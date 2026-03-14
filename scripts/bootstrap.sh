#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
mkdir -p Content/Local

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)

echo "Resolving root package dependencies..."
"${SWIFT[@]}" package resolve

echo "Resolving app package dependencies..."
"${SWIFT[@]}" package resolve --package-path Apps/HGSSMac

echo "Bootstrap complete."
