#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$ROOT_DIR/Content/Local/Tooling/ndspy-venv"
WHEELHOUSE_DIR="$ROOT_DIR/ThirdParty/python-wheels"
PYVENV_CFG="$VENV_DIR/pyvenv.cfg"

REQUIRED_PACKAGES=(
  "ndspy==4.2.0"
  "nitrogfx-py==0.2.0"
  "Pillow==10.4.0"
)

mkdir -p "$ROOT_DIR/Content/Local/Tooling"

if [[ -f "$PYVENV_CFG" ]] && grep -q "^include-system-site-packages = true$" "$PYVENV_CFG"; then
  rm -rf "$VENV_DIR"
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  python3 -m venv "$VENV_DIR"
fi

if [[ ! -d "$WHEELHOUSE_DIR" ]]; then
  echo "Missing offline Python wheelhouse at $WHEELHOUSE_DIR" >&2
  exit 1
fi

for required_file in \
  "$WHEELHOUSE_DIR/ndspy-4.2.0-py3-none-any.whl" \
  "$WHEELHOUSE_DIR/nitrogfx_py-0.2.0-py3-none-any.whl"
do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing offline Python package artifact: $required_file" >&2
    exit 1
  fi
done

if ! compgen -G "$WHEELHOUSE_DIR/pillow-10.4.0-*.whl" > /dev/null; then
  if [[ ! -f "$WHEELHOUSE_DIR/pillow-10.4.0.tar.gz" ]]; then
    echo "Missing offline Python package artifact matching: $WHEELHOUSE_DIR/pillow-10.4.0-*.whl or $WHEELHOUSE_DIR/pillow-10.4.0.tar.gz" >&2
    exit 1
  fi
fi

for required_file in \
  "$WHEELHOUSE_DIR/packaging-25.0-py3-none-any.whl" \
  "$WHEELHOUSE_DIR/setuptools-82.0.1-py3-none-any.whl" \
  "$WHEELHOUSE_DIR/wheel-0.46.3-py3-none-any.whl"
do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing offline Python build tool artifact: $required_file" >&2
    exit 1
  fi
done

install_python_packages() {
  "$VENV_DIR/bin/pip" install --quiet --no-index --find-links "$WHEELHOUSE_DIR" ndspy==4.2.0
  "$VENV_DIR/bin/pip" install --quiet --no-index --find-links "$WHEELHOUSE_DIR" Pillow==10.4.0 && return 0

  if [[ ! -f "$WHEELHOUSE_DIR/pillow-10.4.0.tar.gz" ]]; then
    echo "No compatible offline Pillow wheel found and Pillow source fallback is missing." >&2
    return 1
  fi

  "$VENV_DIR/bin/pip" install --quiet --no-index --find-links "$WHEELHOUSE_DIR" packaging==25.0 setuptools==82.0.1 wheel==0.46.3
  "$VENV_DIR/bin/pip" install --quiet --no-index --no-build-isolation "$WHEELHOUSE_DIR/pillow-10.4.0.tar.gz"
  return 0
}

if ! "$VENV_DIR/bin/python" - <<'PY'
from importlib import metadata
import sys

expected = {
    "ndspy": "4.2.0",
    "nitrogfx-py": "0.2.0",
    "Pillow": "10.4.0",
}

for package_name, version in expected.items():
    try:
        installed = metadata.version(package_name)
    except metadata.PackageNotFoundError:
        sys.exit(1)
    if installed != version:
        sys.exit(1)
PY
then
  install_python_packages
  # nitrogfx-py still pins Pillow 7.x upstream; this repo uses a pinned newer Pillow build that
  # is known to work with the helper's limited API surface.
  "$VENV_DIR/bin/pip" install --quiet --no-index --find-links "$WHEELHOUSE_DIR" --no-deps nitrogfx-py==0.2.0
fi

echo "Python extractor tools ready at $VENV_DIR"
