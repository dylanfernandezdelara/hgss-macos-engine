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

echo "Running Swift tests..."
"${SWIFT[@]}" test "${SWIFT_PACKAGE_FLAGS[@]}"
