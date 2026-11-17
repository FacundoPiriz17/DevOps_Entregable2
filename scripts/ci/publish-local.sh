#!/usr/bin/env bash
set -euo pipefail
image_tag="${IMAGE_TAG:?Falta IMAGE_TAG}"
if [[ ! "$image_tag" =~ ^local-[a-zA-Z0-9_.-]+$ || ${#image_tag} -gt 128 ]]; then exit 2; fi
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
registry=playhub-local-registry
if ! docker container inspect "$registry" >/dev/null 2>&1; then
  docker volume create --label playhub.local.registry=true playhub-local-registry-data >/dev/null
  if [[ "$(docker volume inspect --format '{{ index .Labels "playhub.local.registry" }}' playhub-local-registry-data)" != true ]]; then
    echo 'El volumen del registry ya existe y no pertenece a esta pipeline.' >&2; exit 1
  fi
  docker run --rm --user 0:0 --entrypoint sh -v playhub-local-registry-data:/var/lib/registry \
    registry:2.8.3 -c 'chown 1000:1000 /var/lib/registry'
  docker run -d --name "$registry" --restart unless-stopped \
    --label playhub.local.registry=true -p 127.0.0.1:5001:5000 \
    --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges \
    -v playhub-local-registry-data:/var/lib/registry registry:2.8.3 >/dev/null
fi
if [[ "$(docker inspect --format '{{ index .Config.Labels "playhub.local.registry" }}' "$registry")" != true ||
      "$(docker inspect --format '{{range (index .HostConfig.PortBindings "5000/tcp")}}{{.HostIp}}:{{.HostPort}}{{end}}' "$registry")" != 127.0.0.1:5001 ]]; then
  echo 'El registry local existente no coincide con la configuracion de PlayHub.' >&2; exit 1
fi
docker start "$registry" >/dev/null
mkdir -p reports/ci
: > reports/ci/published-images.txt
for component in backend frontend; do
  image="localhost:5001/playhub-$component:$image_tag"
  docker tag "playhub-$component:$image_tag" "$image"
  docker push "$image"
  printf '%s\n' "$image" >> reports/ci/published-images.txt
done
