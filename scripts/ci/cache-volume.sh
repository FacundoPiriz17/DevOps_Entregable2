#!/usr/bin/env bash
# Volumenes de cache del proyecto: sobreviven a cleanWs y se escriben con el UID del agente.
prepare_cache_volume() {
  local name="$1" image="$2"
  docker volume create --label playhub.ci.cache=true "$name" >/dev/null
  if [[ "$(docker volume inspect --format '{{ index .Labels "playhub.ci.cache" }}' "$name")" != true ]]; then
    echo "El volumen $name ya existe y no es una cache de este proyecto." >&2
    return 1
  fi
  docker run --rm --user 0:0 --entrypoint sh \
    --mount "type=volume,source=$name,target=/cache" "$image" \
    -c 'chown -R "$1:$2" /cache' sh "$(id -u)" "$(id -g)"
}
