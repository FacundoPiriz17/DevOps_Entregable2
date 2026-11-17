"""Comprueba el estado de Helm y la retencion del PVC sin imprimir secretos."""

from datetime import datetime, timezone
import json
import re
import sys


if len(sys.argv) == 3 and sys.argv[1] == "--retained-pvc":
    # Helm decide que conserva a partir del manifiesto guardado, no de la
    # anotacion actual del objeto. Solo se aceptan los campos del PVC esperado.
    expected = re.escape(sys.argv[2])
    for document in re.split(r"(?m)^---\s*$", sys.stdin.read()):
        if not re.search(r"(?m)^kind: PersistentVolumeClaim\s*$", document):
            continue
        metadata = re.search(r"(?ms)^metadata:\s*\n(.*?)(?=^\S|\Z)", document)
        if metadata and re.search(rf'''(?m)^  name: ["']?{expected}["']?\s*$''', metadata[1]):
            annotations = re.search(r"(?ms)^  annotations:\s*\n(.*?)(?=^  \S|\Z)", metadata[1])
            if annotations and re.search(r'''(?m)^    helm\.sh/resource-policy: ["']?keep["']?\s*$''', annotations[1]):
                print("Retencion del PVC confirmada en el manifiesto de Helm.")
                sys.exit(0)
    print("El manifiesto guardado de Helm no confirma la retencion del PVC; no se recupera el release.", file=sys.stderr)
    sys.exit(1)

history = json.load(sys.stdin)
latest = max(history, key=lambda revision: int(revision["revision"]))
status = latest["status"]
if status == "pending-install" and len(history) == 1 and int(latest["revision"]) == 1:
    updated = datetime.fromisoformat(latest["updated"].replace("Z", "+00:00"))
    if updated.tzinfo is None:
        raise ValueError("El historial de Helm no incluye la zona horaria")
    age = (datetime.now(timezone.utc) - updated).total_seconds()
    print("stale-install" if age >= 3600 else "pending")
elif status.startswith("pending-") or status == "uninstalling":
    print("pending")
else:
    print("ready")
