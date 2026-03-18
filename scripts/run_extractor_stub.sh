#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

EXTRACTOR_SCRATCH="$ROOT_DIR/.build-extractor"
SWIFT=(xcrun swift)

INPUT_PATH="$ROOT_DIR/DevContent/Stub"
OUTPUT_PATH="$ROOT_DIR/Content/Local/Boot/HeartGold"
DEFAULT_PRET_ROOT="$ROOT_DIR/External/pokeheartgold"
FINGERPRINT_SCRIPT="$ROOT_DIR/scripts/opening_content_fingerprint.py"
FINGERPRINT_PATH="$OUTPUT_PATH/.opening_content_fingerprint"
FORCE_REFRESH=0

format_duration() {
  local total_seconds="$1"
  printf "%02dm%02ds" $((total_seconds / 60)) $((total_seconds % 60))
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|--refresh-content)
      FORCE_REFRESH=1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: ./scripts/run_extractor_stub.sh [--force|--refresh-content]" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${POKEHEARTGOLD_ROOT:-}" && -d "$DEFAULT_PRET_ROOT" ]]; then
  export POKEHEARTGOLD_ROOT="$DEFAULT_PRET_ROOT"
fi

if [[ -z "${POKEHEARTGOLD_ROOT:-}" ]]; then
  echo "opening-heartgold requires a local pret/pokeheartgold clone." >&2
  echo "Set POKEHEARTGOLD_ROOT or place a clone at $DEFAULT_PRET_ROOT" >&2
  exit 1
fi

required_outputs=(
  "$OUTPUT_PATH/opening_bundle.json"
  "$OUTPUT_PATH/opening_program_ir.json"
  "$OUTPUT_PATH/opening_extract_report.json"
)

content_fingerprint="$(python3 "$FINGERPRINT_SCRIPT" --repo-root "$ROOT_DIR" --pret-root "$POKEHEARTGOLD_ROOT")"

content_is_fresh() {
  [[ -f "$FINGERPRINT_PATH" ]] || return 1
  [[ "$(cat "$FINGERPRINT_PATH")" == "$content_fingerprint" ]] || return 1

  for path in "${required_outputs[@]}"; do
    [[ -f "$path" ]] || return 1
  done

  return 0
}

if [[ "$FORCE_REFRESH" -eq 0 ]] && content_is_fresh; then
  echo "Opening content is current; skipping extractor refresh."
  echo "Fingerprint: ${content_fingerprint:0:12}"
  exit 0
fi

overall_start="$(date +%s)"
echo "Running HeartGold opening extractor against local pret/pokeheartgold clone..."
if [[ "$FORCE_REFRESH" -eq 1 ]]; then
  echo "Content refresh forced by caller."
else
  echo "Content fingerprint changed or extracted outputs are missing."
fi

phase_start="$(date +%s)"
"$ROOT_DIR/scripts/ensure_python_tools.sh"
echo "Python tooling ready in $(format_duration "$(( $(date +%s) - phase_start ))")."

phase_start="$(date +%s)"
"${SWIFT[@]}" run --scratch-path "$EXTRACTOR_SCRATCH" HGSSExtractCLI \
  --mode opening-heartgold \
  --input "$INPUT_PATH" \
  --output "$OUTPUT_PATH" \
  --pret-root "$POKEHEARTGOLD_ROOT"

printf '%s\n' "$content_fingerprint" > "$FINGERPRINT_PATH"
echo "Extractor refresh completed in $(format_duration "$(( $(date +%s) - phase_start ))")."
echo "Total extractor workflow time: $(format_duration "$(( $(date +%s) - overall_start ))")."
echo "Fingerprint: ${content_fingerprint:0:12}"
