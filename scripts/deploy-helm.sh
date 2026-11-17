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
kubeconfig_arg=""
registry=""
image_tag=""
public_host=""
ingress_class=""
tls_enabled=false
tls_issuer="letsencrypt-prod"
tls_secret_name=""
public_scheme_arg=""
namespace_created=false
registry_secret_name=""
secrets_file_arg=""
verify_public=false
monitoring=true
monitoring_mode=""
resource_profile=""
recover_pending_install=false
wait_timeout=""

usage() {
  printf '%s\n' \
    "Uso: scripts/deploy-helm.sh [opciones]" \
    "" \
    "Instala o actualiza el release de Helm de PlayHub y verifica el despliegue." \
    "Sin --registry funciona contra un cluster local (minikube): construye y carga las imagenes." \
    "Con --registry funciona contra un cluster remoto: usa las imagenes ya publicadas, no construye," \
    "no carga imagenes y no abre port-forward; por defecto instala Kyverno y Falco" \
    "(usar --skip-security en un cluster compartido o --adopt-security si ya existen)." \
    "" \
    "Opciones generales:" \
    "  --environment dev|prod      Archivo de values a usar (default: dev)." \
    "  --namespace NOMBRE          Namespace del release (default: playhub-helm)." \
    "  --release-name NOMBRE       Nombre del release (default: playhub)." \
    "  --kubeconfig RUTA           Kubeconfig a usar (default: \$KUBECONFIG o el contexto actual)." \
    "  --skip-build                No reconstruye las imagenes." \
    "  --skip-image-load           No importa las imagenes a Minikube." \
    "  --no-port-forward           No abre los accesos de aplicacion ni monitoreo." \
    "  --no-monitoring             Deshabilita Prometheus/Grafana del release." \
    "  --monitoring-mode MODO      namespace (sin RBAC/nodos) o cluster (infraestructura)." \
    "  --resource-profile PERFIL   lab (cuota compartida) o standard (default: lab remoto)." \
    "  --recover-pending-install   Recupera solo un primer install pendiente de mas de 1 hora." \
    "  --skip-security             No instala ni registra Kyverno/Falco (cluster compartido)." \
    "  --adopt-security            Registra un Kyverno/Falco existente con las versiones del proyecto." \
    "  --wait-timeout DURACION     Timeout de helm --wait (default: 5m local, 10m remoto)." \
    "  --secrets-file RUTA         Archivo .env con DB_PASSWORD, JWT_SECRET y ADMIN_PASSWORD." \
    "  --db-password VALOR         Solo prod/remoto: contrasena de PostgreSQL." \
    "  --jwt-secret VALOR          Solo prod/remoto: secreto JWT (48+ bytes UTF-8)." \
    "  --admin-password VALOR      Solo prod/remoto: contrasena del administrador." \
    "" \
    "Opciones de cluster remoto:" \
    "  --registry PREFIJO          Registro/cuenta de las imagenes (ej: docker.io/usuario)." \
    "  --image-tag TAG             Tag publicado de backend/frontend (requiere --registry)." \
    "  --registry-secret NOMBRE    imagePullSecret a crear (default: regcred)." \
    "                              Requiere las variables REG_USER y REG_PASS." \
    "  --public-host HOST          Host publico del Ingress (ej: playhub.com)." \
    "  --public-scheme http|https  Esquema publico para la app (default: https si --tls, si no http)." \
    "  --ingress-class CLASE       IngressClass del cluster (default: nginx)." \
    "  --tls                       Gestiona TLS del Ingress con cert-manager (requiere ClusterIssuer)." \
    "  --tls-issuer NOMBRE         ClusterIssuer de cert-manager (default: letsencrypt-prod)." \
    "  --tls-secret NOMBRE         Secret TLS (default: <release>-tls)." \
    "  --verify                    Verifica /login y la ruta /api hacia el backend." \
    "" \
    "  -h, --help                  Muestra esta ayuda." \
    "" \
    "Ejemplos:" \
    "  scripts/deploy-helm.sh" \
    "  scripts/deploy-helm.sh --environment prod --db-password X --jwt-secret Y --admin-password Z" \
    "  REG_USER=usuario REG_PASS=token scripts/deploy-helm.sh --environment prod \\" \
    "    --kubeconfig ~/.kube/playhub.yaml --registry docker.io/usuario --image-tag 42-a1b2c3d \\" \
    "    --public-host playhub.com --ingress-class nginx --tls --verify"
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
    --kubeconfig)
      need_value "$@"
      kubeconfig_arg="$2"
      shift 2
      ;;
    --registry)
      need_value "$@"
      registry="$2"
      shift 2
      ;;
    --image-tag)
      need_value "$@"
      image_tag="$2"
      shift 2
      ;;
    --registry-secret)
      need_value "$@"
      registry_secret_name="$2"
      shift 2
      ;;
    --public-host)
      need_value "$@"
      public_host="$2"
      shift 2
      ;;
    --public-scheme)
      need_value "$@"
      public_scheme_arg="$2"
      shift 2
      ;;
    --ingress-class)
      need_value "$@"
      ingress_class="$2"
      shift 2
      ;;
    --tls)
      tls_enabled=true
      shift
      ;;
    --tls-issuer)
      need_value "$@"
      tls_issuer="$2"
      shift 2
      ;;
    --tls-secret)
      need_value "$@"
      tls_secret_name="$2"
      shift 2
      ;;
    --secrets-file)
      need_value "$@"
      secrets_file_arg="$2"
      shift 2
      ;;
    --verify)
      verify_public=true
      shift
      ;;
    --no-monitoring)
      monitoring=false
      shift
      ;;
    --monitoring-mode)
      need_value "$@"
      monitoring_mode="$2"
      shift 2
      ;;
    --resource-profile)
      need_value "$@"
      resource_profile="$2"
      shift 2
      ;;
    --recover-pending-install)
      recover_pending_install=true
      shift
      ;;
    --wait-timeout)
      need_value "$@"
      wait_timeout="$2"
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
override_file=""

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "No se encontro '$1' en PATH." >&2
    exit 1
  fi
}

