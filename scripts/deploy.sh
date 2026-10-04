#!/usr/bin/env bash

set -euo pipefail

deploy_green=false
cluster_type="auto"
cluster_name=""
skip_build=false
skip_image_load=false
frontend_api_url="http://localhost:8080"
no_port_forward=false

usage() {
  printf '%s\n' \
    "Uso: scripts/deploy.sh [opciones]" \
    "" \
    "Opciones:" \
    "  --deploy-green              Construye y despliega tambien el slot Green." \
    "  --cluster-type TIPO         auto|docker-desktop|kind|minikube|k3d|none." \
    "  --cluster-name NOMBRE       Perfil/nombre del cluster local." \
    "  --frontend-api-url URL      URL publica del backend (default: http://localhost:8080)." \
    "  --skip-build                No reconstruye las imagenes." \
    "  --skip-image-load           No importa las imagenes al runtime del cluster." \
    "  --no-port-forward           No inicia los kubectl port-forward de backend/frontend." \
    "  -h, --help                  Muestra esta ayuda."
}

while (($# > 0)); do
  case "$1" in
    --deploy-green)
      deploy_green=true
      shift
      ;;
    --cluster-type)
      if (($# < 2)); then
        echo "Falta el valor de --cluster-type." >&2
        exit 2
      fi
      cluster_type="$2"
      shift 2
      ;;
    --cluster-name)
      if (($# < 2)); then
        echo "Falta el valor de --cluster-name." >&2
        exit 2
      fi
      cluster_name="$2"
      shift 2
      ;;
    --frontend-api-url)
      if (($# < 2)); then
        echo "Falta el valor de --frontend-api-url." >&2
        exit 2
      fi
      frontend_api_url="$2"
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

case "$cluster_type" in
  auto|docker-desktop|kind|minikube|k3d|none)
    ;;
  *)
    echo "Tipo de cluster invalido: $cluster_type" >&2
    exit 2
    ;;
esac

if [[ ! "$frontend_api_url" =~ ^https?:// ]]; then
  echo "--frontend-api-url debe comenzar con http:// o https://" >&2
  exit 2
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "No se encontro '$1' en PATH." >&2
    exit 1
  fi
}

resolve_cluster_type() {
  if [[ "$cluster_type" != "auto" ]]; then
    printf '%s' "$cluster_type"
    return
  fi

  case "$current_context" in
    docker-desktop)
      printf '%s' "docker-desktop"
      ;;
    kind-*)
      printf '%s' "kind"
      ;;
    k3d-*)
      printf '%s' "k3d"
      ;;
    minikube)
      printf '%s' "minikube"
      ;;
    *)
      printf '%s\n' \
        "No se pudo detectar el tipo de cluster a partir del contexto '$current_context'." \
        "Indicalo con --cluster-type docker-desktop|kind|minikube|k3d." \
        "Si las imagenes ya fueron precargadas manualmente, usa --cluster-type none." >&2
      exit 1
      ;;
  esac
}

resolve_cluster_name() {
  if [[ -n "$cluster_name" ]]; then
    printf '%s' "$cluster_name"
    return
  fi

  case "$resolved_cluster_type" in
    kind)
      if [[ "$current_context" == kind-* ]]; then
        printf '%s' "${current_context#kind-}"
      else
        printf '%s' "kind"
      fi
      ;;
    k3d)
      if [[ "$current_context" == k3d-* ]]; then
        printf '%s' "${current_context#k3d-}"
      else
        echo "Debes indicar --cluster-name para un cluster k3d no detectable." >&2
        exit 1
      fi
      ;;
    minikube)
      printf '%s' "$current_context"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

load_images() {
  case "$resolved_cluster_type" in
    docker-desktop)
      echo "Docker Desktop usara las imagenes construidas en su image store actual."
      ;;
    kind)
      require_command kind
      kind load docker-image "${images[@]}" --name "$resolved_cluster_name"
      ;;
    minikube)
      require_command minikube
      for image in "${images[@]}"; do
        minikube -p "$resolved_cluster_name" image load "$image"
      done
      ;;
    k3d)
      require_command k3d
      k3d image import "${images[@]}" --cluster "$resolved_cluster_name"
      ;;
    none)
      echo "Aviso: se omitio la carga automatica; las imagenes deben existir en todos los nodos." >&2
      ;;
  esac
}

