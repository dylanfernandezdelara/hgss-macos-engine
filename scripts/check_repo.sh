#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

export HOME="$ROOT_DIR/.build/swiftpm-home"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"

SWIFTPM_CACHE_PATH="$ROOT_DIR/.build/swiftpm/cache"
SWIFTPM_CONFIG_PATH="$ROOT_DIR/.build/swiftpm/config"
SWIFTPM_SECURITY_PATH="$ROOT_DIR/.build/swiftpm/security"

mkdir -p \
  "$HOME" \
  "$CLANG_MODULE_CACHE_PATH" \
  "$SWIFTPM_CACHE_PATH" \
  "$SWIFTPM_CONFIG_PATH" \
  "$SWIFTPM_SECURITY_PATH"

SWIFT=(xcrun swift)
SWIFT_PACKAGE_FLAGS=(
  --disable-sandbox
  --manifest-cache local
  --cache-path "$SWIFTPM_CACHE_PATH"
  --config-path "$SWIFTPM_CONFIG_PATH"
  --security-path "$SWIFTPM_SECURITY_PATH"
)

echo "Checking required files..."
required=(
  "README.md"
  "WORKFLOW.md"
  "AGENTS.md"
  "docs/ARCHITECTURE.md"
  "docs/CONTENT_SCHEMA.md"
  "docs/FIRST_PLAYABLE_SLICE.md"
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
"${SWIFT[@]}" build "${SWIFT_PACKAGE_FLAGS[@]}"

echo "Building app shell package..."
"${SWIFT[@]}" build "${SWIFT_PACKAGE_FLAGS[@]}" --package-path Apps/HGSSMac

echo "Running extractor stub dry-run check..."
"${SWIFT[@]}" run "${SWIFT_PACKAGE_FLAGS[@]}" HGSSExtractCLI --input "$ROOT_DIR/DevContent/Stub" --output "$ROOT_DIR/Content/Local/CheckRepoExtract" --dry-run

echo "Verifying ignore rules for local content..."
if ! git check-ignore -q Content/Local/example_extracted_asset.bin; then
  echo "Expected Content/Local/* extracted files to be ignored by git rules." >&2
  exit 1
fi

echo "Repository checks passed."