yaml_single_quote() {
  local quote="'"
  printf "'%s'" "${1//$quote/$quote$quote}"
}

kubectl_request() {
  kubectl --request-timeout=20s "$@"
}

check_cluster_connection() {
  local attempt response
  for attempt in 1 2 3; do
    if response="$(kubectl_request get --raw /version 2>&1)"; then
      kubernetes_version_response="$response"
      return 0
    fi
    echo "No se pudo consultar la API Kubernetes (intento $attempt/3): $response" >&2
    case "$response" in
      *Unauthorized*|*unauthorized*|*Forbidden*|*forbidden*|*x509:*) break ;;
    esac
    if (( attempt < 3 )); then sleep 2; fi
  done
  echo "API Kubernetes inaccesible: $current_server (contexto $current_context)." >&2
  echo 'Revisar conectividad desde el agente Jenkins (DNS, puerto 443, proxy/VPN/firewall), disponibilidad del cluster y kubeconfig.' >&2
  echo 'Se cancela antes de ejecutar Helm; aumentar --wait-timeout no resuelve una API inaccesible.' >&2
  return 1
}

print_kubernetes_version() {
  local server_version minor
  server_version="$(printf '%s\n' "$kubernetes_version_response" | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p')"
  if [[ -z "$server_version" ]]; then
    return
  fi
  echo "Kubernetes: $server_version"
  minor="$(printf '%s' "$server_version" | sed -E 's/^v?[0-9]+\.([0-9]+).*/\1/')"
  if [[ "$minor" =~ ^[0-9]+$ ]] && (( minor < 28 )); then
    echo "Aviso: Kubernetes $server_version es antiguo; verificar compatibilidad con las versiones de Kyverno y Falco del proyecto." >&2
  fi
}

