#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

TEST_SCRATCH="$ROOT_DIR/.build-tests"
SWIFT=(xcrun swift)
TEST_LOG="$(mktemp -t hgss-swift-test.XXXXXX)"

cleanup() {
  rm -f "$TEST_LOG"
}

clean_stale_swiftpm_artifacts() {
  xcrun swift package --scratch-path "$TEST_SCRATCH" clean
  find "$TEST_SCRATCH" -type d -name Modules-tool -prune -exec rm -rf {} + 2>/dev/null || true
}

trap cleanup EXIT

echo "Running Swift tests..."
if ! "${SWIFT[@]}" test --scratch-path "$TEST_SCRATCH" 2>&1 | tee "$TEST_LOG"; then
  if grep -q "compiled module was created by a different version of the compiler" "$TEST_LOG"; then
    echo "Detected stale SwiftPM macro artifacts from a different compiler build."
  fi
  echo "Retrying after cleaning stale SwiftPM artifacts..."
  clean_stale_swiftpm_artifacts
  "${SWIFT[@]}" test --scratch-path "$TEST_SCRATCH"
fi
