#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)
SWIFT_ARGS=(test)

if [[ "${SWIFT_PACKAGE_DISABLE_SANDBOX:-0}" == "1" ]]; then
  SWIFT_ARGS+=(--disable-sandbox)
fi

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  MACOS_PLATFORM_DIR="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer"
  if [[ -d "$MACOS_PLATFORM_DIR" ]]; then
    SWIFT_ARGS+=(
      --enable-xctest
      -Xswiftc -I
      -Xswiftc "$MACOS_PLATFORM_DIR/usr/lib"
      -Xswiftc -F
      -Xswiftc "$MACOS_PLATFORM_DIR/Library/Frameworks"
      -Xlinker -F
      -Xlinker "$MACOS_PLATFORM_DIR/Library/Frameworks"
    )
  else
    SWIFT_ARGS+=(--enable-xctest)
  fi
else
  SWIFT_ARGS+=(--enable-xctest)
fi

echo "Running Swift tests..."
"${SWIFT[@]}" "${SWIFT_ARGS[@]}"
