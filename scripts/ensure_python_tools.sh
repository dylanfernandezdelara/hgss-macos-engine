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
  "$WHEELHOUSE_DIR/nitrogfx_py-0.2.0-py3-none-any.whl" \
  "$WHEELHOUSE_DIR/pillow-10.4.0-cp39-cp39-macosx_11_0_arm64.whl"
do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing offline Python package artifact: $required_file" >&2
    exit 1
  fi
done

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
  "$VENV_DIR/bin/pip" install --quiet --no-index --find-links "$WHEELHOUSE_DIR" ndspy==4.2.0 Pillow==10.4.0
  # nitrogfx-py still pins Pillow 7.x upstream; this repo uses a pinned newer Pillow wheel that
  # is known to work with the helper's limited API surface on Apple Silicon.
  "$VENV_DIR/bin/pip" install --quiet --no-index --find-links "$WHEELHOUSE_DIR" --no-deps nitrogfx-py==0.2.0
fi

echo "Python extractor tools ready at $VENV_DIR"
