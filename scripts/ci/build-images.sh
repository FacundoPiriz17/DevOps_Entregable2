#!/usr/bin/env bash
set -euo pipefail
image_tag="${IMAGE_TAG:?Falta IMAGE_TAG (ej: local-8-a1b2c3d)}"
if [[ ! "$image_tag" =~ ^local-[a-zA-Z0-9_.-]+$ || ${#image_tag} -gt 128 ]]; then
  echo 'IMAGE_TAG debe ser un tag local-* valido de hasta 128 caracteres.' >&2
  exit 2
fi
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
mkdir -p reports/ci
docker build --file backend/Dockerfile.prod --tag "playhub-backend:$image_tag" backend
docker build --file frontend/Dockerfile.prod --tag "playhub-frontend:$image_tag" \
  --build-arg NEXT_PUBLIC_API_URL=http://localhost:8080 frontend
printf 'playhub-backend:%s\nplayhub-frontend:%s\n' "$image_tag" "$image_tag" > reports/ci/local-images.txt
