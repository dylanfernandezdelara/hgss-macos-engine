#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)

INPUT_PATH="$ROOT_DIR/DevContent/Stub"
OUTPUT_PATH="$ROOT_DIR/Content/Local/Boot/HeartGold"
DEFAULT_PRET_ROOT="$ROOT_DIR/External/pokeheartgold"

if [[ -z "${POKEHEARTGOLD_ROOT:-}" && -d "$DEFAULT_PRET_ROOT" ]]; then
  export POKEHEARTGOLD_ROOT="$DEFAULT_PRET_ROOT"
fi

if [[ -z "${POKEHEARTGOLD_ROOT:-}" ]]; then
  echo "opening-heartgold requires a local pret/pokeheartgold clone." >&2
  echo "Set POKEHEARTGOLD_ROOT or place a clone at $DEFAULT_PRET_ROOT" >&2
  exit 1
fi

echo "Running HeartGold opening extractor against local pret/pokeheartgold clone..."
"$ROOT_DIR/scripts/ensure_python_tools.sh"
"${SWIFT[@]}" run HGSSExtractCLI \
  --mode opening-heartgold \
  --input "$INPUT_PATH" \
  --output "$OUTPUT_PATH" \
  --pret-root "$POKEHEARTGOLD_ROOT"
