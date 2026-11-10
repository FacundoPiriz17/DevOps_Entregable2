"""Provoca una shell con TTY y conserva solo alertas de esa ejecucion real."""
import argparse
import datetime as dt
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
RECORD = ROOT / '.tmp' / 'falco-test.json'


def kube(*args):
    return subprocess.check_output(['kubectl', *args], text=True, encoding='utf-8')


def utcnow():
    return dt.datetime.now(dt.timezone.utc).isoformat().replace('+00:00', 'Z')


def format_report(record, matches, generated):
    local_time = generated.astimezone(dt.timezone(dt.timedelta(hours=-3)))
    alerts = [json.loads(line)['output'] for line in matches]
    lines = [
        '==============================================',
        '           PLAYHUB - REPORTE DE FALCO',
        '==============================================', '',
        'Reporte generado : ' + local_time.strftime('%Y-%m-%d %H:%M:%S'),
        'Zona horaria: America/Montevideo (UTC-03:00)',
        'Kubernetes namespace: falco',
        'Falco pod selector: app.kubernetes.io/name=falco',
        f"Pod de la prueba: {record['namespace']}/{record['pod']}",
        f"Contenedor: {record['container']}",
        f"Ventana UTC: {record['since']} a {record['completed']}",
        'Alcance: alertas correlacionadas con el contenedor de esta prueba.', '',
        '--------------- RESUMEN ---------------------',
        f'Total de alertas de Falco: {len(alerts)}',
        f'Total de shells interactivas en Pods: {len(alerts)}', '',
        '--------------- ALERTAS ----------------------',
        *(alerts or ['No se encontraron alertas de la prueba.']), '',
        '---------- SHELLS INTERACTIVAS EN PODS ----------',
        *(alerts or ['No se encontraron shells interactivas de la prueba.']), '',
        '--------------- FIN DEL REPORTE ---------------',
    ]
    return '\n'.join(lines) + '\n'


def attack(args):
    data = json.loads(kube('get', 'pods', '-n', args.namespace, '-l', args.selector, '-o', 'json'))
    pods = [p for p in data['items'] if not p['metadata'].get('deletionTimestamp')
            and any(c['type'] == 'Ready' and c['status'] == 'True' for c in p.get('status', {}).get('conditions', []))]
    if not pods:
        raise RuntimeError('No hay un Pod Ready de PlayHub para la prueba.')
    pod = sorted(pods, key=lambda p: p['metadata']['name'])[0]
    container = next((c for c in pod['status']['containerStatuses'] if c['name'] == 'backend' and c['ready']), None)
    if not container:
        raise RuntimeError('El Pod seleccionado no tiene un contenedor backend Ready.')
    command = ['sh'] if args.seconds == 0 else ['sh', '-c', f'id; sleep {args.seconds}']
    record = dict(context=kube('config', 'current-context').strip(), namespace=args.namespace,
                  pod=pod['metadata']['name'], pod_uid=pod['metadata']['uid'], container=container['name'],
                  container_id=container['containerID'].split('://', 1)[-1], since=utcnow(), status='started')
    arguments = ['kubectl', 'exec', '-it', '-n', args.namespace, record['pod'], '-c', record['container'], '--', *command]
    record['command'] = arguments
    RECORD.parent.mkdir(parents=True, exist_ok=True)
    RECORD.write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(f"Pod: {record['pod']}; contenedor: {record['container']}; inicio UTC: {record['since']}", flush=True)
    subprocess.run(arguments, check=True)
    record.update(status='completed', completed=utcnow())
    RECORD.write_text(json.dumps(record, indent=2), encoding='utf-8')
    print('Shell terminada. Ejecutar get-falco-report para verificar su deteccion.')


def report(args):
    record = json.loads(RECORD.read_text(encoding='utf-8-sig'))
    if record.get('status') != 'completed':
        raise RuntimeError('La prueba de shell no termino correctamente.')
    if kube('config', 'current-context').strip() != record['context']:
        raise RuntimeError('El contexto actual no coincide con la prueba.')
    if dt.datetime.now(dt.timezone.utc) - dt.datetime.fromisoformat(record['since'].replace('Z', '+00:00')) > dt.timedelta(hours=1):
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
            if not isinstance(event, dict):
                continue
            fields = event.get('output_fields') or {}
            event_id = str(fields.get('container.id', ''))
            if (event.get('rule') == 'Terminal shell in container' and len(event_id) >= 12
                    and record['container_id'].startswith(event_id)):
                instant = dt.datetime.fromisoformat(event['time'].replace('Z', '+00:00'))
                start = dt.datetime.fromisoformat(record['since'].replace('Z', '+00:00'))
                end = dt.datetime.fromisoformat(record['completed'].replace('Z', '+00:00')) + dt.timedelta(seconds=5)
                if start <= instant <= end:
                    matches.append(line)
        if matches or time.monotonic() >= deadline:
            break
        time.sleep(2)
    directory = ROOT / 'reports' / 'falco'
    directory.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    raw_directory = ROOT / '.tmp' / 'falco-logs'
    raw_directory.mkdir(parents=True, exist_ok=True)
    (raw_directory / f'falco-events-{stamp}.txt').write_text(logs, encoding='utf-8')
    generated = dt.datetime.now(dt.timezone.utc)
    local_stamp = generated.astimezone(dt.timezone(dt.timedelta(hours=-3))).strftime('%Y-%m-%d_%H-%M-%S')
    (directory / f'falco-report-{local_stamp}.txt').write_text(format_report(record, matches, generated), encoding='utf-8')
    if not matches:
        raise RuntimeError('No se detecto la shell de esta prueba. Logs guardados; la evidencia anterior no se reemplaza.')
    (raw_directory / f'falco-test-{stamp}.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    alerts = [json.loads(line)['output'] for line in matches]
    (ROOT / 'reports' / 'falco-event.log').write_text('\n'.join(alerts) + '\n', encoding='utf-8')
    print(f'Deteccion verificada: {len(matches)} evento(s). Evidencia: reports/falco-event.log')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    shell = actions.add_parser('attack')
    shell.add_argument('--namespace', default='default')
    shell.add_argument('--selector', default='app=playhub-backend')
    shell.add_argument('--seconds', type=int, choices=range(0, 61), default=0)
    collector = actions.add_parser('report')
    collector.add_argument('--wait-seconds', type=int, choices=range(0, 61), default=30)
    args = parser.parse_args()
    try:
        (attack if args.action == 'attack' else report)(args)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'ERROR: {error}\n')


if __name__ == '__main__':
    main()
