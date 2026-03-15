# HGSS macOS Engine

Native macOS Pokemon HeartGold/SoulSilver engine scaffold (Swift + SPM), with a thin app shell and headless shared core modules.

## Current Scope

- `Apps/HGSSMac`: macOS app shell only
- `Sources/HGSSDataModel`: shared schema/domain types
- `Sources/HGSSContent`: content loading
- `Sources/HGSSCore`: headless runtime
- `Sources/HGSSTelemetry`: telemetry/event sink
- `Sources/HGSSExtractCLI`: offline extractor stub
- `DevContent/Stub`: tiny checked-in synthetic content
- `Content/Local`: local extracted content (ignored)

## Quick Start

```bash
./scripts/bootstrap.sh
./scripts/test.sh
./scripts/run_extractor_stub.sh
./scripts/run_app.sh
./scripts/check_repo.sh
```

Optional upstream-informed extractor run:

```bash
POKEHEARTGOLD_ROOT=/path/to/pokeheartgold ./scripts/run_extractor_stub.sh
```

## Content and Legal Hygiene

- Commit only source code, docs, and synthetic fixtures.
- Never commit ROMs, save files, proprietary extracted assets, or dumps.
- Keep local extraction outputs in `Content/Local/`.
- Keep local `pokeheartgold` clones outside git or under ignored paths such as `External/`.

See `docs/LEGAL_AND_ASSET_HYGIENE.md`.

## Workflow

- Use small Linear-ticketed PRs.
- Include proof-of-work in PRs.
- Keep game logic in `Sources/`, not in `Apps/HGSSMac`.

See `docs/ENGINE_CONTRACT.md`, `WORKFLOW.md`, `AGENTS.md`, and `.github/pull_request_template.md`.

## Symphony

This repo is configured with a Symphony workflow template at `Symphony/WORKFLOW.md`.

This repo follows the upstream `openai/symphony` operating model as closely as practical.
Upstream's recommended launch shape is `mise exec -- ./bin/symphony ./WORKFLOW.md`. For this repo,
use the helper below as a thin wrapper around that same flow:

```bash
cp .symphony.local.env.example .symphony.local.env
# edit .symphony.local.env and set SYMPHONY_LINEAR_PROJECT_SLUG
./scripts/run_symphony.sh
```

The wrapper should not be treated as a separate Symphony mode. It exists only to apply repo-local
setup and then invoke the upstream foreground `mise exec` service startup. Current repo-local
additions are limited to:

- reading `.symphony.local.env`
- resolving `LINEAR_API_KEY`
- patching the runtime workflow with this repo's Linear project slug
- adding Symphony's required preview acknowledgment flag

Run Symphony in its own Terminal window or tab and leave that terminal open while it is active.
Dashboard behavior matches upstream: disabled by default, enabled only when you pass `--port
<port>`, for example `./scripts/run_symphony.sh --port 4000`.

Per-ticket code changes do not run in the main repo checkout. Symphony creates isolated issue
workspaces under `SYMPHONY_WORKSPACE_ROOT`, and this repo follows the upstream example by cloning
the repository into each workspace via `hooks.after_create`. Git worktrees are not the documented
default here.

See `docs/SYMPHONY_SETUP.md` for full setup and customization options.
