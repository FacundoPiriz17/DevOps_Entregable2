"""Crea un enlace simbolico hacia /etc/shadow y conserva la alerta de Falco."""
import argparse
import datetime as dt
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
RECORD = ROOT / '.tmp' / 'falco-symlink-test.json'
EVIDENCE = ROOT / 'reports' / 'falcoevent.log'
REPORTS = ROOT / 'reports' / 'falco'
RAW_LOGS = ROOT / '.tmp' / 'falco-logs'
RULE = 'Create Symlink Over Sensitive Files'
TARGET = '/etc/shadow'


def kube(*args):
    return subprocess.check_output(['kubectl', *args], text=True, encoding='utf-8')


def utcnow():
    return dt.datetime.now(dt.timezone.utc).isoformat().replace('+00:00', 'Z')


def parse_time(value):
    return dt.datetime.fromisoformat(value.replace('Z', '+00:00'))


def format_report(record, matches, generated):
    local_time = generated.astimezone(dt.timezone(dt.timedelta(hours=-3)))
    alerts = [json.loads(line)['output'] for line in matches]
    cleanup = record.get('cleanup_exit_code')
    cleanup_text = 'correcta' if cleanup == 0 else f'fallida (codigo {cleanup})'
    lines = [
        '==============================================',
        '        PLAYHUB - EVENTO FALCO (SYMLINK)',
        '==============================================', '',
        'Reporte generado : ' + local_time.strftime('%Y-%m-%d %H:%M:%S'),
        'Zona horaria: America/Montevideo (UTC-03:00)',
        'Kubernetes namespace: falco',
        'Falco pod selector: app.kubernetes.io/name=falco',
        f"Pod de la prueba: {record['namespace']}/{record['pod']}",
        f"Contenedor: {record['container']}",
        f"Ventana UTC: {record['since']} a {record['completed']}", '',
        '--------------- EVENTO -----------------------',
        f'Regla: {record["rule"]}',
        'Prioridad: WARNING',
        'MITRE ATT&CK: T1555 - Credentials from Password Stores',
        f'Target: {record["target"]}',
        f'Enlace creado: {record["link"]}',
        'Shell interactiva: no',
        'TTY: no',
        'Kyverno: no interviene; no se creo ni modifico ningun Pod.',
        f'Limpieza del enlace: {cleanup_text}', '',
        'Descripcion:',
        'Se creo un enlace simbolico dentro del contenedor backend apuntando a',
        '/etc/shadow, archivo sensible de credenciales. La accion simula la',
        'preparacion de un acceso no autorizado a credenciales. No se leyo ni',
        'modifico el archivo y el enlace fue eliminado al finalizar.', '',
        '--------------- COMANDOS ---------------------',
        'Ataque:',
        ' '.join(record['command']), '',
        'Limpieza:',
        ' '.join(record['cleanup_command']), '',
        '--------------- RESUMEN ----------------------',
        f'Total de alertas de Falco: {len(alerts)}', '',
        '--------------- ALERTAS ----------------------',
        *(alerts or ['No se encontraron alertas de la prueba.']), '',
        '--------------- FIN DEL REPORTE ---------------',
    ]
    return '\n'.join(lines) + '\n'


