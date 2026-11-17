import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import urllib.request


OWNER = 'playhub-scripts'
MARKER = 'playhub-security-owner'
KYVERNO_VERSION = '1.19.2'
FALCO_CHART_VERSION = '9.2.2'
POLICIES = (
    ('clusterpolicy', 'disallow-latest'),
    ('clusterpolicy', 'require-resources'),
    ('clusterpolicy', 'disallow-root'),
    ('validatingpolicy', 'disallow-privilege-escalation'),
)


def decode_json_documents(text):
    """kubectl may return one List or consecutive documents for multi-doc YAML."""
    decoder = json.JSONDecoder()
    remaining = text.lstrip('\ufeff \r\n\t')
    objects = []
    while remaining:
        value, end = decoder.raw_decode(remaining)
        objects.extend(value['items'] if value.get('kind') == 'List' else [value])
        remaining = remaining[end:].lstrip()
    return objects


class SecurityStack:
    def __init__(self, project_root, dry_run=False, adopt_existing=False):
        self.root = Path(project_root)
        self.dry_run = dry_run
        self.adopt_existing = adopt_existing

    def run(self, command, *arguments):
        result = subprocess.run([command, *arguments], capture_output=True, text=True,
                                encoding='utf-8-sig', errors='replace', check=False)
        if result.stderr.strip():
            print(result.stderr.strip(), file=sys.stderr)
        if result.returncode:
            raise RuntimeError(f'{command} termino con codigo {result.returncode}.')
        return result.stdout.strip()

    def mutate(self, command, *arguments):
        if self.dry_run:
            print('DRY-RUN: ' + ' '.join([command, *arguments]))
            return ''
        output = self.run(command, *arguments)
        if output:
            print(output)
        return output

    def get(self, kind, name, namespace=None):
        args = ['get', kind, name, '--ignore-not-found=true', '-o', 'json']
        if namespace:
            args += ['-n', namespace]
        output = self.run('kubectl', *args)
        return json.loads(output) if output else None

    def helm_releases(self, namespace, *filters):
        # Helm 4 removed --all; explicit states also include pending releases on Helm 3.
        return json.loads(self.run(
            'helm', 'list', '-n', namespace,
            '--deployed', '--failed', '--pending', '--superseded', '--uninstalled', '--uninstalling',
            *filters, '-o', 'json'))

    def apply_json(self, document):
        with tempfile.TemporaryDirectory(prefix='playhub-security-') as directory:
            manifest = Path(directory) / 'resources.json'
            manifest.write_text(json.dumps(document), encoding='utf-8')
            return self.mutate('kubectl', 'apply', '-f', str(manifest))

    def marker(self, component):
        document = self.get('configmap', MARKER, component)
        if document and (document['metadata'].get('labels', {}).get('app.kubernetes.io/managed-by') != OWNER
                         or document.get('data', {}).get('component') != component):
            raise RuntimeError(f'El marcador de {component} no pertenece a PlayHub.')
        return document

    def save_marker(self, component, data):
        if not self.get('namespace', component):
            self.apply_json({'apiVersion': 'v1', 'kind': 'Namespace', 'metadata': {'name': component}})
        self.apply_json({
            'apiVersion': 'v1', 'kind': 'ConfigMap',
            'metadata': {'name': MARKER, 'namespace': component,
                         'labels': {'app.kubernetes.io/managed-by': OWNER}},
            'data': {'component': component, **data},
        })

    def install_kyverno(self, version=KYVERNO_VERSION):
        if version != KYVERNO_VERSION:
            raise RuntimeError(f'Las politicas del proyecto se verificaron con Kyverno {KYVERNO_VERSION}.')
        marker = self.marker('kyverno')
        existing = self.get('deployment', 'kyverno-admission-controller', 'kyverno')
        if existing and not marker and not self.adopt_existing:
            raise RuntimeError('Kyverno ya existe y es compartido. Usar -SkipSecurity / --skip-security; '
                               'o -AdoptSecurity / --adopt-security para registrar la instalacion compatible del proyecto.')
        if existing:
            self.check_kyverno_version()
        if marker and marker['data'].get('version') != version:
            raise RuntimeError('La version de Kyverno registrada es diferente; no se actualiza automaticamente.')

        cache = self.root / '.tmp' / 'security-tools'
        cache.mkdir(parents=True, exist_ok=True)
        manifest = cache / f'kyverno-install-v{version}.yaml'
        if not manifest.is_file():
            url = f'https://github.com/kyverno/kyverno/releases/download/v{version}/install.yaml'
            with urllib.request.urlopen(url, timeout=120) as response:
                manifest.write_bytes(response.read())
        rendered = self.run('kubectl', 'create', '--dry-run=client', '--validate=false',
                            '-f', str(manifest), '-o', 'json')
        inventory = []
        for resource in decode_json_documents(rendered):
            metadata = {'name': resource['metadata']['name']}
            if resource['metadata'].get('namespace'):
                metadata['namespace'] = resource['metadata']['namespace']
            inventory.append({'apiVersion': resource['apiVersion'], 'kind': resource['kind'], 'metadata': metadata})
        if not inventory:
            raise RuntimeError('El manifiesto de Kyverno no contiene recursos.')
        if not marker and not self.adopt_existing:
            for resource in inventory:
                if resource['kind'] == 'Namespace':
                    continue
                if self.get(resource['kind'], resource['metadata']['name'], resource['metadata'].get('namespace')):
                    raise RuntimeError('Hay recursos de Kyverno preexistentes sin marcador; usar SkipSecurity.')
        if self.adopt_existing:
            self.check_foreign_policies(inventory)
        self.save_marker('kyverno', {'version': version, 'inventory': json.dumps(inventory)})
        self.mutate('kubectl', 'apply', '--server-side', '-f', str(manifest))
        for controller in ('admission', 'background', 'cleanup', 'reports'):
            self.run('kubectl', '-n', 'kyverno', 'rollout', 'status',
                     f'deployment/kyverno-{controller}-controller', '--timeout=300s')
        self.mutate('kubectl', 'apply', '-f', str(self.root / 'k8s' / 'kyverno'))
        for kind, name in POLICIES:
            condition = ('--for=jsonpath={.status.conditionStatus.ready}=true'
                         if kind == 'validatingpolicy' else '--for=condition=Ready')
            self.run('kubectl', 'wait', condition, f'{kind}/{name}', '--timeout=120s')

    def check_kyverno_version(self):
        for controller in ('admission', 'background', 'cleanup', 'reports'):
            deployment = self.get('deployment', f'kyverno-{controller}-controller', 'kyverno')
            containers = (deployment or {}).get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
            repository = 'kyverno' if controller == 'admission' else f'{controller}-controller'
            expected_image = f'reg.kyverno.io/kyverno/{repository}:v{KYVERNO_VERSION}'
            if not containers or containers[0].get('image') != expected_image:
                raise RuntimeError(f'Kyverno {controller} no coincide con la version {KYVERNO_VERSION}; se conserva.')

    def install(self):
        if self.get('deployment', 'kyverno-admission-controller', 'kyverno'):
            if not self.marker('kyverno') and not self.adopt_existing:
                raise RuntimeError('Kyverno ya existe sin marcador. Usar SkipSecurity o AdoptSecurity para la instalacion compatible del proyecto.')
            self.check_kyverno_version()
        falco = self.falco_release()
        if falco:
            if not self.marker('falco') and not self.adopt_existing:
                raise RuntimeError('Falco ya existe sin marcador. Usar SkipSecurity o AdoptSecurity para el release compatible del proyecto.')
            if falco.get('chart') != f'falco-{FALCO_CHART_VERSION}':
                raise RuntimeError('La version del chart Falco difiere de la del proyecto; se conserva.')
        self.install_kyverno()
        self.install_falco()

    def falco_release(self):
        releases = self.helm_releases('falco', '--filter', '^falco$')
        return next((release for release in releases if release['name'] == 'falco'), None)

    def install_falco(self):
        marker = self.marker('falco')
        existing = self.falco_release()
        if existing and not marker and not self.adopt_existing:
            raise RuntimeError('Falco ya existe y es compartido. Usar -SkipSecurity / --skip-security; '
                               'o -AdoptSecurity / --adopt-security para registrar el release compatible del proyecto.')
        if existing and existing.get('chart') != f'falco-{FALCO_CHART_VERSION}':
            raise RuntimeError('La version del chart Falco existente difiere de la del proyecto.')
        self.run('helm', 'repo', 'add', 'falcosecurity', 'https://falcosecurity.github.io/charts', '--force-update')
        self.run('helm', 'repo', 'update', 'falcosecurity')
        values = str(self.root / 'security' / 'falco' / 'values.yaml')
        rendered = self.run('helm', 'template', 'falco', 'falcosecurity/falco', '--version',
                            FALCO_CHART_VERSION, '--namespace', 'falco', '--values', values)
        destination = self.root / '.tmp' / 'security-reports' / 'falco-rendered.yaml'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(rendered + '\n', encoding='utf-8')
        self.save_marker('falco', {'chartVersion': FALCO_CHART_VERSION, 'release': 'falco'})
        self.mutate('helm', 'upgrade', '--install', 'falco', 'falcosecurity/falco', '--version',
                    FALCO_CHART_VERSION, '--namespace', 'falco', '--create-namespace', '--values',
                    values, '--wait', '--timeout', '5m')
        self.run('kubectl', 'rollout', 'status', 'daemonset/falco', '-n', 'falco', '--timeout=300s')

    def check_foreign_policies(self, inventory):
        expected = {(kind, '', name) for kind, name in POLICIES}
        for resource in inventory:
            name = resource['metadata']['name']
            if resource['kind'] != 'CustomResourceDefinition' or 'polic' not in name or 'report' in name:
                continue
            if not self.get('crd', name):
                continue
            objects = json.loads(self.run('kubectl', 'get', name, '-A', '-o', 'json')).get('items', [])
            if any((obj['kind'].lower(), obj['metadata'].get('namespace', ''), obj['metadata']['name'])
                   not in expected for obj in objects):
                raise RuntimeError('Kyverno contiene politicas ajenas a PlayHub. Se conserva el operador y sus CRDs.')

    def remove(self):
        kyverno = self.marker('kyverno')
        falco = self.marker('falco')
        release = self.falco_release()
        if release and (not falco or release.get('chart') != f"falco-{falco['data'].get('chartVersion')}"):
            raise RuntimeError('Falco es compartido o cambio de propietario; no se desinstala un release ajeno.')
        if self.get('deployment', 'kyverno-admission-controller', 'kyverno') and not kyverno:
            raise RuntimeError('Kyverno no tiene marcador de PlayHub; no se elimina una instalacion compartida.')
        inventory = json.loads(kyverno['data']['inventory']) if kyverno else []
        if kyverno:
            self.check_foreign_policies(inventory)
        if release:
            self.mutate('helm', 'uninstall', 'falco', '-n', 'falco', '--wait', '--timeout', '5m')
        if falco:
            self.mutate('kubectl', 'delete', 'configmap', MARKER, '-n', 'falco', '--ignore-not-found=true')
        if kyverno:
            for kind, name in POLICIES:
                if self.get('crd', 'clusterpolicies.kyverno.io' if kind == 'clusterpolicy'
                            else 'validatingpolicies.policies.kyverno.io'):
                    self.mutate('kubectl', 'delete', kind, name, '--ignore-not-found=true')
            self.mutate('kubectl', 'delete', 'pod', 'kyverno-valid', 'kyverno-invalid',
                        '-n', 'kyverno-validation', '--ignore-not-found=true')
            resources = [resource for resource in inventory if resource['kind'] != 'Namespace']
            if self.dry_run:
                for resource in resources:
                    print('DRY-RUN: eliminar recurso registrado ' + resource['kind'] + '/' + resource['metadata']['name'])
            elif resources:
                with tempfile.TemporaryDirectory(prefix='playhub-security-') as directory:
                    manifest = Path(directory) / 'inventory.json'
                    manifest.write_text(json.dumps({'apiVersion': 'v1', 'kind': 'List', 'items': resources}), encoding='utf-8')
                    self.mutate('kubectl', 'delete', '-f', str(manifest), '--ignore-not-found=true', '--wait=false')
            self.mutate('kubectl', 'delete', 'configmap', MARKER, '-n', 'kyverno', '--ignore-not-found=true')
        print('Seguridad retirada (o simulada). Se conservan namespaces para proteger recursos ajenos.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', default=str(Path(__file__).resolve().parents[2]))
    actions = parser.add_subparsers(dest='action', required=True)
    install = actions.add_parser('install')
    install.add_argument('--adopt-existing', action='store_true')
    kyverno = actions.add_parser('install-kyverno')
    kyverno.add_argument('--version', default=KYVERNO_VERSION)
    kyverno.add_argument('--adopt-existing', action='store_true')
    falco = actions.add_parser('install-falco')
    falco.add_argument('--adopt-existing', action='store_true')
    remove = actions.add_parser('remove')
    remove.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    stack = SecurityStack(args.project_root, getattr(args, 'dry_run', False), getattr(args, 'adopt_existing', False))
    try:
        for command in (('kubectl',) if args.action == 'install-kyverno' else ('kubectl', 'helm')):
            if not shutil.which(command):
                raise RuntimeError(f'No se encontro {command} en PATH.')
        if args.action == 'install':
            stack.install()
        if args.action == 'install-kyverno':
            stack.install_kyverno(getattr(args, 'version', KYVERNO_VERSION))
        if args.action == 'install-falco':
            stack.install_falco()
        if args.action == 'remove':
            stack.remove()
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        parser.exit(1, f'ERROR: {error}\n')


if __name__ == '__main__':
    main()
