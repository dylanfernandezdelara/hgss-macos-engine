#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)

echo "Running Swift tests..."
if ! "${SWIFT[@]}" test; then
  echo "Retrying after cleaning stale SwiftPM artifacts..."
  "${SWIFT[@]}" package clean
  "${SWIFT[@]}" test
fi
