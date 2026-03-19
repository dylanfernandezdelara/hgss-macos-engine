#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"
mkdir -p Content/Local

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if [[ -z "${LLVM_PREFIX:-}" ]] && command -v brew >/dev/null 2>&1; then
  BREW_LLVM_PREFIX="$(brew --prefix llvm 2>/dev/null || true)"
  if [[ -n "$BREW_LLVM_PREFIX" && -f "$BREW_LLVM_PREFIX/include/clang-c/Index.h" ]]; then
    export LLVM_PREFIX="$BREW_LLVM_PREFIX"
    echo "Using Homebrew LLVM at $LLVM_PREFIX"
  fi
fi

SWIFT=(xcrun swift)

echo "Resolving root package dependencies..."
"${SWIFT[@]}" package resolve

echo "Resolving app package dependencies..."
"${SWIFT[@]}" package resolve --package-path Apps/HGSSMac

echo "Preparing offline python extractor tools..."
"$ROOT_DIR/scripts/ensure_python_tools.sh"

echo "Bootstrap complete."