image_check_pods=()

cleanup_image_checks() {
  for pod in "${image_check_pods[@]}"; do
    kubectl delete pod "$pod" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
  done
}

trap cleanup_image_checks EXIT

check_cluster_image() {
  local image="$1"
  local index="$2"
  local pod="playhub-image-check-${index}-$$"
  local phase=""
  local waiting_reason=""

  image_check_pods+=("$pod")
  kubectl delete pod "$pod" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true

  kubectl run "$pod" \
    --image="$image" \
    --image-pull-policy=Never \
    --labels=app=playhub-image-check \
    --restart=Never \
    --command -- sh -c 'exit 0'

  for _ in {1..45}; do
    phase="$(kubectl get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)"

    if [[ "$phase" == "Succeeded" ]]; then
      echo "Imagen disponible en Kubernetes: $image"
      kubectl delete pod "$pod" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
      return
    fi

    waiting_reason="$(
      kubectl get pod "$pod" \
        -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' \
        2>/dev/null || true
    )"

    case "$waiting_reason" in
      ErrImageNeverPull|ImagePullBackOff|InvalidImageName)
        kubectl describe pod "$pod" || true
        echo "La imagen '$image' no esta disponible en el runtime del nodo ($waiting_reason)." >&2
        return 1
        ;;
    esac

    if [[ "$phase" == "Failed" ]]; then
      kubectl describe pod "$pod" || true
      echo "La comprobacion de la imagen '$image' termino en estado Failed." >&2
      return 1
    fi

    sleep 1
  done

  kubectl describe pod "$pod" || true
  echo "Tiempo agotado comprobando la imagen '$image'." >&2
  return 1
}

show_deployment_diagnostics() {
  echo "El despliegue no se completo. Estado actual del cluster:" >&2
  kubectl get pods -o wide || true
  kubectl get events --sort-by=.lastTimestamp || true
}

show_job_diagnostics() {
  local job="$1"

  echo "Diagnostico de job/$job:" >&2
  kubectl get job "$job" -o wide || true
  kubectl describe job "$job" || true
  kubectl get pods -l "job-name=$job" -o wide || true
  kubectl logs -l "job-name=$job" \
    --all-containers=true \
    --prefix=true \
    --tail=-1 || true
}

wait_for_job() {
  local job="$1"
  local timeout_seconds="$2"
  local poll_interval_seconds=2
  local started_at
  local complete
  local failed
  local reason

  started_at="$(date +%s)"

  while (( $(date +%s) - started_at < timeout_seconds )); do
    complete="$(
      kubectl get job "$job" \
        -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'
    )"

    if [[ "$complete" == "True" ]]; then
      echo "Job completado: $job"
      return 0
    fi

    failed="$(
      kubectl get job "$job" \
        -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}'
    )"

    if [[ "$failed" == "True" ]]; then
      reason="$(
        kubectl get job "$job" \
          -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}'
      )"
      echo "El Job job/$job fallo: ${reason:-sin motivo informado}." >&2
      return 1
    fi

    sleep "$poll_interval_seconds"
  done

  echo "Tiempo agotado esperando que job/$job termine (${timeout_seconds}s)." >&2
  return 1
}

