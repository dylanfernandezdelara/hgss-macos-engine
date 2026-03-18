#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

APP_SCRATCH="$ROOT_DIR/.build-app"
SWIFT=(xcrun swift)
REFRESH_CONTENT=0
SKIP_EXTRACT=0
FULLSCREEN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh-content)
      REFRESH_CONTENT=1
      ;;
    --skip-extract)
      SKIP_EXTRACT=1
      ;;
    --fullscreen)
      FULLSCREEN=1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: ./scripts/run_app.sh [--refresh-content] [--skip-extract] [--fullscreen]" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$SKIP_EXTRACT" -eq 0 ]]; then
  echo "Refreshing local extracted content..."
  if [[ "$REFRESH_CONTENT" -eq 1 ]]; then
    "$ROOT_DIR/scripts/run_extractor_stub.sh" --force
  else
    "$ROOT_DIR/scripts/run_extractor_stub.sh"
  fi
else
  echo "Skipping extractor refresh."
fi

echo "Launching HGSSMac opening player..."
HGSS_REPO_ROOT="$ROOT_DIR" \
HGSS_CONTENT_ROOT="$ROOT_DIR/Content/Local/Boot/HeartGold" \
HGSSMAC_FULLSCREEN="$FULLSCREEN" \
"${SWIFT[@]}" run --scratch-path "$APP_SCRATCH" --package-path Apps/HGSSMac HGSSMac
