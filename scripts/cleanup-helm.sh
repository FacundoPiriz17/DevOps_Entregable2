#!/usr/bin/env bash
set -euo pipefail
namespace=playhub-helm
release_name=playhub
delete_namespace=false
delete_data=false
remove_images=false
remove_security=false
dry_run=false
minikube_profile=minikube

usage() {
  printf '%s\n' \
    'Uso: scripts/cleanup-helm.sh [opciones]' \
    '  --namespace NOMBRE       Namespace (default: playhub-helm).' \
    '  --release-name NOMBRE    Release (default: playhub).' \
    '  --delete-data            Elimina los PVC de PostgreSQL, Prometheus y Grafana.' \
    '  --delete-namespace       Elimina el namespace; requiere --delete-data.' \
    '  --remove-security        Retira Kyverno/politicas/Falco registrados por PlayHub.' \
    '  --remove-images          Retira las imagenes PlayHub de Minikube y Docker.' \
    '  --minikube-profile NOMBRE  Perfil Minikube (default: minikube).' \
    '  --dry-run                Muestra las acciones sin ejecutarlas.' \
    '  -h, --help               Muestra esta ayuda.'
}
need_value() {
  if (($# < 2)) || [[ -z "$2" ]]; then echo "Falta el valor de $1." >&2; exit 2; fi
}
while (($# > 0)); do
  case "$1" in
    --namespace) need_value "$@"; namespace="$2"; shift 2 ;;
    --release-name) need_value "$@"; release_name="$2"; shift 2 ;;
    --minikube-profile) need_value "$@"; minikube_profile="$2"; shift 2 ;;
    --delete-data) delete_data=true; shift ;;
    --delete-namespace) delete_namespace=true; shift ;;
    --remove-images) remove_images=true; shift ;;
    --remove-security) remove_security=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opcion desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
done
if [[ "$delete_namespace" == true ]]; then
  case "$namespace" in
    default|kube-system|kube-public|kube-node-lease|kyverno|falco)
      echo "No se elimina el namespace protegido $namespace." >&2; exit 2 ;;
  esac
  if [[ "$delete_data" != true ]]; then echo '--delete-namespace requiere --delete-data.' >&2; exit 2; fi
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
source "$script_dir/lib/security-stack.sh"
context="$(kubectl config current-context)"
echo "Contexto: $context; namespace: $namespace; release: $release_name"
if [[ "$dry_run" == true ]]; then
  echo "DRY-RUN: desinstalar release exacto $release_name; delete-data=$delete_data; delete-namespace=$delete_namespace."
  echo 'DRY-RUN: detener solamente los cuatro port-forward registrados por el despliegue Helm.'
  if [[ "$remove_images" == true ]]; then echo 'DRY-RUN: retirar las imagenes PlayHub de Docker/Minikube.'; fi
  if [[ "$remove_security" == true ]]; then echo 'DRY-RUN: retirar Kyverno, cuatro politicas y Falco registrados por PlayHub.'; fi
  exit 0
fi
cleanup_args=(--namespace "$namespace" --release-name "$release_name")
if [[ "$delete_data" == true ]]; then cleanup_args+=(--delete-data); fi
if [[ "$delete_namespace" == true ]]; then cleanup_args+=(--delete-namespace); fi
"$(playhub_security_python)" "$script_dir/lib/helm-cleanup.py" "${cleanup_args[@]}"
for name in backend frontend prometheus grafana; do
  pid_file="$project_root/logs/helm-port-forward-$name.pid"
  if [[ -f "$pid_file" ]]; then
    process_id="$(cat "$pid_file")"
    if [[ "$process_id" =~ ^[0-9]+$ ]] && kill -0 "$process_id" 2>/dev/null; then
      process_name="$(ps -p "$process_id" -o comm= 2>/dev/null || true)"
      if [[ "$process_name" == *kubectl* ]]; then kill "$process_id" 2>/dev/null || true; fi
    fi
    rm -f "$pid_file"
  fi
done
if [[ "$remove_images" == true ]]; then
  for image in playhub-backend:v1.0 playhub-frontend:v1.0 playhub-frontend:v1.0-prod; do
    if command -v minikube >/dev/null 2>&1; then minikube -p "$minikube_profile" image rm "$image" || true; fi
    if command -v docker >/dev/null 2>&1; then docker image rm "$image" || true; fi
  done
fi
if [[ "$remove_security" == true ]]; then remove_playhub_security "$project_root"
else echo 'Kyverno y Falco se conservan; --remove-security retira las instalaciones de PlayHub.'
fi
echo 'Limpieza de PlayHub terminada.'