check_remote_security_permissions() {
  local permission missing=()
  local permissions=(
    'create customresourcedefinitions.apiextensions.k8s.io'
    'create clusterroles.rbac.authorization.k8s.io'
    'create clusterrolebindings.rbac.authorization.k8s.io'
    'create validatingwebhookconfigurations.admissionregistration.k8s.io'
    'create mutatingwebhookconfigurations.admissionregistration.k8s.io'
    'create namespaces'
  )
  for permission in "${permissions[@]}"; do
    if ! kubectl auth can-i $permission >/dev/null 2>&1; then
      missing+=("$permission")
    fi
  done
  if ((${#missing[@]})); then
    echo 'El kubeconfig no tiene permisos de administrador para instalar Kyverno/Falco:' >&2
    printf '  - %s\n' "${missing[@]}" >&2
    echo 'Usar --skip-security en un cluster compartido o --adopt-security con un stack ya instalado.' >&2
    exit 1
  fi
}

ensure_namespace() {
  local result
  namespace_created=false
  if result="$(kubectl_request get namespace "$namespace" --ignore-not-found=true -o name 2>&1)"; then
    if [[ -n "$result" ]]; then return 0; fi
  else
    if [[ "$result" == *Forbidden* || "$result" == *forbidden* ]]; then
      echo "Aviso: no se puede consultar el namespace '$namespace'; se asume que ya existe." >&2
      return 0
    fi
    echo "No se pudo consultar el namespace '$namespace': $result" >&2
    return 1
  fi
  kubectl_request create namespace "$namespace" --dry-run=client -o yaml | kubectl_request apply -f - >/dev/null
  namespace_created=true
}

report_deploy_failure() {
  mkdir -p "$project_root/reports"
  {
    echo "El despliegue no se completo. API: $current_server; namespace: $namespace; release: $release_name."
    if kubectl_request get --raw /version >/dev/null; then
      echo 'Estado actual de los recursos y eventos (Helm puede haber revertido los recursos con --atomic):'
      kubectl_request get deployments,replicasets,pods,svc,pvc,ingress -n "$namespace" -o wide || true
      kubectl_request describe replicasets -n "$namespace" -l "app.kubernetes.io/instance=$release_name" || true
      kubectl_request get resourcequota,limitrange -n "$namespace" || true
      kubectl_request get events -n "$namespace" --sort-by=.lastTimestamp || true
    else
      echo 'La API Kubernetes sigue inaccesible. Se omiten las demas consultas para no prolongar el fallo.'
      echo 'Revisar la conexion desde el agente Jenkins y el estado del cluster antes de reintentar.'
    fi
  } 2>&1 | tee "$project_root/reports/deploy-diagnostics.txt"
}

check_helm_release_state() {
  local history state pvc_policy python
  if ! history="$(helm history "$release_name" -n "$namespace" -o json 2>&1)"; then
    if [[ "$history" == *'release: not found'* ]]; then return 0; fi
    echo "No se pudo consultar el historial de Helm: $history" >&2
    return 1
  fi
  python="$(playhub_security_python)"
  state="$(printf '%s' "$history" | "$python" "$script_dir/lib/helm-release-state.py")"
  if [[ "$state" == ready ]]; then return 0; fi
  if [[ "$state" != stale-install || "$recover_pending_install" != true ]]; then
    echo 'El release tiene una operacion pendiente. No se modifica una operacion reciente ni un upgrade pendiente.' >&2
    echo 'Solo un primer install pendiente de mas de una hora se puede recuperar con --recover-pending-install.' >&2
    return 1
  fi
  pvc_policy="$(kubectl_request get pvc "$(resource_base_name)-postgres-data" -n "$namespace" --ignore-not-found=true -o 'jsonpath={.metadata.name}{" "}{.metadata.annotations.helm\.sh/resource-policy}')"
  if [[ -n "${pvc_policy//[[:space:]]/}" && "$pvc_policy" != *' keep' ]]; then
    echo 'Se cancela la recuperacion: el PVC de PostgreSQL no tiene helm.sh/resource-policy=keep.' >&2
    return 1
  fi
  if [[ -n "${pvc_policy//[[:space:]]/}" ]]; then
    helm get manifest "$release_name" -n "$namespace" \
      | "$python" "$script_dir/lib/helm-release-state.py" --retained-pvc "$(resource_base_name)-postgres-data"
  fi
  echo 'Recuperando el primer install abandonado: se retiran los recursos del release y se conserva el PVC de PostgreSQL.'
  helm uninstall "$release_name" -n "$namespace" --keep-history --no-hooks --wait --timeout "$wait_timeout"
}

prepare_falco_namespace() {
  if kubectl get namespace falco >/dev/null 2>&1; then
    if kubectl -n falco get configmap playhub-security-owner >/dev/null 2>&1; then
      kubectl label namespace falco pod-security.kubernetes.io/enforce=privileged --overwrite >/dev/null
    fi
    return
  fi
  kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl label namespace falco pod-security.kubernetes.io/enforce=privileged --overwrite >/dev/null
}

report_security_status() {
  echo
  echo "Estado del stack de seguridad:"
  kubectl get clusterpolicy 2>/dev/null || true
  kubectl get validatingpolicy 2>/dev/null || true
  kubectl -n falco get daemonset,pods 2>/dev/null || true
  helm list -n falco 2>/dev/null || true
}

cleanup_temp_files() {
  if [[ -n "$override_file" ]]; then
    rm -f "$override_file"
  fi
}
trap cleanup_temp_files EXIT

load_secrets_file() {
  local file="$1" line key value
  local found_db=0 found_jwt=0 found_admin=0

  if [[ ! -f "$file" ]]; then
    echo "No se encontro el archivo de secretos '$file'." >&2
    exit 2
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
    case "$key" in
      DB_PASSWORD)
        db_password="$value"; found_db=1 ;;
      JWT_SECRET)
        jwt_secret="$value"; found_jwt=1 ;;
      ADMIN_PASSWORD)
        admin_password="$value"; found_admin=1 ;;
      ''|*)
        echo "Clave desconocida en '$file': '$key' (se esperan DB_PASSWORD, JWT_SECRET, ADMIN_PASSWORD)." >&2
        exit 2
        ;;
    esac
  done < "$file"

  if [[ "$found_db" -ne 1 || "$found_jwt" -ne 1 || "$found_admin" -ne 1 ]]; then
    echo "El archivo '$file' debe definir DB_PASSWORD, JWT_SECRET y ADMIN_PASSWORD." >&2
    exit 2
  fi
}

