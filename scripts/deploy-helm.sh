#!/usr/bin/env bash
set -euo pipefail

environment="dev"
namespace="playhub-helm"
release_name="playhub"
skip_build=false
skip_image_load=false
no_port_forward=false
skip_security=false
adopt_security=false
db_password=""
jwt_secret=""
admin_password=""

usage() {
  printf '%s\n' \
    "Uso: scripts/deploy-helm.sh [opciones]" \
    "" \
    "Instala o actualiza el release de Helm de PlayHub y verifica el despliegue." \
    "" \
    "Opciones:" \
    "  --environment dev|prod      Archivo de values a usar (default: dev)." \
    "  --namespace NOMBRE          Namespace del release (default: playhub-helm)." \
    "  --release-name NOMBRE       Nombre del release (default: playhub)." \
    "  --skip-build                No reconstruye las imagenes." \
    "  --skip-image-load           No importa las imagenes a Minikube." \
    "  --no-port-forward           No abre los accesos de aplicacion ni monitoreo." \
    "  --skip-security             No instala Kyverno/Falco (stack compartido)." \
    "  --adopt-security            Registra el stack existente compatible de PlayHub." \
    "  --db-password VALOR         Solo prod: contrasena de PostgreSQL." \
    "  --jwt-secret VALOR          Solo prod: secreto JWT (48+ bytes UTF-8)." \
    "  --admin-password VALOR      Solo prod: contrasena del administrador." \
    "  -h, --help                  Muestra esta ayuda." \
    "" \
    "Ejemplos:" \
    "  scripts/deploy-helm.sh" \
    "  scripts/deploy-helm.sh --skip-build" \
    "  scripts/deploy-helm.sh --environment prod --db-password X --jwt-secret Y --admin-password Z"
}

need_value() {
  if (($# < 2)) || [[ -z "$2" ]]; then
    echo "Falta el valor de $1." >&2
    exit 2
  fi
}

while (($# > 0)); do
  case "$1" in
    --environment)
      need_value "$@"
      environment="$2"
      shift 2
      ;;
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
    --skip-build)
      skip_build=true
      shift
      ;;
    --skip-image-load)
      skip_image_load=true
      shift
      ;;
    --no-port-forward)
      no_port_forward=true
      shift
      ;;
    --skip-security)
      skip_security=true
      shift
      ;;
    --adopt-security)
      adopt_security=true
      shift
      ;;
    --db-password)
      need_value "$@"
      db_password="$2"
      shift 2
      ;;
    --jwt-secret)
      need_value "$@"
      jwt_secret="$2"
      shift 2
      ;;
    --admin-password)
      need_value "$@"
      admin_password="$2"
      shift 2
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

if [[ "$skip_security" == true && "$adopt_security" == true ]]; then
  echo '--skip-security y --adopt-security no se pueden combinar.' >&2
  exit 2
fi

case "$environment" in
  dev|prod) ;;
  *)
    echo "--environment debe ser dev o prod (recibido: $environment)." >&2
    exit 2
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
source "$script_dir/lib/security-stack.sh"
secrets_file=""

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "No se encontro '$1' en PATH." >&2
    exit 1
  fi
}

cleanup_secrets_file() {
  if [[ -n "$secrets_file" ]]; then
    rm -f "$secrets_file"
  fi
}
trap cleanup_secrets_file EXIT

resource_base_name() {
  if [[ "$release_name" == *playhub* ]]; then
    printf '%s' "$release_name"
  else
    printf '%s' "$release_name-playhub"
  fi
}

yaml_single_quote() {
  local quote="'"
  printf "'%s'" "${1//$quote/$quote$quote}"
}

stop_helm_port_forward() {
  local name pid_file pid

  for name in backend frontend prometheus grafana; do
    pid_file="$project_root/logs/helm-port-forward-$name.pid"

    if [[ -f "$pid_file" ]]; then
      pid="$(cat "$pid_file")"

      if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        if [[ "$(process_name_of "$pid")" == *kubectl* ]]; then
          kill "$pid" 2>/dev/null || true
        fi
      fi

      rm -f "$pid_file"
    fi
  done
}

listeners_on_port() {
  local port="$1"

  if command -v lsof >/dev/null 2>&1; then
    lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null || true
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ano 2>/dev/null \
      | awk -v suffix=":$port" '$1 == "TCP" && $4 == "LISTENING" && index($2, suffix) == length($2) - length(suffix) + 1 { print $5 }' \
      | sort -u
  fi
}

