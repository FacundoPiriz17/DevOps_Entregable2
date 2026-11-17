#!/usr/bin/env bash
set -euo pipefail
workspace="${WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
args=(--rm --entrypoint /usr/bin/env -u "$(id -u):$(id -g)" -e HOME=/tmp
  -e "WORKSPACE=$workspace" -e "PUBLIC_URL=${PUBLIC_URL:-http://localhost:8080}"
  -e "IMAGE_TAG=${IMAGE_TAG:-}" -w "$workspace"
  -v /var/run/docker.sock:/var/run/docker.sock --group-add "$(stat -c '%g' /var/run/docker.sock)")
if [[ -n "${HOSTNAME:-}" ]] && docker container inspect "$HOSTNAME" >/dev/null 2>&1; then
  args+=(--volumes-from "$HOSTNAME")
else
  args+=(--mount "type=bind,source=$workspace,target=$workspace")
fi
docker run "${args[@]}" playhub-jenkins:local "$@"
