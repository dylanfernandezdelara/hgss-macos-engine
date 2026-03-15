#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYMPHONY_ROOT="$ROOT_DIR/External/symphony"
SYMPHONY_ELIXIR_DIR="$SYMPHONY_ROOT/elixir"
WORKFLOW_TEMPLATE="$ROOT_DIR/Symphony/WORKFLOW.md"
LOCAL_ENV_FILE="$ROOT_DIR/.symphony.local.env"

if [[ -f "$LOCAL_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV_FILE"
fi

if ! command -v mise >/dev/null 2>&1; then
  echo "mise is required. Install it from https://mise.jdx.dev/getting-started.html" >&2
  exit 1
fi

if [[ ! -f "$WORKFLOW_TEMPLATE" ]]; then
  echo "Missing workflow template: $WORKFLOW_TEMPLATE" >&2
  exit 1
fi

PROJECT_SLUG="${SYMPHONY_LINEAR_PROJECT_SLUG:-}"
if [[ -z "$PROJECT_SLUG" ]]; then
  echo "Set SYMPHONY_LINEAR_PROJECT_SLUG before running Symphony." >&2
  echo "Options:" >&2
  echo "  - export SYMPHONY_LINEAR_PROJECT_SLUG=..." >&2
  echo "  - set it in $LOCAL_ENV_FILE" >&2
  exit 1
fi

if [[ -z "${LINEAR_API_KEY:-}" ]]; then
  if LINEAR_API_KEY_FROM_KEYCHAIN="$(security find-generic-password -a "$(whoami)" -s symphony-linear-api-key -w 2>/dev/null)"; then
    export LINEAR_API_KEY="$LINEAR_API_KEY_FROM_KEYCHAIN"
  fi
fi

if [[ -z "${LINEAR_API_KEY:-}" ]]; then
  echo "Set LINEAR_API_KEY before running Symphony." >&2
  echo "Options:" >&2
  echo "  - export LINEAR_API_KEY=..." >&2
  echo "  - store in macOS Keychain service symphony-linear-api-key" >&2
  exit 1
fi

if [[ ! -d "$SYMPHONY_ROOT/.git" ]]; then
  echo "Cloning openai/symphony into External/symphony..."
  git clone --depth 1 https://github.com/openai/symphony "$SYMPHONY_ROOT"
else
  echo "Updating External/symphony..."
  git -C "$SYMPHONY_ROOT" fetch origin
  git -C "$SYMPHONY_ROOT" pull --ff-only origin main
fi

RUNTIME_WORKFLOW="$(mktemp "${TMPDIR:-/tmp}/hgss-symphony-workflow.XXXXXX.md")"
trap 'rm -f "$RUNTIME_WORKFLOW"' EXIT
sed "s/__PROJECT_SLUG__/${PROJECT_SLUG}/g" "$WORKFLOW_TEMPLATE" >"$RUNTIME_WORKFLOW"

mkdir -p "${SYMPHONY_WORKSPACE_ROOT:-$HOME/code/symphony-workspaces}"

ACK_FLAG="--i-understand-that-this-will-be-running-without-the-usual-guardrails"
EXTRA_ARGS=("$@")
HAS_ACK_FLAG="false"
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  for arg in "${EXTRA_ARGS[@]}"; do
    if [[ "$arg" == "$ACK_FLAG" ]]; then
      HAS_ACK_FLAG="true"
      break
    fi
  done
fi

if [[ "$HAS_ACK_FLAG" != "true" ]]; then
  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    EXTRA_ARGS=("$ACK_FLAG" "${EXTRA_ARGS[@]}")
  else
    EXTRA_ARGS=("$ACK_FLAG")
  fi
fi

cd "$SYMPHONY_ELIXIR_DIR"
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build

echo "Starting Symphony with workflow: $RUNTIME_WORKFLOW"
mise exec -- ./bin/symphony "$RUNTIME_WORKFLOW" "${EXTRA_ARGS[@]}"
