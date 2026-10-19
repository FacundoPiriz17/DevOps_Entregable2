#!/usr/bin/env bash
#
# Genera trafico real contra PlayHub para alimentar los dashboards de Grafana.
#
# Este script prueba la demo de monitoreo de extremo a extremo:
#
#   1. Opcionalmente despliega la aplicacion invocando deploy.sh (--deploy).
#   2. Espera a que backend, frontend y Prometheus respondan.
#   3. Genera trafico contra la API REST con curl (Python 3 para leer JSON):
#      logins fallidos, registro e ingreso de usuarios sinteticos, catalogo,
#      carrito, compras, wishlist, errores 4xx y una ráfaga de carga concurrente
#      que mueve CPU/RAM/red de los workloads y del nodo.
#   4. Desactiva los usuarios sinteticos con un administrador (--keep-users evita
#      la limpieza).
#   5. Consulta Prometheus para verificar que las metricas aumentaron e imprime
#      un resumen con los enlaces a los dashboards de Grafana.
#
# Sale con codigo 0 solo si las metricas clave aumentaron (tambien funciona
# como smoke test de la demo de monitoreo).
#
# Uso:
#   ./scripts/demo-monitoring.sh
#   ./scripts/demo-monitoring.sh --deploy --deploy-green
#   ./scripts/demo-monitoring.sh --synthetic-users 8 --burst-seconds 60

set -uo pipefail

deploy=false
deploy_green=false
cluster_type="minikube"
api_url="http://localhost:8080"
frontend_url="http://localhost:5745"
prometheus_url="http://localhost:9090"
synthetic_users=5
burst_seconds=30
burst_concurrency=8
timeout_sec=180
keep_users=false
skip_frontend=false

usage() {
  printf '%s\n' \
    "Uso: scripts/demo-monitoring.sh [opciones]" \
    "" \
    "Opciones:" \
    "  --deploy                    Ejecuta scripts/deploy.sh antes de generar trafico." \
    "  --deploy-green              Pasa --deploy-green a deploy.sh (requiere --deploy)." \
    "  --cluster-type TIPO         Tipo de cluster para deploy.sh (default: minikube)." \
    "  --api-url URL               Backend (default: http://localhost:8080)." \
    "  --frontend-url URL          Frontend (default: http://localhost:5745)." \
    "  --prometheus-url URL        Prometheus (default: http://localhost:9090)." \
    "  --synthetic-users N         Usuarios sinteticos a registrar (default: 5)." \
    "  --burst-seconds N           Duracion de la ráfaga de carga (default: 30)." \
    "  --burst-concurrency N       Workers concurrentes de la ráfaga (default: 8)." \
    "  --timeout N                 Espera maxima de disponibilidad en segundos (default: 180)." \
    "  --keep-users                No desactiva los usuarios sinteticos al finalizar." \
    "  --skip-frontend             No genera trafico contra el frontend." \
    "  -h, --help                  Muestra esta ayuda."
}