resource_base_name() {
  if [[ "$release_name" == *playhub* ]]; then
    printf '%s' "$release_name"
  else
    printf '%s' "$release_name-playhub"
  fi
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

if [[ -n "$secrets_file_arg" ]]; then
  load_secrets_file "$secrets_file_arg"
fi

remote=false
if [[ -n "$registry" ]]; then
  remote=true
fi

if [[ -n "$registry" && -z "$image_tag" ]] || [[ -z "$registry" && -n "$image_tag" ]]; then
  echo '--registry y --image-tag deben usarse juntos.' >&2
  exit 2
fi

if [[ -n "$image_tag" ]]; then
  if [[ ! "$image_tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
    echo "Tag de imagen invalido: '$image_tag'." >&2
    exit 2
  fi
fi

if [[ -n "$registry" ]]; then
  case "$registry" in
    *://*|*/|/*|*[[:space:]]*)
      echo "Registry invalido: '$registry' (sin esquema, sin barra final, sin espacios)." >&2
      exit 2
      ;;
  esac
fi

if [[ -n "$public_host" ]]; then
  if [[ ! "$public_host" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo "Host publico invalido: '$public_host' (sin esquema ni ruta)." >&2
    exit 2
  fi
fi

if [[ "$tls_enabled" == true && -z "$public_host" ]]; then
  echo '--tls requiere --public-host.' >&2
  exit 2
fi

if [[ "$verify_public" == true && -z "$public_host" ]]; then
  echo '--verify requiere --public-host.' >&2
  exit 2
fi

if [[ -n "$public_scheme_arg" ]]; then
  case "$public_scheme_arg" in
    http|https) ;;
    *)
      echo "--public-scheme debe ser http o https (recibido: '$public_scheme_arg')." >&2
      exit 2
      ;;
  esac
  if [[ -z "$public_host" ]]; then
    echo '--public-scheme requiere --public-host.' >&2
    exit 2
  fi
  if [[ "$tls_enabled" == true && "$public_scheme_arg" == "http" ]]; then
    echo '--tls no es compatible con --public-scheme http.' >&2
    exit 2
  fi
fi

if [[ "$remote" == true ]]; then
  if [[ -z "$public_host" ]]; then
    echo 'El modo remoto (--registry) requiere --public-host.' >&2
    exit 2
  fi
  if [[ -z "${REG_USER:-}" || -z "${REG_PASS:-}" ]]; then
    echo 'En modo remoto hay que definir REG_USER y REG_PASS para crear el imagePullSecret.' >&2
    exit 2
  fi
  skip_build=true
  skip_image_load=true
  no_port_forward=true
  monitoring_mode="${monitoring_mode:-namespace}"
  resource_profile="${resource_profile:-lab}"
  ingress_class="${ingress_class:-nginx}"
  tls_secret_name="${tls_secret_name:-$release_name-tls}"
  registry_secret_name="${registry_secret_name:-regcred}"
  wait_timeout="${wait_timeout:-10m}"
else
  monitoring_mode="${monitoring_mode:-cluster}"
  resource_profile="${resource_profile:-standard}"
  wait_timeout="${wait_timeout:-5m}"
  if [[ -n "$public_host" ]]; then
    ingress_class="${ingress_class:-nginx}"
    tls_secret_name="${tls_secret_name:-$release_name-tls}"
  fi
fi

case "$monitoring_mode" in
  namespace|cluster) ;;
  *) echo '--monitoring-mode debe ser namespace o cluster.' >&2; exit 2 ;;
esac
case "$resource_profile" in
  lab|standard) ;;
  *) echo '--resource-profile debe ser lab o standard.' >&2; exit 2 ;;
