#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

export HOME="$ROOT_DIR/.build/swiftpm-home"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"

SWIFTPM_CACHE_PATH="$ROOT_DIR/.build/swiftpm/cache"
SWIFTPM_CONFIG_PATH="$ROOT_DIR/.build/swiftpm/config"
SWIFTPM_SECURITY_PATH="$ROOT_DIR/.build/swiftpm/security"

mkdir -p \
  "$HOME" \
  "$CLANG_MODULE_CACHE_PATH" \
  "$SWIFTPM_CACHE_PATH" \
  "$SWIFTPM_CONFIG_PATH" \
  "$SWIFTPM_SECURITY_PATH"

SWIFT=(xcrun swift)
SWIFT_PACKAGE_FLAGS=(
  --disable-sandbox
  --manifest-cache local
  --cache-path "$SWIFTPM_CACHE_PATH"
  --config-path "$SWIFTPM_CONFIG_PATH"
  --security-path "$SWIFTPM_SECURITY_PATH"
)

INPUT_PATH="$ROOT_DIR/DevContent/Stub"
OUTPUT_PATH="$ROOT_DIR/Content/Local/StubExtract"

if [[ -n "${POKEHEARTGOLD_ROOT:-}" ]]; then
  echo "Running extractor against local pret/pokeheartgold clone..."
  "${SWIFT[@]}" run "${SWIFT_PACKAGE_FLAGS[@]}" HGSSExtractCLI --input "$INPUT_PATH" --output "$OUTPUT_PATH" --pret-root "$POKEHEARTGOLD_ROOT"
else
  echo "Running extractor with checked-in normalized profile..."
  "${SWIFT[@]}" run "${SWIFT_PACKAGE_FLAGS[@]}" HGSSExtractCLI --input "$INPUT_PATH" --output "$OUTPUT_PATH"
fi
