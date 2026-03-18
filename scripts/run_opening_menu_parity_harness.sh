#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMPARE_PATH="${1:-}"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)
TEST_LOG="$(mktemp -t hgss-opening-parity.XXXXXX)"

cleanup() {
  rm -f "$TEST_LOG"
}

clean_stale_swiftpm_artifacts() {
  "${SWIFT[@]}" package clean
  find .build -type d -name Modules-tool -prune -exec rm -rf {} +
}

run_filtered_test() {
  local filter="$1"
  : > "$TEST_LOG"
  if ! "${SWIFT[@]}" test --filter "$filter" 2>&1 | tee "$TEST_LOG"; then
    if grep -q "compiled module was created by a different version of the compiler" "$TEST_LOG"; then
      echo "Detected stale SwiftPM macro artifacts while running $filter."
      echo "Retrying after cleaning stale SwiftPM artifacts..."
      clean_stale_swiftpm_artifacts
      "${SWIFT[@]}" test --filter "$filter"
      return
    fi
    return 1
  fi
}

trap cleanup EXIT

echo "Refreshing extracted opening content..."
"$ROOT_DIR/scripts/run_extractor_stub.sh"

echo "Running parser-backed IR snapshot checks..."
run_filtered_test OpeningIRSnapshotTests

echo "Running source-backed runtime trace checks..."
run_filtered_test OpeningProgramTraceTests

echo "Running native playback controller checks..."
run_filtered_test HGSSOpeningProgramRenderTests

if [[ -n "$COMPARE_PATH" ]]; then
  echo "Diffing extracted audio/reference artifacts against: $COMPARE_PATH"
  python3 "$ROOT_DIR/scripts/opening_reference_diff.py" \
    --expected "$COMPARE_PATH" \
    --actual "$ROOT_DIR/Content/Local/Boot/HeartGold"
else
  echo "No comparison root provided; skipping opening_reference diff."
fi

echo "Opening/menu parity harness passed."
