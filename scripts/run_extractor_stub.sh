#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)
SWIFT_FLAGS=()

if [[ "${SWIFT_PACKAGE_DISABLE_SANDBOX:-0}" == "1" ]]; then
  SWIFT_FLAGS+=(--disable-sandbox)
fi

INPUT_PATH="$ROOT_DIR/DevContent/Stub"
OUTPUT_PATH="$ROOT_DIR/Content/Local/StubExtract"

if [[ -n "${POKEHEARTGOLD_ROOT:-}" ]]; then
  echo "Running extractor against local pret/pokeheartgold clone..."
  "${SWIFT[@]}" run "${SWIFT_FLAGS[@]}" HGSSExtractCLI --input "$INPUT_PATH" --output "$OUTPUT_PATH" --pret-root "$POKEHEARTGOLD_ROOT"
else
  echo "Running extractor with checked-in normalized profile..."
  "${SWIFT[@]}" run "${SWIFT_FLAGS[@]}" HGSSExtractCLI --input "$INPUT_PATH" --output "$OUTPUT_PATH"
fi
