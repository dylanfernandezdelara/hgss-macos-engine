#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)

INPUT_PATH="$ROOT_DIR/DevContent/Stub"
OUTPUT_PATH="$ROOT_DIR/Content/Local/StubExtract"
DEFAULT_PRET_ROOT="$ROOT_DIR/External/pokeheartgold"

if [[ -z "${POKEHEARTGOLD_ROOT:-}" && -d "$DEFAULT_PRET_ROOT" ]]; then
  export POKEHEARTGOLD_ROOT="$DEFAULT_PRET_ROOT"
fi

if [[ -n "${POKEHEARTGOLD_ROOT:-}" ]]; then
  echo "Running extractor against local pret/pokeheartgold clone..."
  "${SWIFT[@]}" run HGSSExtractCLI --input "$INPUT_PATH" --output "$OUTPUT_PATH" --pret-root "$POKEHEARTGOLD_ROOT"
else
  echo "Running extractor with checked-in normalized profile..."
  "${SWIFT[@]}" run HGSSExtractCLI --input "$INPUT_PATH" --output "$OUTPUT_PATH"
fi