esac

if [[ "$remote" == true || "$environment" == "prod" ]]; then
  if [[ -z "$db_password" || -z "$jwt_secret" || -z "$admin_password" ]]; then
    echo "En prod/remoto hay que pasar --secrets-file o --db-password, --jwt-secret y --admin-password." >&2
    exit 2
  fi
  if [[ "$(printf '%s' "$jwt_secret" | wc -c)" -lt 48 ]]; then
    echo 'El JWT secret requiere al menos 48 bytes UTF-8 para HS384.' >&2
    exit 2
  fi
fi

if [[ -n "$kubeconfig_arg" ]]; then
  if [[ "$kubeconfig_arg" != *:* && ! -f "$kubeconfig_arg" ]]; then
    echo "No se encontro el kubeconfig '$kubeconfig_arg'." >&2
    exit 1
  fi
  export KUBECONFIG="$kubeconfig_arg"
fi

if [[ "$remote" == true || "$verify_public" == true ]]; then
  require_command curl
fi

require_command helm
require_command kubectl

current_context="$(kubectl config current-context)"
if [[ -z "$current_context" ]]; then
  echo "kubectl no tiene un contexto activo." >&2
  exit 1
fi
current_server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"

echo "Contexto Kubernetes: $current_context${current_server:+ ($current_server)}"
echo "Namespace del release: $namespace"
echo "Release: $release_name"
echo "Entorno: $environment"
echo "Modo: $([[ "$remote" == true ]] && echo remoto || echo local)"
echo "Perfil de recursos: $resource_profile; monitoreo: $monitoring (modo $monitoring_mode)"

if [[ "$remote" == true ]]; then
  check_cluster_connection
  print_kubernetes_version

  if [[ -n "$public_host" && -n "$ingress_class" ]]; then
    ingressclass_error="$(kubectl_request get ingressclass "$ingress_class" 2>&1 >/dev/null || true)"
    if [[ -n "$ingressclass_error" ]]; then
      if [[ "$ingressclass_error" == *Forbidden* || "$ingressclass_error" == *forbidden* ]]; then
        echo "Aviso: no se puede consultar la IngressClass '$ingress_class'; se asume que existe." >&2
      else
        echo "No se pudo validar la IngressClass '$ingress_class': $ingressclass_error" >&2
        exit 1
      fi
    fi
  fi

  if [[ "$tls_enabled" == true ]]; then
    if ! issuer_result="$(kubectl_request get "clusterissuer/$tls_issuer" 2>&1)"; then
      echo "No se pudo validar el ClusterIssuer '$tls_issuer': $issuer_result" >&2
      exit 1
    fi
  fi
fi

cd "$project_root"

chart_path="helm-chart"
values_file="$chart_path/values-$environment.yaml"
profile_file=""
if [[ "$resource_profile" == lab ]]; then profile_file="$chart_path/values-lab.yaml"; fi

if [[ ! -f "$chart_path/Chart.yaml" ]]; then
  echo "No se encontro $project_root/$chart_path/Chart.yaml. La carpeta helm-chart debe estar en la raiz del proyecto." >&2
  exit 1
fi

if [[ ! -f "$values_file" ]]; then
  echo "No se encontro $project_root/$values_file." >&2
  exit 1
fi

if [[ -n "$public_host" ]]; then
  if [[ -n "$public_scheme_arg" ]]; then
    public_scheme="$public_scheme_arg"
  elif [[ "$tls_enabled" == true ]]; then
    public_scheme="https"
  else
    public_scheme="http"
  fi
  public_url="$public_scheme://$public_host"
else
  public_scheme=""
  public_url=""
fi

