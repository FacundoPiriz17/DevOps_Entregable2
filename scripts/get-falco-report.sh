#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

REPORT_DIR="$PROJECT_ROOT/reports/falco"
mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

EVENTS_FILE="$REPORT_DIR/falco-events-$TIMESTAMP.log"
REPORT_FILE="$REPORT_DIR/falco-report-$TIMESTAMP.txt"
ALERTS_FILE="$REPORT_DIR/.falco-alerts-$TIMESTAMP.tmp"
POD_SHELL_FILE="$REPORT_DIR/.falco-pod-shells-$TIMESTAMP.tmp"

echo "Obteniendo logs de Falco..."

if ! kubectl logs -n falco \
    -l app.kubernetes.io/name=falco \
    -c falco \
    --prefix=true > "$EVENTS_FILE"; then

    echo "ERROR: No se pudieron conseguir los logs de Falco. Asegúrese de que el pod de Falco está corriendo."
    rm -f "$EVENTS_FILE"
    exit 1
fi

grep -E ' (Emergency|Alert|Critical|Error|Warning|Notice|Informational|Debug)( |$)' \
    "$EVENTS_FILE" > "$ALERTS_FILE" || true

grep -F 'A shell was spawned in a container with an attached terminal' \
    "$ALERTS_FILE" > "$POD_SHELL_FILE" || true

ALERT_COUNT="$(wc -l < "$ALERTS_FILE" | tr -d ' ')"
POD_SHELL_COUNT="$(wc -l < "$POD_SHELL_FILE" | tr -d ' ')"

{
    echo "=============================================="
    echo "           PLAYHUB - REPORTE DE FALCO"
    echo "=============================================="
    echo ""
    echo "Reporte generado: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Kubernetes namespace: falco"
    echo "Falco pod selector: app.kubernetes.io/name/falco"
    echo ""
    echo "--------------- RESUMEN ---------------------"
    echo "Total de alertas de Falco: $ALERT_COUNT"
    echo "Total de shells interactivas en Pods: $POD_SHELL_COUNT"
    echo ""
    echo "--------------- ALERTAS ----------------------"

    if [[ "$ALERT_COUNT" -gt 0 ]]; then
        cat "$ALERTS_FILE"
    else
        echo "No se encontraron alertas."
    fi

    echo ""
    echo "---------- SHELLS INTERACTIVAS EN PODS ----------"

    if [[ "$POD_SHELL_COUNT" -gt 0 ]]; then
        cat "$POD_SHELL_FILE"
    else
        echo "No se encontraron shells interactivas en Pods."
    fi

    echo ""
    echo "--------------- FIN DEL REPORTE ---------------"

} > "$REPORT_FILE"

rm -f "$ALERTS_FILE" "$POD_SHELL_FILE"

echo ""
echo "Obtención de alertas de Falco terminada."
echo "Eventos: $EVENTS_FILE"
echo "Reporte: $REPORT_FILE"
