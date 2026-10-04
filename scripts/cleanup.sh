#!/usr/bin/env bash

set -euo pipefail

delete_data=false
remove_images=false
dry_run=false
minikube_profile="minikube"

usage() {
  printf '%s\n' \
    "Uso: scripts/cleanup.sh [opciones]" \
    "" \
    "Elimina exclusivamente los recursos Kubernetes de PlayHub." \
    "Por defecto conserva el PVC y las imagenes locales." \
    "" \
    "Opciones:" \
    "  --delete-data              Elimina el PVC y todos los datos de PostgreSQL." \
    "  --remove-images            Elimina las imagenes PlayHub de Minikube y Docker." \
    "  --minikube-profile NOMBRE  Perfil de Minikube (default: minikube)." \
    "  --dry-run                  Muestra las eliminaciones sin ejecutarlas." \
    "  -h, --help                 Muestra esta ayuda."
}

while (($# > 0)); do
  case "$1" in
    --delete-data)
      delete_data=true
      shift
      ;;
    --remove-images)
      remove_images=true
      shift
      ;;
    --minikube-profile)
      if (($# < 2)); then
        echo "Falta el valor de --minikube-profile." >&2
        exit 2
      fi
      minikube_profile="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opcion desconocida: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "No se encontro '$1' en PATH." >&2
    exit 1
  fi
}

run_command() {
  if [[ "$dry_run" == true ]]; then
    printf 'DRY-RUN:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

delete_resources() {
  local kind="$1"
  shift

  run_command kubectl delete "$kind" "$@" \
    --namespace "$namespace" \
    --ignore-not-found=true \
    --wait=true
}

remove_optional_image() {
  local runtime="$1"
  local image="$2"

  if [[ "$runtime" == "minikube" ]]; then
    if [[ "$dry_run" == true ]]; then
      run_command minikube -p "$minikube_profile" image rm "$image"
    elif ! minikube -p "$minikube_profile" image rm "$image"; then
      echo "Aviso: Minikube no pudo eliminar '$image'; puede que ya no exista." >&2
    fi
    return
  fi

  if [[ "$dry_run" == true ]]; then
    run_command docker image rm "$image"
  elif ! docker image rm "$image"; then
    echo "Aviso: Docker no pudo eliminar '$image'; puede que ya no exista." >&2
  fi
}

stop_tracked_port_forward() {
  local name="$1"
  local pid_file="$project_root/logs/port-forward-$name.pid"
  local pid

  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file")"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      if [[ "$dry_run" == true ]]; then
        echo "DRY-RUN: kill $pid (port-forward $name)"
      else
        kill "$pid" 2>/dev/null || true
      fi
    fi

    if [[ "$dry_run" == false ]]; then
      rm -f "$pid_file"
    fi
  fi
}

require_command kubectl

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

current_context="$(kubectl config current-context)"

if [[ -z "$current_context" ]]; then
  echo "kubectl no tiene un contexto activo." >&2
  exit 1
fi

namespace="$(kubectl config view --minify -o jsonpath='{..namespace}')"
namespace="${namespace:-default}"

echo "Contexto: $current_context"
echo "Namespace: $namespace"
echo "Solo se eliminaran recursos con nombres propios de PlayHub."

if [[ "$delete_data" == true ]]; then
  echo "Aviso: --delete-data eliminara playhub-postgres-data y todos sus datos." >&2
else
  echo "El PVC playhub-postgres-data se conservara. Usa --delete-data para reiniciar tambien la base."
fi

echo "Deteniendo port-forward de backend y frontend, si existen..."
stop_tracked_port_forward backend
stop_tracked_port_forward frontend

delete_resources deployment \
  playhub-backend-blue \
  playhub-backend-green \
  playhub-frontend-blue \
  playhub-frontend-green \
  playhub-postgres

delete_resources job playhub-migrations

delete_resources service \
  playhub-backend \
  playhub-backend-blue \
  playhub-backend-green \
  playhub-frontend \
  playhub-frontend-blue \
  playhub-frontend-green \
  playhub-db

delete_resources configmap \
  playhub-config \
  playhub-migration-sql

delete_resources secret playhub-secrets

pod_names="$(kubectl get pods --namespace "$namespace" -o name)"
image_check_pods=()

while IFS= read -r pod; do
  case "$pod" in
    pod/playhub-image-check-*)
      image_check_pods+=("$pod")
      ;;
  esac
done <<< "$pod_names"

if ((${#image_check_pods[@]} > 0)); then
  run_command kubectl delete "${image_check_pods[@]}" \
    --namespace "$namespace" \
    --ignore-not-found=true \
    --wait=true
else
  run_command kubectl delete pod \
    --namespace "$namespace" \
    --selector "app=playhub-image-check" \
    --ignore-not-found=true \
    --wait=true
fi

if [[ "$delete_data" == true ]]; then
  delete_resources pvc playhub-postgres-data
fi

if [[ "$remove_images" == true ]]; then
  images=(
    "playhub-backend:v1.0"
    "playhub-backend:v2.0"
    "playhub-frontend:v1.0"
    "playhub-frontend:v2.0"
  )

  if command -v minikube >/dev/null 2>&1; then
    for image in "${images[@]}"; do
      remove_optional_image minikube "$image"
    done
  else
    echo "Aviso: no se encontro minikube; no se limpio su cache de imagenes." >&2
  fi

  if command -v docker >/dev/null 2>&1; then
    for image in "${images[@]}"; do
      remove_optional_image docker "$image"
    done
  else
    echo "Aviso: no se encontro docker; no se eliminaron las imagenes locales." >&2
  fi
fi

if [[ "$dry_run" == true ]]; then
  echo "Simulacion terminada; no se elimino ningun recurso."
else
  echo "Limpieza de PlayHub terminada."
fi

if [[ "$delete_data" == false ]]; then
  echo "Se conservo persistentvolumeclaim/playhub-postgres-data."
fi