if [[ "$remote" == true ]]; then
  backend_image="$registry/playhub-backend:$image_tag"
  frontend_image="$registry/playhub-frontend:$image_tag"
  registry_host="${registry%%/*}"
  case "$registry_host" in
    docker.io|index.docker.io) docker_server="https://index.docker.io/v1/" ;;
    *) docker_server="$registry_host" ;;
  esac
  frontend_api_url="$public_url"
else
  if [[ "$environment" == "prod" ]]; then
    frontend_tag="v1.0-prod"
    frontend_api_url="http://playhub.local"
  else
    frontend_tag="v1.0"
    frontend_api_url="http://localhost:8080"
  fi
  backend_image="playhub-backend:v1.0"
  frontend_image="playhub-frontend:$frontend_tag"
fi

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

if [[ "$skip_security" == false ]]; then
  if [[ "$remote" == true ]]; then
    check_remote_security_permissions
  fi
  security_args=()
  if [[ "$adopt_security" == true ]]; then
    echo "Registrando el stack Kyverno/Falco existente (--adopt-security)..."
    security_args+=(--adopt-existing)
  else
    echo "Instalando Kyverno y Falco..."
    if [[ "$remote" == true ]]; then
      prepare_falco_namespace
    fi
  fi
  initialize_playhub_security "$project_root" "${security_args[@]}"
  report_security_status
else
  echo "Se omite la instalacion de Kyverno y Falco (--skip-security)."
fi

