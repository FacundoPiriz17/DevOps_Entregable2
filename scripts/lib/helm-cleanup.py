import argparse
import json
from pathlib import Path
import re
import tempfile

from importlib.util import module_from_spec, spec_from_file_location

spec = spec_from_file_location('playhub_security_stack', Path(__file__).with_name('security-stack.py'))
security = module_from_spec(spec)
spec.loader.exec_module(security)

PROTECTED_NAMESPACES = {'default', 'kube-system', 'kube-public', 'kube-node-lease', 'kyverno', 'falco'}


class HelmCleanup(security.SecurityStack):
    def cleanup(self, namespace, release, delete_data=False, delete_namespace=False):
        for value in (namespace, release):
            if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]*[a-z0-9])?', value) or len(value) > 63:
                raise RuntimeError('Namespace y release deben ser nombres DNS validos, sin opciones ni patrones.')
        if delete_namespace and namespace in PROTECTED_NAMESPACES:
            raise RuntimeError(f'No se elimina el namespace protegido {namespace}.')
        if delete_namespace and not delete_data:
            raise RuntimeError('--delete-namespace requiere --delete-data porque elimina todos los PVC del namespace.')
        releases = json.loads(self.run('helm', 'list', '-n', namespace, '--all', '-o', 'json'))
        target = next((item for item in releases if item['name'] == release), None)
        if target and not target.get('chart', '').startswith('playhub-'):
            raise RuntimeError('El release indicado no pertenece al chart PlayHub; se conserva.')
        if delete_namespace and any(item['name'] != release for item in releases):
            raise RuntimeError('El namespace contiene otros releases; se conserva para no eliminar aplicaciones ajenas.')

        selector = f'app.kubernetes.io/instance={release},app.kubernetes.io/name=playhub'
        pvcs = json.loads(self.run('kubectl', 'get', 'pvc', '-n', namespace, '-l', selector, '-o', 'json'))
        data_names = {item['metadata']['name'] for item in pvcs.get('items', [])}
        if target:
            manifest = self.run('helm', 'get', 'manifest', release, '-n', namespace)
            with tempfile.TemporaryDirectory(prefix='playhub-cleanup-') as directory:
                source = Path(directory) / 'release.yaml'
                source.write_text(manifest, encoding='utf-8')
                rendered = self.run('kubectl', 'create', '--dry-run=client', '--validate=false', '-f', str(source), '-o', 'json')
            resources = security.decode_json_documents(rendered)
            for resource in resources:
                if resource['kind'] != 'PersistentVolumeClaim':
                    continue
                metadata = resource['metadata']
                data_names.add(metadata['name'])
                if not delete_data and metadata.get('annotations', {}).get('helm.sh/resource-policy') != 'keep':
                    raise RuntimeError('El release antiguo no conserva sus PVC. Actualizarlo con el chart actual '
                                       'antes de limpiar, o usar --delete-data para borrarlos expresamente.')
            self.mutate('helm', 'uninstall', release, '-n', namespace, '--wait', '--timeout', '5m')
        else:
            print(f'No existe el release {release} en {namespace}.')
        if delete_data and data_names:
            self.mutate('kubectl', 'delete', 'pvc', *sorted(data_names), '-n', namespace, '--ignore-not-found=true')
        if delete_namespace:
            self.mutate('kubectl', 'delete', 'namespace', namespace, '--ignore-not-found=true')
        if not delete_data:
            print('Se conservan los PVC y datos de PostgreSQL, Prometheus y Grafana.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--namespace', default='playhub-helm')
    parser.add_argument('--release-name', default='playhub')
    parser.add_argument('--delete-data', action='store_true')
    parser.add_argument('--delete-namespace', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    try:
        HelmCleanup(Path(__file__).resolve().parents[2], args.dry_run).cleanup(
            args.namespace, args.release_name, args.delete_data, args.delete_namespace)
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        parser.exit(1, f'ERROR: {error}\n')


if __name__ == '__main__':
    main()
