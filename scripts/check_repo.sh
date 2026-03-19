#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

TEST_SCRATCH="$ROOT_DIR/.build-tests"
APP_SCRATCH="$ROOT_DIR/.build-app"
EXTRACTOR_SCRATCH="$ROOT_DIR/.build-extractor"
SWIFT_SHARED=(xcrun swift)
SWIFT_APP=(xcrun swift)
SWIFT_EXTRACTOR=(xcrun swift)

echo "Checking required files..."
required=(
  "README.md"
  "WORKFLOW.md"
  "AGENTS.md"
  "docs/ARCHITECTURE.md"
  "docs/CONTENT_SCHEMA.md"
  "docs/FIRST_PLAYABLE_SLICE.md"
  "docs/HEARTGOLD_OPENING_PARITY.md"
  "docs/LEGAL_AND_ASSET_HYGIENE.md"
  "DevContent/Stub/manifest.json"
)

for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

echo "Building shared package..."
"${SWIFT_SHARED[@]}" build --scratch-path "$TEST_SCRATCH"

echo "Building app shell package..."
"${SWIFT_APP[@]}" build --package-path Apps/HGSSMac --scratch-path "$APP_SCRATCH"

echo "Running HeartGold opening extractor dry-run check..."
"${SWIFT_EXTRACTOR[@]}" run --scratch-path "$EXTRACTOR_SCRATCH" HGSSExtractCLI \
  --mode opening-heartgold \
  --input "$ROOT_DIR/DevContent/Stub" \
  --output "$ROOT_DIR/Content/Local/CheckRepoExtract" \
  --dry-run

echo "Verifying ignore rules for local content..."
if ! git check-ignore -q Content/Local/example_extracted_asset.bin; then
  echo "Expected Content/Local/* extracted files to be ignored by git rules." >&2
  exit 1
fi

echo "Repository checks passed."