write_override_file() {
  local file="$1"

  {
    if [[ "$remote" == true || "$environment" == "prod" ]]; then
      echo "secrets:"
      echo "  dbPassword: $(yaml_single_quote "$db_password")"
      echo "  jwtSecret: $(yaml_single_quote "$jwt_secret")"
      echo "  adminPassword: $(yaml_single_quote "$admin_password")"
    fi

    if [[ "$remote" == true ]]; then
      echo "backend:"
      echo "  image:"
      echo "    repository: $(yaml_single_quote "$registry/playhub-backend")"
      echo "    tag: $(yaml_single_quote "$image_tag")"
      echo "    pullPolicy: IfNotPresent"
      echo "frontend:"
      echo "  image:"
      echo "    repository: $(yaml_single_quote "$registry/playhub-frontend")"
      echo "    tag: $(yaml_single_quote "$image_tag")"
      echo "    pullPolicy: IfNotPresent"
      echo "imagePullSecrets:"
      echo "  - name: $(yaml_single_quote "$registry_secret_name")"
    fi

    if [[ -n "$public_host" ]]; then
      if [[ "$tls_enabled" == true ]]; then
        echo "ingress:"
        echo "  enabled: true"
        echo "  className: $(yaml_single_quote "$ingress_class")"
        echo "  host: $(yaml_single_quote "$public_host")"
        echo "  annotations:"
        echo "    cert-manager.io/cluster-issuer: $(yaml_single_quote "$tls_issuer")"
        echo "  tls:"
        echo "    enabled: true"
        echo "    secretName: $(yaml_single_quote "$tls_secret_name")"
      else
        echo "ingress:"
        echo "  enabled: true"
        echo "  className: $(yaml_single_quote "$ingress_class")"
        echo "  host: $(yaml_single_quote "$public_host")"
      fi
      echo "config:"
      echo "  corsAllowedOrigins: $(yaml_single_quote "${public_url:-http://$public_host}")"
      echo "  cookieSecure: $(yaml_single_quote "$([[ "$public_scheme" == "https" ]] && echo true || echo false)")"
    fi

    echo "monitoring:"
    echo "  enabled: $monitoring"
    echo "  mode: $monitoring_mode"
  } > "$file"
}

mkdir -p "$project_root/.tmp"
override_file="$(umask 077 && mktemp "$project_root/.tmp/helm-overrides.XXXXXXXX")"
write_override_file "$override_file"

echo "Validando el chart (helm lint)..."
lint_args=(-f "$values_file")
if [[ -n "$profile_file" ]]; then lint_args+=(-f "$profile_file"); fi
if [[ -f "$override_file" ]]; then
  lint_args+=(-f "$override_file")
fi
helm lint "$chart_path" "${lint_args[@]}"

if [[ "$remote" == true ]]; then
  echo "Preparando namespace e imagePullSecret..."
  ensure_namespace
  check_helm_release_state
  echo 'Cuotas actuales del namespace:'
  kubectl_request get resourcequota -n "$namespace" || true
  kubectl_request -n "$namespace" create secret docker-registry "$registry_secret_name" \
    --docker-server="$docker_server" \
    --docker-username="$REG_USER" \
    --docker-password="$REG_PASS" \
    --dry-run=client -o yaml | kubectl_request apply -f - >/dev/null
  check_cluster_connection
fi

echo "Instalando / actualizando el release con Helm (entorno $environment)..."
helm_args=(
  upgrade --install "$release_name" "$chart_path"
  -f "$values_file"
  -n "$namespace"
  --wait --timeout "$wait_timeout"
)
if [[ -n "$profile_file" ]]; then helm_args+=(-f "$profile_file"); fi
if [[ "$remote" != true || "$namespace_created" == true ]]; then
  helm_args+=(--create-namespace)
fi
if [[ "$remote" == true ]]; then
  helm_args+=(--atomic)
fi
if [[ -f "$override_file" ]]; then
  helm_args+=(-f "$override_file")
fi

if ! helm "${helm_args[@]}"; then
  report_deploy_failure
  exit 1
fi

echo
echo "Pods, servicios y volumenes del release:"
kubectl_request get pods,svc,pvc -n "$namespace" || true

echo
echo "Ejecutando helm test..."
if ! helm test "$release_name" -n "$namespace" --timeout "$wait_timeout"; then
  report_deploy_failure
  exit 1
fi

base_name="$(resource_base_name)"
echo

if [[ "$remote" == true ]]; then
  echo "URL publica: $public_url"
  kubectl_request -n "$namespace" get ingress || true
  if [[ "$monitoring" == true ]]; then
    echo "Grafana: kubectl -n $namespace port-forward svc/$base_name-grafana 3000:3000"
    echo "Prometheus: kubectl -n $namespace port-forward svc/$base_name-prometheus 9090:9090"
    echo 'Grafana usa el usuario admin y ADMIN_PASSWORD del archivo de secretos.'
    if [[ "$monitoring_mode" == namespace ]]; then
      echo 'Monitoreo HTTP y de negocio habilitado. CPU/memoria de pods requieren metricas de infraestructura de la plataforma.'
    fi
  fi
fi

if [[ "$environment" == "prod" && "$remote" == false ]]; then
  echo "Acceso por Ingress: http://playhub.local"
  echo "Requiere: minikube addons enable ingress, 'minikube tunnel' corriendo y"
  echo "la linea '127.0.0.1 playhub.local' en el archivo hosts del sistema."
fi

if [[ "$verify_public" == true ]]; then
  echo "Verificando frontend y backend en $public_url ..."
  verified=false
  for _ in {1..18}; do
    frontend_status="$(curl --silent --show-error --connect-timeout 10 --max-time 15 -o /dev/null -w '%{http_code}' "$public_url/login" || true)"
    # /api/games requiere autenticacion: 401 es la respuesta esperada del backend.
    # Un frontend saludable por si solo no valida el Ingress ni el Service de la API.
    backend_status="$(curl --silent --show-error --connect-timeout 10 --max-time 15 -o /dev/null -w '%{http_code}' "$public_url/api/games" || true)"
    if [[ "$frontend_status" == 200 && "$backend_status" == 401 ]]; then
      verified=true
      break
    fi
    echo "Estado publico: frontend=$frontend_status (esperado 200), API=$backend_status (esperado 401)." >&2
    sleep 10
  done
  if [[ "$verified" != true ]]; then
    echo "No se pudo verificar frontend/API. Revisar pods, cuotas, Service, Ingress, DNS y TLS." >&2
    report_deploy_failure
    kubectl_request -n "$namespace" get ingress,certificate >&2 2>/dev/null || true
    exit 1
  fi
  echo "Frontend y API publicos verificados: $public_url"
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
  if [[ "$remote" == false ]]; then
    echo "Aviso: se omitio el inicio automatico de port-forward (--no-port-forward)." >&2
    echo "Manual: kubectl port-forward -n $namespace svc/$base_name-backend 8080:8080"
    echo "        kubectl port-forward -n $namespace svc/$base_name-frontend 5745:5745"
    if [[ "$monitoring" == true ]]; then
      echo "        kubectl port-forward -n $namespace svc/$base_name-prometheus 9090:9090"
      echo "        kubectl port-forward -n $namespace svc/$base_name-grafana 3000:3000"
    fi
  fi
fi

