set -euo pipefail

namespace="playhub-helm"
release_name="playhub"
delete_namespace=false
remove_images=false
dry_run=false
minikube_profile="minikube"

usage() {
  printf '%s\n' \
    "Uso: scripts/cleanup-helm.sh [opciones]" \
    "" \
    "Desinstala el release de Helm de PlayHub. El PVC de PostgreSQL se elimina con el release." \
    "" \
    "Opciones:" \
    "  --namespace NOMBRE          Namespace del release (default: playhub-helm)." \
    "  --release-name NOMBRE       Nombre del release (default: playhub)." \
    "  --delete-namespace          Elimina tambien el namespace." \
    "  --remove-images             Elimina playhub-backend:v1.0, playhub-frontend:v1.0 y" \
    "                              playhub-frontend:v1.0-prod de Minikube y Docker." \
    "                              Ojo: deploy.sh usa las mismas etiquetas v1.0 (las reconstruye)." \
    "  --minikube-profile NOMBRE   Perfil de Minikube (default: minikube)." \
    "  --dry-run                   Muestra las acciones sin ejecutarlas." \
    "  -h, --help                  Muestra esta ayuda."
}

need_value() {
  if (($# < 2)) || [[ -z "$2" ]]; then
    echo "Falta el valor de $1." >&2
    exit 2
  fi
}

while (($# > 0)); do
  case "$1" in
    --namespace)
      need_value "$@"
      namespace="$2"
      shift 2
      ;;
    --release-name)
      need_value "$@"
      release_name="$2"
      shift 2
      ;;
    --delete-namespace)
      delete_namespace=true
      shift
      ;;
    --remove-images)
      remove_images=true
      shift
      ;;
    --minikube-profile)
      need_value "$@"
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "No se encontro '$1' en PATH." >&2
    exit 1
  fi
}

run_command() {
  if [[ "$dry_run" == true ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

stop_helm_port_forward() {
  local name pid_file pid

  for name in backend frontend; do
    pid_file="$project_root/logs/helm-port-forward-$name.pid"

    if [[ -f "$pid_file" ]]; then
      pid="$(cat "$pid_file")"

      if [[ "$dry_run" == true ]]; then
        echo "[dry-run] detener port-forward '$name' (PID $pid)"
        continue
      fi

      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
      fi

      rm -f "$pid_file"
    fi
  done
}

require_command helm
require_command kubectl

context="$(kubectl config current-context)"
if [[ -z "$context" ]]; then
  echo "No se pudo determinar el contexto actual de Kubernetes." >&2
  exit 1
fi

echo "Contexto: $context"
echo "Namespace: $namespace"
echo "Release: $release_name"
echo "Solo se elimina el release de Helm; el despliegue de deploy.sh (namespace default) no se toca."
echo "Aviso: se eliminaran tambien el PVC y los datos de PostgreSQL del release." >&2

echo "Deteniendo los port-forward de Helm, si existen..."
stop_helm_port_forward

found="$(helm list -n "$namespace" --short --filter "^${release_name}\$")"

if [[ -z "$found" ]]; then
  echo "No hay un release '$release_name' en el namespace '$namespace'. Nada que desinstalar."
else
  run_command helm uninstall "$release_name" -n "$namespace"
fi

if [[ "$delete_namespace" == true ]]; then
  echo "Eliminando el namespace '$namespace'..."
  run_command kubectl delete namespace "$namespace" --ignore-not-found=true
fi

if [[ "$remove_images" == true ]]; then
  images=(playhub-backend:v1.0 playhub-frontend:v1.0 playhub-frontend:v1.0-prod)

  if command -v minikube >/dev/null 2>&1; then
    for image in "${images[@]}"; do
      echo "Eliminando $image de Minikube..."
      run_command minikube -p "$minikube_profile" image rm "$image" || true
    done
  else
    echo "Aviso: no se encontro minikube en PATH; se omiten las imagenes del cluster." >&2
  fi

  if command -v docker >/dev/null 2>&1; then
    for image in "${images[@]}"; do
      echo "Eliminando $image de Docker..."
      run_command docker image rm "$image" || true
    done
  else
    echo "Aviso: no se encontro docker en PATH; se omiten las imagenes locales." >&2
  fi
fi

echo
echo "Limpieza terminada. Para comprobarlo:"
echo "  helm list -n $namespace"
echo "  kubectl get all -n $namespace"
