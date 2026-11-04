#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="default"
LABEL_SELECTOR="app=playhub-backend"

echo "PLAYHUB - SIMULACION DE ATAQUE CON SHELL"

POD=$(kubectl get pods \
    -n "$NAMESPACE" \
    -l "$LABEL_SELECTOR" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$POD" ]]; then
    echo "No se encontro ningun Pod de PlayHub corriendo."
    exit 1
fi

CONTAINER=$(kubectl get pod "$POD" \
    -n "$NAMESPACE" \
    -o jsonpath='{.spec.containers[0].name}')

if [[ -z "$CONTAINER" ]]; then
    echo "No se pudo identificar el contenedor."
    exit 1
fi

echo "Target Pod: $POD"
echo "Container: $CONTAINER"
echo "Abriendo shell interactiva..."

kubectl exec -it -n "$NAMESPACE" "$POD" \
    -c "$CONTAINER" -- \
    sh -c 'if command -v bash >/dev/null 2>&1; then exec bash -i; else exec sh; fi'

echo "Simulacion completada."
