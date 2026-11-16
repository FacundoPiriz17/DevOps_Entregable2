#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
source "$script_dir/lib/security-stack.sh"
"$(playhub_security_python)" "$script_dir/lib/security-stack.py" --project-root "$project_root" install-kyverno "$@"