stop_tracked_port_forward() {
  local name="$1"
  local pid_file="$project_root/logs/port-forward-$name.pid"
  local pid

  if [[ -f "$pid_file" ]]; then
    pid="$(cat "$pid_file")"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi

    rm -f "$pid_file"
  fi
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

# Un port-forward anterior puede seguir ocupando el puerto y hacer fallar el bind
# en silencio, dejando la app inaccesible con ERR_CONNECTION_REFUSED.
free_stale_port_forward() {
  local port="$1"
  local pid
  local name

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

start_tracked_port_forward() {
  local name="$1"
  local service="$2"
  local port_mapping="$3"
  local pid_file="$project_root/logs/port-forward-$name.pid"
  local log_file="$project_root/logs/port-forward-$name.log"

  stop_tracked_port_forward "$name"

  if ! free_stale_port_forward "${port_mapping%%:*}"; then
    return 1
  fi

  mkdir -p "$project_root/logs"

  kubectl port-forward "svc/$service" "$port_mapping" >"$log_file" 2>&1 &
  disown

  echo "$!" >"$pid_file"

  for _ in {1..10}; do
    if grep -q "Forwarding from" "$log_file" 2>/dev/null; then
      echo "Port-forward activo: svc/$service -> $port_mapping (log: $log_file)"
      return 0
    fi
    sleep 0.5
  done

  echo "No se pudo iniciar el port-forward de '$service'. Ultimas lineas de $log_file:" >&2
  tail -n 20 "$log_file" >&2 2>/dev/null || true
  return 1
}

require_command kubectl

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
migration_directory="$project_root/backend/src/main/resources/db/migration"

if [[ ! -d "$migration_directory" ]]; then
  echo "No se encontro el directorio de migraciones: $migration_directory" >&2
  exit 1
fi

current_context="$(kubectl config current-context)"

if [[ -z "$current_context" ]]; then
  echo "kubectl no tiene un contexto activo." >&2
  exit 1
fi

current_namespace="$(
  kubectl config view --minify -o jsonpath='{..namespace}'
)"
current_namespace="${current_namespace:-default}"

resolved_cluster_type="$(resolve_cluster_type)"
resolved_cluster_name="$(resolve_cluster_name)"

echo "Contexto Kubernetes: $current_context"
echo "Namespace: $current_namespace"
echo "Tipo de cluster: $resolved_cluster_type"

if [[ -n "$resolved_cluster_name" ]]; then
  echo "Nombre del cluster: $resolved_cluster_name"
fi

if [[ "$resolved_cluster_type" == "minikube" ]]; then
  require_command minikube

  if ! minikube -p "$resolved_cluster_name" status; then
    echo "El perfil Minikube '$resolved_cluster_name' no esta iniciado." >&2
    echo "Ejecuta: minikube start -p $resolved_cluster_name" >&2
    exit 1
  fi
fi

kubectl cluster-info

images=(
  "playhub-backend:v1.0"
  "playhub-frontend:v1.0"
)

if [[ "$deploy_green" == true ]]; then
  images+=(
    "playhub-backend:v2.0"
    "playhub-frontend:v2.0"
  )
fi

manifest_files=(
  "k8s/configmap.yaml"
  "k8s/secret.yaml"
  "k8s/postgres-pvc.yaml"
  "k8s/postgres-service.yaml"
  "k8s/postgres-deployment.yaml"
  "k8s/migration-job.yaml"
  "k8s/backend-service.yaml"
  "k8s/frontend-service.yaml"
  "k8s/backend-blue-deployment.yaml"
  "k8s/frontend-blue-deployment.yaml"
)

if [[ "$deploy_green" == true ]]; then
  manifest_files+=(
    "k8s/backend-green-deployment.yaml"
    "k8s/frontend-green-deployment.yaml"
  )
fi

cd "$project_root"

echo "Validando manifiestos contra el cluster..."

for manifest_file in "${manifest_files[@]}"; do
  kubectl apply --dry-run=client --validate=strict -f "$manifest_file"
done

if [[ "$skip_build" == false ]]; then
  require_command docker
  docker info --format '{{.ServerVersion}}'

  echo "Construyendo imagenes Blue..."

  docker build \
    --file backend/Dockerfile.prod \
    --tag playhub-backend:v1.0 \
    backend

  docker build \
    --build-arg "NEXT_PUBLIC_API_URL=$frontend_api_url" \
    --file frontend/Dockerfile.prod \
    --tag playhub-frontend:v1.0 \
    frontend

  if [[ "$deploy_green" == true ]]; then
    echo "Construyendo imagenes Green..."

    docker build \
      --file backend/Dockerfile.prod \
      --tag playhub-backend:v2.0 \
      backend

    docker build \
      --build-arg "NEXT_PUBLIC_API_URL=$frontend_api_url" \
      --file frontend/Dockerfile.prod \
      --tag playhub-frontend:v2.0 \
      frontend
  fi
else
  echo "Aviso: se omitio la construccion de imagenes." >&2
fi

if [[ "$skip_image_load" == false ]]; then
  load_images
else
  echo "Aviso: se omitio la carga de imagenes en el cluster." >&2
fi

echo "Comprobando que Kubernetes puede iniciar las imagenes..."

for index in "${!images[@]}"; do
  check_cluster_image "${images[$index]}" "$((index + 1))"
done

echo "Aplicando configuracion y PostgreSQL..."

kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl rollout status deployment/playhub-postgres --timeout=180s

echo "Cargando las migraciones SQL en Kubernetes..."

kubectl create configmap playhub-migration-sql \
  --from-file=backend/src/main/resources/db/migration \
  --dry-run=client \
  -o json | kubectl apply -f -

echo "Ejecutando el Job de Flyway..."

kubectl delete job playhub-migrations --ignore-not-found=true
kubectl apply -f k8s/migration-job.yaml

if ! wait_for_job playhub-migrations 300; then
  show_job_diagnostics playhub-migrations
  exit 1
fi

kubectl logs job/playhub-migrations

echo "Desplegando Services y el slot Blue..."

backend_blue_existed=false
frontend_blue_existed=false

if kubectl get deployment playhub-backend-blue >/dev/null 2>&1; then
  backend_blue_existed=true
fi

if kubectl get deployment playhub-frontend-blue >/dev/null 2>&1; then
  frontend_blue_existed=true
fi

kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/frontend-service.yaml
kubectl apply -f k8s/backend-blue-deployment.yaml
kubectl apply -f k8s/frontend-blue-deployment.yaml

if [[ "$backend_blue_existed" == true ]]; then
  kubectl rollout restart deployment/playhub-backend-blue
fi

if [[ "$frontend_blue_existed" == true ]]; then
  kubectl rollout restart deployment/playhub-frontend-blue
fi

if ! kubectl rollout status deployment/playhub-backend-blue --timeout=300s; then
  show_deployment_diagnostics
  exit 1
fi

if ! kubectl rollout status deployment/playhub-frontend-blue --timeout=300s; then
  show_deployment_diagnostics
  exit 1
fi

if [[ "$deploy_green" == true ]]; then
  echo "Desplegando tambien el slot Green..."

  backend_green_existed=false
  frontend_green_existed=false

  if kubectl get deployment playhub-backend-green >/dev/null 2>&1; then
    backend_green_existed=true
  fi

  if kubectl get deployment playhub-frontend-green >/dev/null 2>&1; then
    frontend_green_existed=true
  fi

  kubectl apply -f k8s/backend-green-deployment.yaml
  kubectl apply -f k8s/frontend-green-deployment.yaml

  if [[ "$backend_green_existed" == true ]]; then
    kubectl rollout restart deployment/playhub-backend-green
  fi

  if [[ "$frontend_green_existed" == true ]]; then
    kubectl rollout restart deployment/playhub-frontend-green
  fi

  if ! kubectl rollout status deployment/playhub-backend-green --timeout=300s; then
    show_deployment_diagnostics
    exit 1
  fi

  if ! kubectl rollout status deployment/playhub-frontend-green --timeout=300s; then
    show_deployment_diagnostics
    exit 1
  fi
fi

echo
echo "Despliegue terminado. Slot activo: Blue"

kubectl get pods
kubectl get jobs
kubectl get pvc
kubectl get services

if [[ "$no_port_forward" == false ]]; then
  echo
  echo "Iniciando port-forward de backend y frontend..."

  port_forward_failed=false

  start_tracked_port_forward backend playhub-backend 8080:8080 || port_forward_failed=true
  start_tracked_port_forward frontend playhub-frontend 5745:5745 || port_forward_failed=true

  echo

  if [[ "$port_forward_failed" == true ]]; then
    echo "El despliegue termino, pero algun port-forward no pudo iniciarse (ver mensajes arriba)." >&2
    echo "La app NO es accesible desde el navegador hasta que se resuelva." >&2
    exit 1
  fi

  echo "Frontend disponible en: http://localhost:5745"
  echo "Backend disponible en:  http://localhost:8080"
  echo "Para detenerlos: kill \$(cat logs/port-forward-backend.pid) \$(cat logs/port-forward-frontend.pid)"
else
  echo "Aviso: se omitio el inicio automatico de port-forward (--no-port-forward)." >&2
fi
