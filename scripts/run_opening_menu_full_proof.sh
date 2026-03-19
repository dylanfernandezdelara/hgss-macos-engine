#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COMPARE_ARGS=()
LAUNCH_APP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --compare-root)
      COMPARE_ARGS=(--compare-root "${2:-}")
      if [[ -z "${COMPARE_ARGS[1]}" ]]; then
        echo "--compare-root requires a path argument." >&2
        exit 1
      fi
      shift
      ;;
    --launch-app)
      LAUNCH_APP=1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: ./scripts/run_opening_menu_full_proof.sh [--compare-root PATH] [--launch-app]" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ${#COMPARE_ARGS[@]} -gt 0 ]]; then
  "$ROOT_DIR/scripts/run_opening_menu_parity_harness.sh" --refresh-content "${COMPARE_ARGS[@]}"
else
  "$ROOT_DIR/scripts/run_opening_menu_parity_harness.sh" --refresh-content
fi
"$ROOT_DIR/scripts/check_repo.sh"
"$ROOT_DIR/scripts/test.sh"
"$ROOT_DIR/scripts/run_extractor_stub.sh"

if [[ "$LAUNCH_APP" -eq 1 ]]; then
  "$ROOT_DIR/scripts/run_app.sh" --skip-extract
else
  echo "Full proof checks passed."
  echo "Run ./scripts/run_app.sh --skip-extract for the manual app launch check."
fi
