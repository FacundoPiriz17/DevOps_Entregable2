#!/usr/bin/env bash
set -euo pipefail

component="${1:?Indicar backend o frontend}"
workspace="${WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$(dirname "${BASH_SOURCE[0]}")/cache-volume.sh"
args=(--rm -u "$(id -u):$(id -g)" -e HOME=/tmp -w "$workspace/$component")

# Un agente en contenedor comparte los volumenes con sus contenedores de build.
# Un agente instalado directamente en Linux comparte el workspace por bind mount.
if [[ -n "${HOSTNAME:-}" ]] && docker container inspect "$HOSTNAME" >/dev/null 2>&1; then
  args+=(--volumes-from "$HOSTNAME")
else
  args+=(--mount "type=bind,source=$workspace,target=$workspace")
fi

case "$component" in
  backend)
    prepare_cache_volume playhub-maven-cache maven:3.9-eclipse-temurin-26@sha256:b2c1ad85954592f9928e84327c65201f308ad9b5d8ed7d5b823717c97bf23fbb
    socket=/var/run/docker.sock
    if [[ ! -S "$socket" ]]; then
      echo 'El agente necesita /var/run/docker.sock para los tests de Testcontainers.' >&2
      exit 1
    fi
    args+=(-v "$socket:$socket" --group-add "$(stat -c '%g' "$socket")"
      --add-host=host.docker.internal:host-gateway
      -e TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal -e MAVEN_CONFIG=/tmp/.m2
      --mount type=volume,source=playhub-maven-cache,target=/tmp/.m2)
    docker run "${args[@]}" maven:3.9-eclipse-temurin-26@sha256:b2c1ad85954592f9928e84327c65201f308ad9b5d8ed7d5b823717c97bf23fbb \
      mvn -B -Dmaven.repo.local=/tmp/.m2/repository clean verify
    ;;
  frontend)
    prepare_cache_volume playhub-ci-npm-cache node:22-alpine@sha256:0e1754758c2df4cfa3e68d59e2e1b7374bb7fd9ea6328eaaacf15cc934af8202
    args+=(--mount type=volume,source=playhub-ci-npm-cache,target=/tmp/.npm)
    args+=(-e "NEXT_PUBLIC_API_URL=${PUBLIC_URL:?Falta PUBLIC_URL}")
    docker run "${args[@]}" node:22-alpine@sha256:0e1754758c2df4cfa3e68d59e2e1b7374bb7fd9ea6328eaaacf15cc934af8202 \
      sh -c 'npm ci && npm run lint && npm run build'
    ;;
  *) echo 'El componente debe ser backend o frontend.' >&2; exit 2 ;;
esac
