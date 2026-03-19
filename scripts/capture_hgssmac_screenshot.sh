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
KEEP_RUNNING=0
FULL_DISPLAY=0
CAPTURE_DELAY="2.0"
WAIT_TIMEOUT="20.0"
OUTPUT_PATH=""
WINDOW_OWNER="HGSSMac"
WINDOW_TITLE="HGSSMac"
QUERY_SOURCE="$ROOT_DIR/scripts/hgss_window_query.swift"
QUERY_BINARY="$ROOT_DIR/Content/Local/Tooling/hgss-window-query"
APP_LOG=""
APP_PID=""

usage() {
  cat <<EOF
Usage: ./scripts/capture_hgssmac_screenshot.sh [options]

Options:
  --refresh-content       Force a fresh extractor run before launch.
  --skip-extract          Reuse existing extracted content.
  --delay SECONDS         Wait this long after the window appears before capture. Default: ${CAPTURE_DELAY}
  --timeout SECONDS       Maximum time to wait for the window. Default: ${WAIT_TIMEOUT}
  --output PATH           Write the screenshot to PATH.
  --full-display          Capture the main display instead of the HGSSMac window.
  --keep-running          Leave the app running after the screenshot is saved.
  --help                  Show this help text.
EOF
}

cleanup() {
  local status=$?
  if [[ -n "$APP_PID" && "$KEEP_RUNNING" -eq 0 ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  if [[ -n "$APP_LOG" && -f "$APP_LOG" ]]; then
    rm -f "$APP_LOG"
  fi
  exit "$status"
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
    --delay)
      CAPTURE_DELAY="${2:-}"
      if [[ -z "$CAPTURE_DELAY" ]]; then
        echo "--delay requires a seconds value." >&2
        exit 1
      fi
      shift
      ;;
    --timeout)
      WAIT_TIMEOUT="${2:-}"
      if [[ -z "$WAIT_TIMEOUT" ]]; then
        echo "--timeout requires a seconds value." >&2
        exit 1
      fi
      shift
      ;;
    --output)
      OUTPUT_PATH="${2:-}"
      if [[ -z "$OUTPUT_PATH" ]]; then
        echo "--output requires a path." >&2
        exit 1
      fi
      shift
      ;;
    --keep-running)
      KEEP_RUNNING=1
      ;;
    --full-display)
      FULL_DISPLAY=1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
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

if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_DIR="$ROOT_DIR/Content/Local/Debug/Screenshots"
  mkdir -p "$OUTPUT_DIR"
  OUTPUT_PATH="$OUTPUT_DIR/hgssmac-$(date +%Y%m%d-%H%M%S).png"
else
  mkdir -p "$(dirname "$OUTPUT_PATH")"
fi

mkdir -p "$(dirname "$QUERY_BINARY")"

if [[ ! -x "$QUERY_BINARY" || "$QUERY_SOURCE" -nt "$QUERY_BINARY" ]]; then
  echo "Compiling HGSS window query helper..."
  swiftc "$QUERY_SOURCE" -o "$QUERY_BINARY"
fi

APP_LOG="$(mktemp -t hgssmac-capture-log.XXXXXX)"

echo "Launching HGSSMac for screenshot capture..."
HGSS_REPO_ROOT="$ROOT_DIR" \
HGSS_CONTENT_ROOT="$ROOT_DIR/Content/Local/Boot/HeartGold" \
"${SWIFT[@]}" run --scratch-path "$APP_SCRATCH" --package-path Apps/HGSSMac HGSSMac >"$APP_LOG" 2>&1 &
APP_PID=$!

find_window_id() {
  "$QUERY_BINARY" --owner "$WINDOW_OWNER" --title "$WINDOW_TITLE"
}

deadline_epoch="$(python3 - "$WAIT_TIMEOUT" <<'PY'
import sys, time
print(time.time() + float(sys.argv[1]))
PY
)"

window_id=""
while :; do
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "HGSSMac exited before a screenshot could be taken." >&2
    cat "$APP_LOG" >&2
    exit 1
  fi

  if [[ "$FULL_DISPLAY" -eq 0 ]]; then
    if window_id="$(find_window_id 2>/dev/null)"; then
      break
    fi
  else
    break
  fi

  now_epoch="$(python3 - <<'PY'
import time
print(time.time())
PY
)"
  if ! python3 - "$now_epoch" "$deadline_epoch" <<'PY'
import sys
sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)
PY
  then
    echo "Timed out waiting for the HGSSMac window." >&2
    cat "$APP_LOG" >&2
    exit 1
  fi

  sleep 0.25
done

sleep "$CAPTURE_DELAY"

if [[ "$FULL_DISPLAY" -eq 1 ]]; then
  screencapture -x -m "$OUTPUT_PATH"
else
  screencapture -x -o -l "$window_id" "$OUTPUT_PATH"
fi

echo "Saved screenshot to: $OUTPUT_PATH"
if [[ "$KEEP_RUNNING" -eq 1 && -n "$APP_LOG" ]]; then
  echo "App log: $APP_LOG"
fi

if [[ "$KEEP_RUNNING" -eq 1 ]]; then
  echo "HGSSMac is still running with PID $APP_PID."
  trap - EXIT
fi
