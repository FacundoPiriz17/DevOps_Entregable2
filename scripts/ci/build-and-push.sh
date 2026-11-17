#!/usr/bin/env bash
set -euo pipefail

registry="${REGISTRY:?Falta REGISTRY (ej: docker.io/usuario)}"
image_tag="${IMAGE_TAG:?Falta IMAGE_TAG (ej: 42-a1b2c3d)}"
public_url="${PUBLIC_URL:?Falta PUBLIC_URL (origen publico para NEXT_PUBLIC_API_URL)}"
reg_user="${REG_USER:?Falta REG_USER}"
reg_pass="${REG_PASS:?Falta REG_PASS}"

backend_image="${IMAGE_BE:-$registry/playhub-backend}"
frontend_image="${IMAGE_FE:-$registry/playhub-frontend}"
registry_host="${registry%%/*}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "No se encontro 'docker' en PATH." >&2
  exit 1
fi

if [[ "$public_url" == *localhost* || "$public_url" == *127.0.0.1* ]]; then
  echo "Aviso: PUBLIC_URL apunta a localhost; el bundle del frontend no funcionara fuera de esta maquina." >&2
fi

logged_in=false
cleanup_login() {
  if [[ "$logged_in" == true ]]; then
    docker logout "$registry_host" >/dev/null 2>&1 || true
  fi
}
trap cleanup_login EXIT

echo "Login en $registry_host como $reg_user..."
printf '%s' "$reg_pass" | docker login "$registry_host" --username "$reg_user" --password-stdin
logged_in=true

echo "Construyendo $backend_image:$image_tag..."
docker build \
  --file "$repo_root/backend/Dockerfile.prod" \
  --tag "$backend_image:$image_tag" \
  "$repo_root/backend"

echo "Construyendo $frontend_image:$image_tag (NEXT_PUBLIC_API_URL=$public_url)..."
docker build \
  --build-arg "NEXT_PUBLIC_API_URL=$public_url" \
  --file "$repo_root/frontend/Dockerfile.prod" \
  --tag "$frontend_image:$image_tag" \
  "$repo_root/frontend"

echo "Publicando imagenes..."
docker push "$backend_image:$image_tag"
docker push "$frontend_image:$image_tag"

echo "Imagenes publicadas:"
echo "  $backend_image:$image_tag"
echo "  $frontend_image:$image_tag"
