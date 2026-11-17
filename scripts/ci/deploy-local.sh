#!/usr/bin/env bash
set -euo pipefail
image_tag="${IMAGE_TAG:?Falta IMAGE_TAG (ej: local-8-a1b2c3d)}"
if [[ ! "$image_tag" =~ ^local-[a-zA-Z0-9_.-]+$ || ${#image_tag} -gt 128 ]]; then exit 2; fi
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
for tool in docker helm kubectl; do
  command -v "$tool" >/dev/null || { echo "Falta $tool en Jenkins." >&2; exit 1; }
done

# El unico destino es el nodo Minikube local identificado por Docker.
node=minikube
namespace=playhub-local
release=playhub-local
if [[ "$(docker inspect --format '{{ index .Config.Labels "created_by.minikube.sigs.k8s.io" }}' "$node")" != true ||
      "$(docker inspect --format '{{.State.Running}}' "$node")" != true ]]; then
  echo 'Se necesita el perfil minikube iniciado con el driver Docker.' >&2; exit 1
fi
node_ip="$(docker inspect --format '{{with index .NetworkSettings.Networks "minikube"}}{{.IPAddress}}{{end}}' "$node")"
if [[ ! "$node_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'El nodo debe estar conectado a la red Docker minikube.' >&2; exit 1
fi
if [[ -n "${HOSTNAME:-}" ]] && docker container inspect "$HOSTNAME" >/dev/null 2>&1; then
  if [[ -z "$(docker inspect --format '{{with index .NetworkSettings.Networks "minikube"}}connected{{end}}' "$HOSTNAME")" ]]; then
    docker network connect minikube "$HOSTNAME"
  fi
fi
mkdir -p .tmp reports/ci
work_dir="$(umask 077 && mktemp -d "$repo_root/.tmp/local-deploy.XXXXXXXX")"
cleanup() { rm -f "$work_dir/kubeconfig"; rmdir "$work_dir"; }
trap cleanup EXIT
local_config="$work_dir/kubeconfig"
# Configuracion exclusivamente local; no se consultan credenciales de Jenkins.
docker cp "$node:/etc/kubernetes/admin.conf" "$local_config"
chmod 600 "$local_config"
cluster_name="$(kubectl --kubeconfig "$local_config" config view --minify -o jsonpath='{.clusters[0].name}')"
kubectl --kubeconfig "$local_config" config set-cluster "$cluster_name" --server="https://$node_ip:8443" >/dev/null
export KUBECONFIG="$local_config"
kube=(kubectl --request-timeout=20s)
"${kube[@]}" get --raw /version >/dev/null
runtime="$("${kube[@]}" get node minikube -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}')"
if [[ "$runtime" != docker://* ]]; then
  echo "Se requiere --container-runtime=docker (actual: $runtime)." >&2; exit 1
fi
docker image inspect "playhub-backend:$image_tag" "playhub-frontend:$image_tag" >/dev/null
echo 'Importando las imagenes de esta corrida en el Minikube local...'
docker save "playhub-backend:$image_tag" "playhub-frontend:$image_tag" | docker exec -i "$node" docker image load

diagnostics() {
  {
    "${kube[@]}" -n "$namespace" get deployments,daemonsets,pods,svc,pvc -o wide || true
    "${kube[@]}" -n "$namespace" get events --sort-by=.lastTimestamp || true
    helm status "$release" -n "$namespace" || true
  } > reports/ci/local-deploy-diagnostics.txt 2>&1
}
trap 'status=$?; if (( status != 0 )); then diagnostics; fi; cleanup; exit "$status"' EXIT

"${kube[@]}" create namespace "$namespace" --dry-run=client -o yaml | "${kube[@]}" apply -f -

echo 'Desplegando playhub-local con monitoreo completo...'
helm upgrade --install "$release" helm-chart --namespace "$namespace" \
  -f helm-chart/values-dev.yaml -f helm-chart/values-lab.yaml -f helm-chart/values-local.yaml \
  --set-string "backend.image.tag=$image_tag" --set-string "frontend.image.tag=$image_tag" \
  --wait --timeout 10m --history-max 5
helm test "$release" -n "$namespace" --timeout 5m

"${kube[@]}" -n "$namespace" get deployments,daemonsets,pods,svc,pvc > reports/ci/local-deployment.txt
cat > reports/ci/local-access.txt <<'ACCESS'
# Ejecutar desde PowerShell en el host, en terminales separadas:
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-frontend 5745:5745
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-backend 8080:8080
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-grafana 3000:3000
kubectl --context minikube -n playhub-local port-forward svc/playhub-local-prometheus 9090:9090
# Frontend http://localhost:5745 | API http://localhost:8080
# Grafana http://localhost:3000 (admin / PlayHub123) | Prometheus http://localhost:9090
ACCESS
cat reports/ci/local-access.txt