while (($# > 0)); do
  case "$1" in
    --deploy) deploy=true; shift ;;
    --deploy-green) deploy_green=true; shift ;;
    --cluster-type)
      if (($# < 2)); then echo "Falta el valor de --cluster-type." >&2; exit 2; fi
      cluster_type="$2"; shift 2 ;;
    --api-url)
      if (($# < 2)); then echo "Falta el valor de --api-url." >&2; exit 2; fi
      api_url="${2%/}"; shift 2 ;;
    --frontend-url)
      if (($# < 2)); then echo "Falta el valor de --frontend-url." >&2; exit 2; fi
      frontend_url="${2%/}"; shift 2 ;;
    --prometheus-url)
      if (($# < 2)); then echo "Falta el valor de --prometheus-url." >&2; exit 2; fi
      prometheus_url="${2%/}"; shift 2 ;;
    --synthetic-users)
      if (($# < 2)); then echo "Falta el valor de --synthetic-users." >&2; exit 2; fi
      synthetic_users="$2"; shift 2 ;;
    --burst-seconds)
      if (($# < 2)); then echo "Falta el valor de --burst-seconds." >&2; exit 2; fi
      burst_seconds="$2"; shift 2 ;;
    --burst-concurrency)
      if (($# < 2)); then echo "Falta el valor de --burst-concurrency." >&2; exit 2; fi
      burst_concurrency="$2"; shift 2 ;;
    --timeout)
      if (($# < 2)); then echo "Falta el valor de --timeout." >&2; exit 2; fi
      timeout_sec="$2"; shift 2 ;;
    --keep-users) keep_users=true; shift ;;
    --skip-frontend) skip_frontend=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opcion desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ----------------------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
  echo "No se encontro 'curl' en PATH. Se requiere para generar el trafico." >&2
  exit 2
fi

python_cmd=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info.major != 3)' >/dev/null 2>&1; then
    python_cmd="$candidate"
    break
  fi
done
if [[ -z "$python_cmd" ]]; then
  echo "Se requiere Python 3 para leer las respuestas JSON de la API y Prometheus." >&2
  exit 2
fi
for setting in synthetic_users burst_seconds burst_concurrency timeout_sec; do
  value="${!setting}"
  if [[ ! "$value" =~ ^[1-9][0-9]{0,4}$ ]]; then
    echo "Valor invalido para $setting: $value (debe ser un entero positivo)." >&2
    exit 2
  fi
done
if ((synthetic_users > 1000 || burst_seconds > 86400 || burst_concurrency > 128 || timeout_sec > 86400)); then
  echo "Parametros fuera de rango (usuarios <= 1000, concurrencia <= 128, segundos <= 86400)." >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
logs_dir="$project_root/logs"
mkdir -p "$logs_dir"
work_dir="$(mktemp -d "$logs_dir/demo-monitoring.XXXXXXXX")"

# Parse JSON inside this script: nested category/image IDs must not be treated
# as game IDs, and a Prometheus API error must not be interpreted as zero.
json_extract() {
  "$python_cmd" -c '
import json, math, sys
try:
    payload = json.load(sys.stdin)
    if sys.argv[1] == "games":
        if not isinstance(payload, list):
            raise ValueError("El catalogo no es una lista")
        ids = dict.fromkeys(game["id"] for game in payload if game.get("available") is True)
        print("\n".join(str(game_id) for game_id in list(ids)[:12]))
    else:
        if payload.get("status") != "success" or payload["data"]["resultType"] != "vector":
            raise ValueError("Consulta de Prometheus invalida")
        result = payload["data"]["result"]
        value = float(result[0]["value"][1]) if result else 0.0
        if not math.isfinite(value):
            raise ValueError("Valor de Prometheus no finito")
        print(value)
except (ValueError, KeyError, TypeError, IndexError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
' "$1" | tr -d '\r'
}

admin_email="facundo@playhub.test"
admin_password="PlayHub123"
general_email="agostina@playhub.test"
general_password="PlayHub123"
run_id="$(date +%Y%m%d%H%M%S)-${work_dir##*.}"
failed_login_attempts=15
error_request_rounds=3
fail_count=0

if [[ -t 1 ]]; then
  c_step=$'\033[36m'; c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_off=$'\033[0m'
else
  c_step=""; c_ok=""; c_warn=""; c_err=""; c_off=""
fi

step() { printf '\n%s==> %s%s\n' "$c_step" "$1" "$c_off"; }
ok() { printf '%s  OK  %s%s\n' "$c_ok" "$1" "$c_off"; }
info() { printf '  ..  %s\n' "$1"; }
warn() { printf '%s  AVISO  %s%s\n' "$c_warn" "$1" "$c_off"; }
err() { printf '%s  ERROR  %s%s\n' "$c_err" "$1" "$c_off"; }

# ----------------------------------------------------------------------------
# HTTP basico con curl. La respuesta queda en http_status / http_body.
# Uso: http_request METODO URL [BODY] [COOKIE_JAR]
# ----------------------------------------------------------------------------
http_status=0
http_body=""

http_request() {
  local method="$1" url="$2" body="${3:-}" jar="${4:-}"
  local tmp
  tmp="$(mktemp)"
  local -a args=(-s -S -o "$tmp" -w "%{http_code}" -X "$method" --max-time 30)
  if [[ -n "$jar" ]]; then args+=(-b "$jar" -c "$jar"); fi
  if [[ -n "$body" ]]; then args+=(-H "Content-Type: application/json" -d "$body"); fi
  args+=("$url")
  http_status="$(curl "${args[@]}" 2>/dev/null | tail -n 1)"
  http_body="$(cat "$tmp" 2>/dev/null || true)"
  rm -f "$tmp"
  [[ "$http_status" =~ ^[0-9]+$ ]] || http_status=0
}

wait_http_ok() {
  local url="$1" label="$2" seconds="${3:-$timeout_sec}"
  local deadline=$(( $(date +%s) + seconds ))
  while (($(date +%s) < deadline)); do
    http_status="$(curl -s -L -o /dev/null -w '%{http_code}' --max-time 30 "$url" 2>/dev/null)" || http_status=0
    if [[ "$http_status" -eq 200 ]]; then return 0; fi
    sleep 2
  done
  warn "Tiempo agotado esperando $label ($url)."
  return 1
}

# Valor instantaneo de una query de Prometheus (0 si no hay series).
prom_value() {
  local tmp
  tmp="$(mktemp)"
  local code
  code="$(curl -s -G -o "$tmp" -w "%{http_code}" --max-time 30 \
    --data-urlencode "query=$1" "$prometheus_url/api/v1/query" 2>/dev/null | tail -n 1)"
  local body
  body="$(cat "$tmp" 2>/dev/null || true)"
  rm -f "$tmp"
  if [[ "$code" != "200" ]]; then echo ""; return; fi
  printf '%s' "$body" | json_extract prom
}

# login EMAIL PASSWORD JAR -> 0 si inicio sesion
do_login() {
  local email="$1" password="$2" jar="$3"
  local body
  body="$(printf '{"email":"%s","password":"%s"}' "$email" "$password")"
  http_request POST "$api_url/api/auth/login" "$body" "$jar"
  [[ "$http_status" -eq 200 ]]
}

register_synthetic() {
  local index="$1"
  local email="demo-load-$run_id-$index@playhub.test"
  local jar="$work_dir/jar-synth-$index.txt"
  local body
  body="$(printf '{"name":"Demo Load %s","email":"%s","country":"UY","password":"PlayHubDemo123"}' "$index" "$email")"
  http_request POST "$api_url/api/auth/register" "$body"
  if [[ "$http_status" -eq 201 ]]; then
    registered_email="$email"
    if do_login "$email" "PlayHubDemo123" "$jar"; then
      registered_jar="$jar"
      return 0
    fi
  fi
  return 1
}

# ----------------------------------------------------------------------------
# Fase 1: despliegue opcional y espera
# ----------------------------------------------------------------------------
if $deploy; then
  step "Desplegando la aplicacion con deploy.sh (--cluster-type $cluster_type$(if $deploy_green; then printf ' --deploy-green'; fi))"
  deploy_args=(--cluster-type "$cluster_type")
  if $deploy_green; then deploy_args+=(--deploy-green); fi
  if ! "$script_dir/deploy.sh" "${deploy_args[@]}"; then
    err "deploy.sh termino con error."
    exit 2
  fi
fi

step "Esperando a que la aplicacion y el monitoreo respondan"
if wait_http_ok "$api_url/actuator/health" "backend"; then
  ok "Backend disponible en $api_url"
else
  err "El backend no responde en $api_url. Ejecuta el deploy o revisa los port-forward."
  exit 2
fi

if ! $skip_frontend; then
  min_timeout=60
  if ((timeout_sec < min_timeout)); then min_timeout=$timeout_sec; fi
  if wait_http_ok "$frontend_url" "frontend" "$min_timeout"; then
    ok "Frontend disponible en $frontend_url"
  else
    warn "El frontend no responde en $frontend_url; la ráfaga salteara el trafico al frontend."
    skip_frontend=true
  fi
fi

if ! wait_http_ok "$prometheus_url/-/ready" "prometheus" 60; then
  err "Prometheus no responde en $prometheus_url."
  exit 2
fi
ok "Prometheus disponible en $prometheus_url"

target_up="$(prom_value 'max(up{job="playhub-backend"})')"
if [[ -z "$target_up" ]]; then
  warn "No se pudo consultar el target playhub-backend en Prometheus."
elif awk -v up="$target_up" 'BEGIN { exit !(up < 1) }'; then
  warn "El target playhub-backend esta DOWN en Prometheus (http://localhost:9090/targets)."
else
  ok "Target playhub-backend UP en Prometheus"
fi

# ----------------------------------------------------------------------------
# Fase 2: metricas antes de generar trafico
# ----------------------------------------------------------------------------
step "Leyendo metricas base en Prometheus"
before_failed="$(prom_value "sum(failed_logins_total)")"
before_purchases="$(prom_value "sum(total_purchases_total)")"
before_earnings="$(prom_value "sum(total_earnings_currency_units_total)")"
before_requests="$(prom_value 'sum(http_server_requests_seconds_count{uri!~"/actuator.*"})')"
if [[ -z "$before_failed" || -z "$before_purchases" || -z "$before_earnings" || -z "$before_requests" ]]; then
  err "No se pudieron consultar las metricas base en Prometheus."
  exit 2
fi
info "failed_logins=$before_failed purchases=$before_purchases earnings=$before_earnings http_requests=$before_requests"

step "Generando $failed_login_attempts logins fallidos"
failed_responses=0
for ((i = 0; i < failed_login_attempts; i++)); do
  http_request POST "$api_url/api/auth/login" "{\"email\":\"$admin_email\",\"password\":\"IncorrectDemoPassword\"}"
  if [[ "$http_status" -eq 401 ]]; then failed_responses=$((failed_responses + 1)); fi
done
if ((failed_responses == failed_login_attempts)); then
  ok "$failed_responses respuestas 401 de login"
else
  err "Solo $failed_responses de $failed_login_attempts logins devolvieron 401."
  fail_count=$((fail_count + 1))
fi

# ----------------------------------------------------------------------------
# Fase 3: sesiones
# ----------------------------------------------------------------------------
step "Abriendo sesiones de usuario"
admin_jar="$work_dir/jar-admin.txt"
if do_login "$admin_email" "$admin_password" "$admin_jar"; then
  ok "Sesion admin ($admin_email)"
else
  err "No se pudo iniciar sesion como $admin_email."
  exit 2
fi

general_jar="$work_dir/jar-general.txt"
if do_login "$general_email" "$general_password" "$general_jar"; then
  ok "Sesion usuario general ($general_email)"
else
  warn "No se pudo iniciar sesion como $general_email."
  general_jar=""
fi

synth_emails=()
synth_jars=()
for ((i = 1; i <= synthetic_users; i++)); do
  registered_email=""
  registered_jar=""
  if register_synthetic "$i"; then
    ok "Usuario sintetico $registered_email"
  else
    err "No se pudo registrar/iniciar sesion del usuario sintetico #$i."
    fail_count=$((fail_count + 1))
  fi
  if [[ -n "$registered_email" ]]; then
    synth_emails+=("$registered_email")
    synth_jars+=("$registered_jar")
  fi
done

# ----------------------------------------------------------------------------
# Fase 4: catalogo (lecturas GET para latencia y throughput)
# ----------------------------------------------------------------------------
step "Generando trafico de catalogo"
http_request GET "$api_url/api/games" "" "$admin_jar"
game_ids="$(printf '%s' "$http_body" | json_extract games)"
if [[ -z "$game_ids" ]]; then
  err "El catalogo no contiene juegos disponibles para comprar."
  fail_count=$((fail_count + 1))
else
  ok "Juegos comprables detectados: $(printf '%s\n' $game_ids | wc -l | tr -d ' ')"
fi

pick_random_game() {
  printf '%s\n' $game_ids | shuf -n 1
}

all_jars=("$admin_jar")
[[ -n "$general_jar" ]] && all_jars+=("$general_jar")
for j in "${synth_jars[@]:-}"; do [[ -n "$j" ]] && all_jars+=("$j"); done

browse_count=0
for jar in "${all_jars[@]}"; do
  [[ -n "$jar" ]] || continue
  for _ in 1 2 3; do
    http_request GET "$api_url/api/games" "" "$jar"
    browse_count=$((browse_count + 1))
  done
  for _ in 1 2 3 4; do
    gid="$(pick_random_game)"
    http_request GET "$api_url/api/games/$gid" "" "$jar"
    browse_count=$((browse_count + 1))
  done
done
ok "$browse_count lecturas de catalogo"

# ----------------------------------------------------------------------------
# Fase 5: carrito y compras (alimenta total_purchases / total_earnings)
# ----------------------------------------------------------------------------
step "Generando carritos y compras"
cart_emails=()
cart_jars=()
[[ -n "$general_jar" ]] && { cart_emails+=("$general_email"); cart_jars+=("$general_jar"); }
if ((${#synth_emails[@]} > 0)); then
  for i in "${!synth_emails[@]}"; do
    cart_emails+=("${synth_emails[$i]}")
    cart_jars+=("${synth_jars[$i]}")
  done
fi

purchases=0
if ((${#cart_jars[@]} > 0)); then
  for i in "${!cart_jars[@]}"; do
    jar="${cart_jars[$i]}"
    [[ -n "$jar" ]] || continue
    mapfile -t pick < <(printf '%s\n' $game_ids | shuf -n 3)
    added=()
    for gid in "${pick[@]}"; do
      http_request POST "$api_url/api/cart/games/$gid" "" "$jar"
      if [[ "$http_status" -eq 201 ]]; then added+=("$gid"); fi
    done
    http_request GET "$api_url/api/cart" "" "$jar"
    if ((${#added[@]} > 0)); then
      http_request DELETE "$api_url/api/cart/games/${added[0]}" "" "$jar"
      http_request POST "$api_url/api/cart/games/${added[0]}" "" "$jar"
    fi
    http_request POST "$api_url/api/cart/checkout" "" "$jar"
    if [[ "$http_status" -eq 200 ]]; then purchases=$((purchases + 1)); fi
    http_request GET "$api_url/api/library" "" "$jar"
  done
fi
ok "Compras procesadas: $purchases de ${#cart_jars[@]} usuarios"
if ((purchases < 1)); then
  err "Esta corrida no pudo completar ninguna compra."
  fail_count=$((fail_count + 1))
fi

# ----------------------------------------------------------------------------
# Fase 6: wishlist y biblioteca
# ----------------------------------------------------------------------------
step "Generando trafico de wishlist y biblioteca"
wish_ops=0
for jar in "${synth_jars[@]:-}"; do
  [[ -n "$jar" ]] || continue
  mapfile -t pick < <(printf '%s\n' $game_ids | shuf -n 2)
  for gid in "${pick[@]}"; do
    http_request POST "$api_url/api/wishlist/games/$gid" "" "$jar"
    if [[ "$http_status" -eq 201 ]]; then wish_ops=$((wish_ops + 1)); fi
  done
  http_request GET "$api_url/api/wishlist" "" "$jar"
  if ((${#pick[@]} > 0)); then
    http_request DELETE "$api_url/api/wishlist/games/${pick[0]}" "" "$jar"
  fi
done
for jar in "$admin_jar" "$general_jar"; do
  [[ -n "$jar" ]] || continue
  http_request GET "$api_url/api/library" "" "$jar"
  http_request GET "$api_url/api/users/me" "" "$jar"
done
ok "Operaciones de wishlist: $wish_ops"

# ----------------------------------------------------------------------------
# Fase 7: errores 4xx (404, 400 y 403)
# ----------------------------------------------------------------------------
step "Generando errores 4xx (404/400/403)"
error_jar="$general_jar"
[[ -n "${synth_jars[0]:-}" ]] && error_jar="${synth_jars[0]}"
error_ops=0
for _ in $(seq 1 "$error_request_rounds"); do
  http_request GET "$api_url/api/games/999999" "" "$error_jar"
  http_request POST "$api_url/api/cart/checkout" "" "$error_jar"
  http_request GET "$api_url/api/games/999999" "" "$admin_jar"
  http_request GET "$api_url/api/admin/users" "" "$error_jar"
  http_request GET "$api_url/api/admin/users" "" "$general_jar"
  error_ops=$((error_ops + 5))
done
ok "$error_ops peticiones que producen respuestas 4xx"

# ----------------------------------------------------------------------------
# Fase 8: ráfaga de carga concurrente
# ----------------------------------------------------------------------------
step "Ráfaga de carga: $burst_concurrency workers durante $burst_seconds segundos"
burst_start="$(date +%s)"
burst_pids=()
for ((w = 0; w < burst_concurrency; w++)); do
  (
    count=0
    deadline=$(( $(date +%s) + burst_seconds ))
    while (($(date +%s) < deadline)); do
      if curl -s -o /dev/null -b "$admin_jar" --max-time 10 "$api_url/api/games"; then count=$((count + 1)); fi
      if curl -s -o /dev/null -b "$admin_jar" --max-time 10 "$api_url/api/cart"; then count=$((count + 1)); fi
      if ! $skip_frontend; then
        if curl -s -L -o /dev/null --max-time 10 "$frontend_url/"; then count=$((count + 1)); fi
      fi
    done
    printf '%s\n' "$count" > "$work_dir/burst-$w.count"
  ) &
  burst_pids+=($!)
done
burst_total=0
for w in "${!burst_pids[@]}"; do
  if ! wait "${burst_pids[$w]}"; then fail_count=$((fail_count + 1)); fi
  count="$(cat "$work_dir/burst-$w.count" 2>/dev/null || echo 0)"
  burst_total=$((burst_total + count))
done
burst_elapsed=$(( $(date +%s) - burst_start ))
rps=$(( burst_total / (burst_elapsed > 0 ? burst_elapsed : 1) ))
ok "Ráfaga completada: $burst_total requests en ${burst_elapsed}s (~$rps req/s)"

# ----------------------------------------------------------------------------
# Fase 9: limpieza de usuarios sinteticos
# ----------------------------------------------------------------------------
if ! $keep_users && ((${#synth_emails[@]} > 0)); then
  step "Desactivando usuarios sinteticos (usa --keep-users para conservarlos)"
  deactivated=0
  for email in "${synth_emails[@]}"; do
    encoded_email="$(printf '%s' "$email" | sed 's/@/%40/g')"
    http_request PATCH "$api_url/api/admin/users/$encoded_email/deactivate" "" "$admin_jar"
    if [[ "$http_status" -eq 200 ]]; then deactivated=$((deactivated + 1)); fi
  done
  ok "$deactivated de ${#synth_emails[@]} usuarios sinteticos desactivados"
  if ((deactivated != ${#synth_emails[@]})); then
    err "No se pudo completar la limpieza."
    fail_count=$((fail_count + 1))
  fi
elif ((${#synth_emails[@]} > 0)); then
  info "Usuarios sinteticos conservados (--keep-users): ${#synth_emails[@]}"
fi

# ----------------------------------------------------------------------------
# Fase 10: verificacion en Prometheus
# ----------------------------------------------------------------------------
step "Verificando metricas en Prometheus"
metrics_deadline=$(( $(date +%s) + timeout_sec ))
while true; do
  after_failed="$(prom_value "sum(failed_logins_total)")"
  after_purchases="$(prom_value "sum(total_purchases_total)")"
  after_earnings="$(prom_value "sum(total_earnings_currency_units_total)")"
  after_requests="$(prom_value 'sum(http_server_requests_seconds_count{uri!~"/actuator.*"})')"
  after_up="$(prom_value 'max(up{job="playhub-backend"})')"
  if [[ -n "$after_failed" && -n "$after_purchases" && -n "$after_earnings" && -n "$after_requests" ]] &&
      awk -v f="$after_failed" -v bf="$before_failed" -v p="$after_purchases" -v bp="$before_purchases" \
          -v r="$after_requests" -v br="$before_requests" -v up="${after_up:-0}" \
          'BEGIN { exit !(f-bf >= 15 && p-bp >= 1 && r-br >= 200 && up >= 1) }'; then
    break
  fi
  if (($(date +%s) >= metrics_deadline)); then break; fi
  sleep 2
done

delta() {
  local before="$1" after="$2"
  before="${before:-0}"; after="${after:-0}"
  local d
  d="$(awk -v a="$after" -v b="$before" 'BEGIN { d = a - b; if (d < 0) d = a; printf "%.1f", d }')"
  echo "$d"
}

delta_failed="$(delta "$before_failed" "$after_failed")"
delta_purchases="$(delta "$before_purchases" "$after_purchases")"
delta_earnings="$(delta "$before_earnings" "$after_earnings")"
delta_requests="$(delta "$before_requests" "$after_requests")"

printf '\n  %-36s %10s %12s %12s\n' "Metrica" "Antes" "Despues" "Delta"
printf '  %-36s %10s %12s %12s\n' "------" "-----" "-------" "-----"
printf '  %-36s %10s %12s %12s\n' "failed_logins_total" "$before_failed" "$after_failed" "$delta_failed"
printf '  %-36s %10s %12s %12s\n' "total_purchases_total" "$before_purchases" "$after_purchases" "$delta_purchases"
printf '  %-36s %10s %12s %12s\n' "total_earnings (unidades)" "$before_earnings" "$after_earnings" "$delta_earnings"
printf '  %-36s %10s %12s %12s\n' "http_server_requests (count)" "$before_requests" "$after_requests" "$delta_requests"
printf '  %-36s %10s %12s\n' "up{job=playhub-backend}" "-" "${after_up:-?}"
printf '\n'

checks_ok=true
if ((fail_count > 0)); then checks_ok=false; fi
if [[ -z "$after_failed" || -z "$after_purchases" || -z "$after_earnings" || -z "$after_requests" ]]; then
  err "No se pudieron consultar todas las metricas finales en Prometheus."
  checks_ok=false
fi
check_pass() {
  if awk -v v="$1" -v m="$2" 'BEGIN { exit !(v >= m) }'; then
    ok "$3"
  else
    err "$3"
    checks_ok=false
  fi
}
check_pass "$delta_failed" "$failed_login_attempts" "Logins fallidos registrados (>= $failed_login_attempts)"
check_pass "$delta_purchases" "1" "Compras registradas (>= 1)"
check_pass "$delta_requests" "200" "Requests HTTP generados (>= 200)"
if awk -v v="${after_up:-0}" 'BEGIN { exit !(v >= 1) }'; then
  ok "Target de Prometheus UP"
else
  err "Target de Prometheus UP"
  checks_ok=false
fi

step "Dashboards de Grafana (http://localhost:3000, carpeta PlayHub)"
printf '  http://localhost:3000/d/playhub-counters      Contadores (compras, ganancias, logins fallidos, 500)\n'
printf '  http://localhost:3000/d/playhub-http-latency  Latencia y throughput HTTP del backend\n'
printf '  http://localhost:3000/d/playhub-bluegreen     Trafico y latencia por slot Blue/Green\n'
printf '  http://localhost:3000/d/playhub-workloads     Recursos de workloads (CPU/RAM/red por pod)\n'
printf '  http://localhost:3000/d/playhub-nodes         Recursos del nodo\n'
printf '\n'
printf '  Prometheus targets: http://localhost:9090/targets\n'

if $checks_ok; then
  ok "Demo de monitoreo verificada: todas las metricas clave aumentaron."
  exit 0
else
  err "Verificacion fallida. Revisa los dashboards y los targets de Prometheus."
  exit 1
fi
