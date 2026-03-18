#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMPARE_PATH=""
REFRESH_CONTENT=0
SKIP_EXTRACT=0

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

TEST_SCRATCH="$ROOT_DIR/.build-tests"
SWIFT=(xcrun swift)
TEST_LOG="$(mktemp -t hgss-opening-parity.XXXXXX)"
PARITY_FILTER="OpeningIRSnapshotTests|OpeningProgramTraceTests|HGSSOpeningProgramRenderTests|HGSSOpeningParityHarnessTests"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh-content)
      REFRESH_CONTENT=1
      ;;
    --skip-extract)
      SKIP_EXTRACT=1
      ;;
    --compare-root)
      COMPARE_PATH="${2:-}"
      if [[ -z "$COMPARE_PATH" ]]; then
        echo "--compare-root requires a path argument." >&2
        exit 1
      fi
      shift
      ;;
    --help)
      echo "Usage: ./scripts/run_opening_menu_parity_harness.sh [--refresh-content] [--skip-extract] [--compare-root PATH]"
      exit 0
      ;;
    --*)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
    *)
      if [[ -n "$COMPARE_PATH" ]]; then
        echo "Unexpected extra positional argument: $1" >&2
        exit 1
      fi
      COMPARE_PATH="$1"
      ;;
  esac
  shift
done

cleanup() {
  rm -f "$TEST_LOG"
}

clean_stale_swiftpm_artifacts() {
  xcrun swift package --scratch-path "$TEST_SCRATCH" clean
  find "$TEST_SCRATCH" -type d -name Modules-tool -prune -exec rm -rf {} + 2>/dev/null || true
}

run_filtered_test() {
  local filter="$1"
  : > "$TEST_LOG"
  if ! "${SWIFT[@]}" test --scratch-path "$TEST_SCRATCH" --filter "$filter" 2>&1 | tee "$TEST_LOG"; then
    if grep -q "compiled module was created by a different version of the compiler" "$TEST_LOG"; then
      echo "Detected stale SwiftPM macro artifacts while running $filter."
      echo "Retrying after cleaning stale SwiftPM artifacts..."
      clean_stale_swiftpm_artifacts
      "${SWIFT[@]}" test --scratch-path "$TEST_SCRATCH" --filter "$filter"
      return
    fi
    return 1
  fi
}

trap cleanup EXIT

if [[ "$SKIP_EXTRACT" -eq 0 ]]; then
  echo "Refreshing extracted opening content..."
  if [[ "$REFRESH_CONTENT" -eq 1 ]]; then
    "$ROOT_DIR/scripts/run_extractor_stub.sh" --force
  else
    "$ROOT_DIR/scripts/run_extractor_stub.sh"
  fi
else
  echo "Skipping extractor refresh."
fi

echo "Running opening/menu parity suites..."
run_filtered_test "$PARITY_FILTER"

if [[ -n "$COMPARE_PATH" ]]; then
  echo "Diffing extracted audio/reference artifacts against: $COMPARE_PATH"
  python3 "$ROOT_DIR/scripts/opening_reference_diff.py" \
    --expected "$COMPARE_PATH" \
    --actual "$ROOT_DIR/Content/Local/Boot/HeartGold"
else
  echo "No comparison root provided; skipping opening_reference diff."
fi

echo "Opening/menu parity harness passed."
