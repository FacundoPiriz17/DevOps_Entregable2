#!/usr/bin/env bash

set -euo pipefail

target="${1:-}"

if [[ "$target" != "blue" && "$target" != "green" ]]; then
  echo "Uso: $0 <blue|green>" >&2
  exit 2
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "No se encontro kubectl en PATH." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

restart_tracked_port_forward() {
  local name="$1"
  local service="$2"
  local port_mapping="$3"
  local pid_file="$project_root/logs/port-forward-$name.pid"
  local log_file="$project_root/logs/port-forward-$name.log"
  local pid

  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file")"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi

    rm -f "$pid_file"

    kubectl port-forward "svc/$service" "$port_mapping" >"$log_file" 2>&1 &
    disown
    echo "$!" >"$pid_file"
    echo "Port-forward de '$service' reiniciado para apuntar al nuevo slot (log: $log_file)."
    return 0
  fi

  return 1
}

get_service_slot() {
  kubectl get service "$1" -o jsonpath='{.spec.selector.slot}'
}

backend_deployment="playhub-backend-$target"
frontend_deployment="playhub-frontend-$target"

current_backend_slot="$(get_service_slot playhub-backend)"
current_frontend_slot="$(get_service_slot playhub-frontend)"

if [[ "$current_backend_slot" != "$current_frontend_slot" ]]; then
  echo "Estado inconsistente: frontend=$current_frontend_slot, backend=$current_backend_slot." >&2
  exit 1
fi

current_slot="$current_backend_slot"

if [[ "$current_slot" == "$target" ]]; then
  echo "PlayHub ya utiliza el slot '$target'."
  exit 0
fi

echo "Comprobando que Backend $target este disponible..."
kubectl rollout status "deployment/$backend_deployment" --timeout=180s

echo "Comprobando que Frontend $target este disponible..."
kubectl rollout status "deployment/$frontend_deployment" --timeout=180s

target_patch="$(printf '{"spec":{"selector":{"slot":"%s"}}}' "$target")"
rollback_patch="$(printf '{"spec":{"selector":{"slot":"%s"}}}' "$current_slot")"

echo "Cambiando el backend de $current_slot a $target..."
kubectl patch service playhub-backend --type=merge --patch="$target_patch"

echo "Cambiando el frontend de $current_slot a $target..."

if ! kubectl patch service playhub-frontend --type=merge --patch="$target_patch"; then
  echo "Fallo el cambio del frontend. Restaurando el backend a $current_slot..." >&2
  kubectl patch service playhub-backend --type=merge --patch="$rollback_patch"
  exit 1
fi

echo
echo "PlayHub ahora utiliza el slot '$target'."

kubectl get service playhub-backend playhub-frontend \
  -o custom-columns='SERVICE:.metadata.name,SLOT:.spec.selector.slot'

backend_restarted=false
frontend_restarted=false

if restart_tracked_port_forward backend playhub-backend 8080:8080; then
  backend_restarted=true
fi

if restart_tracked_port_forward frontend playhub-frontend 5745:5745; then
  frontend_restarted=true
fi

if [[ "$backend_restarted" == false || "$frontend_restarted" == false ]]; then
  echo "Aviso: si utilizas port-forward manual, detenlo y vuelvelo a iniciar para conectarte a los Pods del nuevo slot."
fi