def attack(args):
    data = json.loads(kube('get', 'pods', '-n', args.namespace, '-l', args.selector, '-o', 'json'))
    pods = [p for p in data['items'] if not p['metadata'].get('deletionTimestamp')
            and any(c['type'] == 'Ready' and c['status'] == 'True'
                    for c in p.get('status', {}).get('conditions', []))]
    if not pods:
        raise RuntimeError('No hay un Pod Ready de PlayHub para la prueba.')
    pod = sorted(pods, key=lambda p: p['metadata']['name'])[0]
    container = next((c for c in pod.get('status', {}).get('containerStatuses', [])
                      if c['name'] == 'backend' and c['ready']), None)
    if not container or not container.get('containerID'):
        raise RuntimeError('El Pod seleccionado no tiene un contenedor backend Ready.')
    link = f'/tmp/playhub-falco-{int(time.time() * 1000)}.link'
    record = dict(context=kube('config', 'current-context').strip(), namespace=args.namespace,
                  pod=pod['metadata']['name'], pod_uid=pod['metadata']['uid'],
                  container=container['name'], container_id=container['containerID'].split('://', 1)[-1],
                  event_type='symlink', rule=RULE, target=TARGET, link=link,
                  since=utcnow(), status='started')
    record['command'] = ['kubectl', 'exec', '-n', args.namespace, record['pod'], '-c', record['container'],
                         '--', '/bin/busybox', 'ln', '-s', TARGET, link]
    record['cleanup_command'] = ['kubectl', 'exec', '-n', args.namespace, record['pod'],
                                 '-c', record['container'], '--', '/bin/busybox', 'rm', '-f', link]
    RECORD.parent.mkdir(parents=True, exist_ok=True)
    RECORD.write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(f"Pod: {record['pod']}; contenedor: {record['container']}; inicio UTC: {record['since']}", flush=True)
    try:
        subprocess.run(record['command'], check=True, text=True, capture_output=True)
        record.update(status='completed', completed=utcnow())
    except (OSError, subprocess.CalledProcessError) as error:
        record.update(status='failed', completed=utcnow(), error=str(error))
        raise
    finally:
        try:
            cleanup = subprocess.run(record['cleanup_command'], check=False, text=True, capture_output=True)
            record['cleanup_exit_code'] = cleanup.returncode
            record['cleanup_stderr'] = cleanup.stderr.strip()
        except OSError as error:
            record['cleanup_exit_code'] = -1
            record['cleanup_stderr'] = str(error)
        RECORD.write_text(json.dumps(record, indent=2), encoding='utf-8')
    if record.get('cleanup_exit_code') != 0:
        print('ADVERTENCIA: no se pudo confirmar la eliminacion del enlace temporal.', flush=True)
    print('Enlace temporal eliminado. Ejecutar get-falco-symlink-report para verificar la deteccion.')


def report(args):
    record = json.loads(RECORD.read_text(encoding='utf-8-sig'))
    if record.get('event_type') != 'symlink' or record.get('status') != 'completed':
        raise RuntimeError('La prueba symlink no termino correctamente.')
    if kube('config', 'current-context').strip() != record['context']:
        raise RuntimeError('El contexto actual no coincide con la prueba.')
    start = parse_time(record['since'])
    end = parse_time(record['completed'])
    if dt.datetime.now(dt.timezone.utc) - start > dt.timedelta(hours=1):
        raise RuntimeError('La prueba tiene mas de una hora; provocar un evento nuevo.')
    logs_args = ['logs', '-n', 'falco', '-l', 'app.kubernetes.io/name=falco', '-c', 'falco',
                 '--since-time=' + record['since'], '--tail=-1', '--max-log-requests=10']
    deadline = time.monotonic() + args.wait_seconds
    while True:
        logs = kube(*logs_args)
        matches = []
        for line in logs.splitlines():
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(event, dict) or event.get('rule') != RULE:
                continue
            fields = event.get('output_fields') or {}
            event_id = str(fields.get('container.id', ''))
            if len(event_id) < 12 or not record['container_id'].startswith(event_id):
                continue
            output = str(event.get('output', ''))
            target = str(fields.get('evt.arg.target', ''))
            if TARGET not in output and target != TARGET:
                continue
            instant = parse_time(event['time'])
            if start <= instant <= end + dt.timedelta(seconds=5):
                matches.append(line)
        if matches or time.monotonic() >= deadline:
            break
        time.sleep(2)
    RAW_LOGS.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    (RAW_LOGS / f'falco-symlink-events-{stamp}.txt').write_text(logs, encoding='utf-8')
    REPORTS.mkdir(parents=True, exist_ok=True)
    generated = dt.datetime.now(dt.timezone.utc)
    local_stamp = generated.astimezone(dt.timezone(dt.timedelta(hours=-3))).strftime('%Y-%m-%d_%H-%M-%S')
    (REPORTS / f'falco-symlink-report-{local_stamp}.txt').write_text(
        format_report(record, matches, generated), encoding='utf-8')
    if not matches:
        raise RuntimeError('No se detecto el enlace de esta prueba. Logs guardados; la evidencia anterior no se reemplaza.')
    (RAW_LOGS / f'falco-symlink-test-{stamp}.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    alerts = [json.loads(line)['output'] for line in matches]
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text('\n'.join(alerts) + '\n', encoding='utf-8')
    print(f'Deteccion verificada: {len(matches)} evento(s). Evidencia: reports/falcoevent.log')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    trigger = actions.add_parser('attack')
    trigger.add_argument('--namespace', default='default')
    trigger.add_argument('--selector', default='app=playhub-backend')
    collector = actions.add_parser('report')
    collector.add_argument('--wait-seconds', type=int, choices=range(0, 61), default=30)
    args = parser.parse_args()
    try:
        (attack if args.action == 'attack' else report)(args)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'ERROR: {error}\n')


if __name__ == '__main__':
    main()
