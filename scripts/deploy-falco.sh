#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

VALUES_FILE="$PROJECT_ROOT/security/falco/values.yaml"

RELEASE_NAME="falco"
NAMESPACE="falco"
CHART="falcosecurity/falco"
CHART_VERSION="9.2.2"

echo "========================================"
echo "       PLAYHUB - DEPLOYMENT DE FALCO"
echo "========================================"

for command in helm kubectl; do
if ! command -v "$command" >/dev/null 2>&1; then
echo "ERROR: $command no se encontró en el PATH."
exit 1
fi
done

if [[ ! -f "$VALUES_FILE" ]]; then
echo "ERROR: No se encontró el values file de Falco: $VALUES_FILE"
exit 1
fi

echo ""
echo "Verificando el cluster de Kubernetes..."

kubectl get nodes

echo ""
echo "Actualizando el repositorio de Helm con Falco..."

helm repo add falcosecurity 
https://falcosecurity.github.io/charts 
--force-update

helm repo update

echo ""
echo "Instalando/actualizando Falco..."

helm upgrade --install "$RELEASE_NAME" "$CHART" 
--version "$CHART_VERSION" 
--namespace "$NAMESPACE" 
--create-namespace 
--values "$VALUES_FILE" 
--wait 
--timeout 5m

echo ""
echo "Esperando Falco DaemonSet..."

kubectl rollout status daemonset/falco 
-n "$NAMESPACE" 
--timeout=180s

echo ""
echo "Falco pods:"
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
echo "Falco DaemonSet:"
kubectl get daemonset -n "$NAMESPACE"

echo ""
echo "Falco deployment completado exitosamente."