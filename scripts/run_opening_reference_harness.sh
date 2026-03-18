#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMPARE_PATH="${1:-}"

"$ROOT_DIR/scripts/run_extractor_stub.sh"

REFERENCE_PATH="$ROOT_DIR/Content/Local/Boot/HeartGold/opening_reference.json"

echo "Opening reference harness ready:"
echo "  $REFERENCE_PATH"
echo "Audio trace files:"
find "$ROOT_DIR/Content/Local/Boot/HeartGold/intermediate/audio" -type f | sort

if [[ -n "$COMPARE_PATH" ]]; then
  echo "Comparing current opening reference against: $COMPARE_PATH"
  python3 "$ROOT_DIR/scripts/opening_reference_diff.py" \
    --expected "$COMPARE_PATH" \
    --actual "$ROOT_DIR/Content/Local/Boot/HeartGold"
fi
