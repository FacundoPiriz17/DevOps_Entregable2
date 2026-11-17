#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
workspace="${WORKSPACE:-$PWD}"
mkdir -p reports/ci
args=(--rm -u "$(id -u):$(id -g)" -e HOME=/tmp -w "$workspace")
if [[ -n "${HOSTNAME:-}" ]] && docker container inspect "$HOSTNAME" >/dev/null 2>&1; then
  args+=(--volumes-from "$HOSTNAME")
else
  args+=(--mount "type=bind,source=$workspace,target=$workspace")
fi
rm -f reports/ci/semgrep.json reports/semgrep-report.txt
status=0
docker run "${args[@]}" semgrep/semgrep:1.182.1 semgrep scan \
  --oss-only --jobs=2 --timeout=15 --config security/semgrep/rules \
  --exclude node_modules --exclude .next --exclude target --exclude .tmp \
  --exclude reports --exclude docs/generated --exclude security/semgrep/rules \
  --severity ERROR --error --metrics=off --disable-version-check \
  --text --text-output reports/semgrep-report.txt --json-output reports/ci/semgrep.json . || status=$?
if [[ -f reports/ci/semgrep.json ]]; then
  python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path('reports/ci/semgrep.json').read_text())
report = Path('reports/semgrep-report.txt')
text = report.read_text() if report.exists() else ''
report.write_text(f"Semgrep {data.get('version', '')} - severidad ERROR\n"
                  f"Archivos: {len(data.get('paths', {}).get('scanned', []))}\n"
                  f"Hallazgos: {len(data.get('results', []))}\n"
                  f"Errores: {len(data.get('errors', []))}\n\n" + text)
PY
fi
exit "$status"