process_name_of() {
  local pid="$1"

  if command -v ps >/dev/null 2>&1 && ps -p "$pid" -o comm= 2>/dev/null | grep -q .; then
    ps -p "$pid" -o comm= 2>/dev/null
  elif command -v tasklist >/dev/null 2>&1; then
    tasklist //FI "PID eq $pid" //NH //FO CSV 2>/dev/null | head -n 1 | cut -d, -f1 | tr -d '"'
  fi
}

free_port() {
  local port="$1"
  local pid name

  for pid in $(listeners_on_port "$port"); do
    name="$(process_name_of "$pid")"

    if [[ "$name" != *kubectl* ]]; then
      echo "El puerto $port ya esta ocupado por '$name' (PID $pid), que no es un port-forward." >&2
      echo "Liberalo o volve a ejecutar con --no-port-forward." >&2
      return 1
    fi

    echo "Liberando el puerto $port: port-forward previo (PID $pid)."

    if command -v taskkill >/dev/null 2>&1; then
      taskkill //F //PID "$pid" >/dev/null 2>&1 || true
    else
      kill "$pid" 2>/dev/null || true
    fi
  done

  sleep 1
}

start_helm_port_forward() {
  local name="$1"
  local service="$2"
  local port="$3"
  local optional="${4:-false}"
  local remote_port
  local pid_file="$project_root/logs/helm-port-forward-$name.pid"
  local log_file="$project_root/logs/helm-port-forward-$name.log"

  if ! remote_port="$(kubectl get service "$service" -n "$namespace" --ignore-not-found=true -o jsonpath='{.spec.ports[0].port}')"; then
    echo "No se pudo consultar el Service '$service'." >&2
    return 1
  fi
  if [[ "$optional" == true && -z "$remote_port" ]]; then
    echo "Service opcional '$service' deshabilitado; se omite su port-forward."
    return 0
  fi
  if [[ ! "$remote_port" =~ ^[0-9]+$ ]]; then
    echo "El Service '$service' no tiene un puerto disponible." >&2
    return 1
  fi

  if ! free_port "$port"; then
    return 1
  fi

  mkdir -p "$project_root/logs"

  kubectl port-forward -n "$namespace" "svc/$service" "$port:$remote_port" >"$log_file" 2>&1 &
  disown
  echo "$!" >"$pid_file"

  for _ in {1..10}; do
    if grep -q "Forwarding from" "$log_file" 2>/dev/null; then
      echo "Port-forward activo: svc/$service -> $port:$remote_port (log: $log_file)"
      return 0
    fi
    sleep 0.5
  done

  echo "No se pudo iniciar el port-forward de '$service'. Ultimas lineas de $log_file:" >&2
  tail -n 20 "$log_file" >&2 2>/dev/null || true
  return 1
}

require_command helm
require_command kubectl

current_context="$(kubectl config current-context)"
if [[ -z "$current_context" ]]; then
  echo "kubectl no tiene un contexto activo." >&2
  exit 1
fi

echo "Contexto Kubernetes: $current_context"
echo "Namespace del release: $namespace"
echo "Release: $release_name"
echo "Entorno: $environment"

cd "$project_root"

chart_path="helm-chart"
values_file="$chart_path/values-$environment.yaml"

if [[ ! -f "$chart_path/Chart.yaml" ]]; then
  echo "No se encontro $project_root/$chart_path/Chart.yaml. La carpeta helm-chart debe estar en la raiz del proyecto." >&2
  exit 1
fi

if [[ ! -f "$values_file" ]]; then
  echo "No se encontro $project_root/$values_file." >&2
  exit 1
fi

if [[ "$environment" == "prod" ]]; then
  if [[ -z "$db_password" || -z "$jwt_secret" || -z "$admin_password" ]]; then
    echo "En prod hay que pasar --db-password, --jwt-secret (48+ bytes UTF-8) y --admin-password." >&2
    exit 2
  fi
  if [[ "$(printf '%s' "$jwt_secret" | wc -c)" -lt 48 ]]; then
    echo '--jwt-secret requiere al menos 48 bytes UTF-8 para HS384.' >&2
    exit 2
  fi
  frontend_tag="v1.0-prod"
  frontend_api_url="http://playhub.local"
else
  frontend_tag="v1.0"
  frontend_api_url="http://localhost:8080"
fi

backend_image="playhub-backend:v1.0"
frontend_image="playhub-frontend:$frontend_tag"

if [[ "$skip_build" == false ]]; then
  require_command docker
  echo "Construyendo imagenes..."
  docker build --file backend/Dockerfile.prod --tag "$backend_image" backend
  docker build \
    --build-arg "NEXT_PUBLIC_API_URL=$frontend_api_url" \
    --file frontend/Dockerfile.prod \
    --tag "$frontend_image" \
    frontend
else
  echo "Aviso: se omitio la construccion de imagenes." >&2
fi

