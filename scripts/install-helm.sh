set -euo pipefail

version="v4.3.1"
install_dir="${HOME}/.local/bin"
force=false

usage() {
  printf '%s\n' \
    "Uso: scripts/install-helm.sh [opciones]" \
    "" \
    "Descarga e instala Helm si no esta instalado." \
    "" \
    "Opciones:" \
    "  --version vX.Y.Z      Version de Helm (default: $version)." \
    "  --install-dir RUTA    Carpeta de destino (default: \$HOME/.local/bin)." \
    "  --force               Instala aunque ya haya un helm en el PATH." \
    "  -h, --help            Muestra esta ayuda." \
    "" \
    "Ejemplos:" \
    "  scripts/install-helm.sh" \
    "  sudo scripts/install-helm.sh --install-dir /usr/local/bin"
}

while (($# > 0)); do
  case "$1" in
    --version)
      if (($# < 2)) || [[ -z "$2" ]]; then
        echo "Falta el valor de --version." >&2
        exit 2
      fi
      version="$2"
      shift 2
      ;;
    --install-dir)
      if (($# < 2)) || [[ -z "$2" ]]; then
        echo "Falta el valor de --install-dir." >&2
        exit 2
      fi
      install_dir="$2"
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opcion desconocida: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "--version debe tener el formato vX.Y.Z (por ejemplo v4.3.1)." >&2
  exit 2
fi

if command -v helm >/dev/null 2>&1 && [[ "$force" == false ]]; then
  echo "Helm ya esta instalado en: $(command -v helm)"
  helm version
  echo
  echo "No se hizo nada. Usa --force para instalar la version $version igualmente."
  exit 0
fi

case "$(uname -s)" in
  Linux) os="linux" ;;
  Darwin) os="darwin" ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "Este script es para Linux y macOS. En Windows usa: .\\scripts\\install-helm.ps1" >&2
    exit 1
    ;;
  *)
    echo "Sistema operativo no soportado: $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch="amd64" ;;
  aarch64|arm64) arch="arm64" ;;
  armv7l|armv6l) arch="arm" ;;
  i386|i686) arch="386" ;;
  *)
    echo "Arquitectura no soportada: $(uname -m)" >&2
    exit 1
    ;;
esac

download() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$output" "$url"
  else
    echo "Hace falta curl o wget para descargar Helm." >&2
    exit 1
  fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "Hace falta sha256sum o shasum para verificar la descarga." >&2
    exit 1
  fi
}

base_url="https://get.helm.sh"
archive="helm-$version-$os-$arch.tar.gz"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "Descargando $base_url/$archive ..."
download "$base_url/$archive" "$tmp_dir/$archive"
download "$base_url/$archive.sha256sum" "$tmp_dir/$archive.sha256sum"

echo "Verificando SHA256..."
expected="$(awk '{print $1}' "$tmp_dir/$archive.sha256sum")"
actual="$(sha256_of "$tmp_dir/$archive")"
if [[ "$expected" != "$actual" ]]; then
  echo "El SHA256 no coincide. Esperado: $expected, obtenido: $actual. No se instalo nada." >&2
  exit 1
fi
echo "SHA256 correcto."

tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
if [[ ! -f "$tmp_dir/$os-$arch/helm" ]]; then
  echo "No se encontro el binario helm dentro de $archive." >&2
  exit 1
fi

if ! mkdir -p "$install_dir" 2>/dev/null || [[ ! -w "$install_dir" ]]; then
  echo "No hay permisos de escritura en $install_dir." >&2
  echo "Ejecuta con sudo o elegi otra carpeta con --install-dir." >&2
  exit 1
fi

install -m 0755 "$tmp_dir/$os-$arch/helm" "$install_dir/helm"
echo "Helm copiado a: $install_dir/helm"
echo

"$install_dir/helm" version
echo

case ":$PATH:" in
  *":$install_dir:"*) ;;
  *)
    echo "Aviso: $install_dir no esta en tu PATH. Agregalo, por ejemplo:"
    echo "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    ;;
esac

