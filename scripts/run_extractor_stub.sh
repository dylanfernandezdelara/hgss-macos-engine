#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT=(xcrun swift)

INPUT_PATH="$ROOT_DIR/DevContent/Stub"
OUTPUT_PATH="$ROOT_DIR/Content/Local/StubExtract"

echo "Running extractor stub..."
"${SWIFT[@]}" run HGSSExtractCLI --input "$INPUT_PATH" --output "$OUTPUT_PATH"
