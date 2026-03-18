#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="$ROOT_DIR/Content/Local/Tooling/ndspy-venv/bin/python"

if [[ ! -x "$VENV_PYTHON" ]]; then
  echo "Missing python tool venv at $VENV_PYTHON" >&2
  echo "Run ./scripts/ensure_python_tools.sh first." >&2
  exit 1
fi

"$VENV_PYTHON" "$@"
