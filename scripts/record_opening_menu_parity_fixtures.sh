#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

TEST_SCRATCH="$ROOT_DIR/.build-tests"
SWIFT=(xcrun swift)
TEST_LOG="$(mktemp -t hgss-opening-record.XXXXXX)"
REFRESH_CONTENT=0
SKIP_EXTRACT=0

cleanup() {
  rm -f "$TEST_LOG"
}

clean_stale_swiftpm_artifacts() {
  xcrun swift package --scratch-path "$TEST_SCRATCH" clean
  find "$TEST_SCRATCH" -type d -name Modules-tool -prune -exec rm -rf {} + 2>/dev/null || true
}

run_filtered_test() {
  local filter="$1"
  shift
  : > "$TEST_LOG"
  if ! env "$@" "${SWIFT[@]}" test --scratch-path "$TEST_SCRATCH" --filter "$filter" 2>&1 | tee "$TEST_LOG"; then
    if grep -q "compiled module was created by a different version of the compiler" "$TEST_LOG"; then
      echo "Detected stale SwiftPM macro artifacts while recording $filter."
      echo "Retrying after cleaning stale SwiftPM artifacts..."
      clean_stale_swiftpm_artifacts
      env "$@" "${SWIFT[@]}" test --scratch-path "$TEST_SCRATCH" --filter "$filter"
      return
    fi
    return 1
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh-content)
      REFRESH_CONTENT=1
      ;;
    --skip-extract)
      SKIP_EXTRACT=1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: ./scripts/record_opening_menu_parity_fixtures.sh [--refresh-content] [--skip-extract]" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$SKIP_EXTRACT" -eq 0 ]]; then
  echo "Preparing extracted opening content..."
  if [[ "$REFRESH_CONTENT" -eq 1 ]]; then
    "$ROOT_DIR/scripts/run_extractor_stub.sh" --force
  else
    "$ROOT_DIR/scripts/run_extractor_stub.sh"
  fi
else
  echo "Skipping extractor refresh."
fi

echo "Recording parser-backed opening IR fixtures..."
run_filtered_test OpeningIRSnapshotTests HGSS_RECORD_OPENING_IR_SNAPSHOT=1

echo "Recording visual and audio parity fixtures..."
run_filtered_test HGSSOpeningParityHarnessTests HGSS_RECORD_OPENING_PARITY=1

echo "Opening/menu parity fixtures recorded."
