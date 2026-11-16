#!/usr/bin/env bash

playhub_security_python() {
  local candidate
  if [[ -n "${PYTHON:-}" ]]; then
    if "$PYTHON" -c 'import sys; sys.exit(sys.version_info.major != 3)' >/dev/null 2>&1; then
      printf '%s' "$PYTHON"
      return
    fi
    echo 'PYTHON debe apuntar a un interprete Python 3 funcional.' >&2
    return 1
  fi
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info.major != 3)' >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return
    fi
  done
  echo 'No se encontro un interprete Python 3 funcional.' >&2
  return 1
}

initialize_playhub_security() {
  local project_root="$1"
  shift
  "$(playhub_security_python)" "$project_root/scripts/lib/security-stack.py" --project-root "$project_root" install "$@"
}

remove_playhub_security() {
  local project_root="$1"
  shift
  "$(playhub_security_python)" "$project_root/scripts/lib/security-stack.py" --project-root "$project_root" remove "$@"
}
