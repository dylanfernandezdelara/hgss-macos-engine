#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)

echo "Launching HGSSMac app shell..."
HGSS_REPO_ROOT="$ROOT_DIR" "${SWIFT[@]}" run --package-path Apps/HGSSMac HGSSMac