if [[ "$skip_image_load" == false ]]; then
  if [[ "$current_context" == "minikube" ]]; then
    require_command minikube
    require_command docker
    echo "Cargando imagenes en Minikube..."
    mkdir -p "$project_root/.tmp"
    archive_directory="$(mktemp -d "$project_root/.tmp/helm-images.XXXXXXXX")"
    image_archive="$archive_directory/images.tar"
    import_status=0
    docker save --output "$image_archive" "$backend_image" "$frontend_image" || import_status=$?
    if [[ "$import_status" -eq 0 ]]; then
      minikube image load --overwrite=true "$image_archive" || import_status=$?
    fi
    rm -f "$image_archive"
    rmdir "$archive_directory"
    if [[ "$import_status" -ne 0 ]]; then exit "$import_status"; fi
  else
    echo "Aviso: el contexto '$current_context' no es minikube; no se cargaron las imagenes. Deben existir en el cluster." >&2
  fi
else
  echo "Aviso: se omitio la carga de imagenes en el cluster." >&2
fi

echo "Validando el chart (helm lint)..."
helm lint "$chart_path" -f "$values_file"

if [[ "$skip_security" == false ]]; then
  security_args=()
  if [[ "$adopt_security" == true ]]; then security_args+=(--adopt-existing); fi
  initialize_playhub_security "$project_root" "${security_args[@]}"
else
  echo "Se omite la instalacion de Kyverno y Falco (--skip-security)."
fi

echo "Instalando / actualizando el release con Helm (entorno $environment)..."
helm_args=(
  upgrade --install "$release_name" "$chart_path"
  -f "$values_file"
  -n "$namespace" --create-namespace
  --wait --timeout 5m
)

if [[ "$environment" == "prod" ]]; then
  mkdir -p "$project_root/.tmp"
  secrets_file="$project_root/.tmp/helm-secrets.$$.yaml"
  (umask 077 && : >"$secrets_file")
  {
    echo "secrets:"
    echo "  dbPassword: $(yaml_single_quote "$db_password")"
    echo "  jwtSecret: $(yaml_single_quote "$jwt_secret")"
    echo "  adminPassword: $(yaml_single_quote "$admin_password")"
  } >"$secrets_file"
  helm_args+=(-f ".tmp/helm-secrets.$$.yaml")
fi

if ! helm "${helm_args[@]}"; then
  echo "El despliegue no se completo. Estado actual del namespace:" >&2
  kubectl get pods -n "$namespace" -o wide || true
  kubectl get events -n "$namespace" --sort-by=.lastTimestamp || true
  exit 1
fi

echo
echo "Pods, servicios y volumenes del release:"
kubectl get pods,svc,pvc -n "$namespace"

echo
echo "Ejecutando helm test..."
helm test "$release_name" -n "$namespace"

base_name="$(resource_base_name)"
echo

if [[ "$environment" == "prod" ]]; then
  echo "Acceso por Ingress: http://playhub.local"
  echo "Requiere: minikube addons enable ingress, 'minikube tunnel' corriendo y"
  echo "la linea '127.0.0.1 playhub.local' en el archivo hosts del sistema."
fi
if [[ "$no_port_forward" == false ]]; then
  stop_helm_port_forward

  access_ok=true
  if [[ "$environment" == "dev" ]]; then
    start_helm_port_forward backend "$base_name-backend" 8080 || access_ok=false
    start_helm_port_forward frontend "$base_name-frontend" 5745 || access_ok=false
  fi
  start_helm_port_forward prometheus "$base_name-prometheus" 9090 true || access_ok=false
  start_helm_port_forward grafana "$base_name-grafana" 3000 true || access_ok=false

  echo

  if [[ "$access_ok" == false ]]; then
    echo "El despliegue termino, pero algun port-forward no pudo iniciarse (ver mensajes arriba)." >&2
    exit 1
  fi

  if [[ "$environment" == "dev" ]]; then
    echo "Frontend disponible en: http://localhost:5745"
    echo "Backend disponible en:  http://localhost:8080/actuator/health"
  fi
  echo "Monitoreo habilitado: Prometheus http://localhost:9090 y Grafana http://localhost:3000"
  echo "Para detener los accesos y limpiar el release: bash scripts/cleanup-helm.sh"
else
  echo "Aviso: se omitio el inicio automatico de port-forward (--no-port-forward)." >&2
  echo "Manual: kubectl port-forward -n $namespace svc/$base_name-backend 8080:8080"
  echo "        kubectl port-forward -n $namespace svc/$base_name-frontend 5745:5745"
  echo "        kubectl port-forward -n $namespace svc/$base_name-prometheus 9090:9090"
  echo "        kubectl port-forward -n $namespace svc/$base_name-grafana 3000:3000"
fi

