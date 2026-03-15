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

Requires a Swift 6 toolchain with Swift Testing support (`swift-tools-version: 6.0` in the root package).

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

See `WORKFLOW.md`, `AGENTS.md`, and `.github/pull_request_template.md`.

## Symphony

This repo is configured with a Symphony workflow template at `Symphony/WORKFLOW.md`.

Use the helper script to bootstrap and run the upstream Symphony reference implementation:

```bash
cp .symphony.local.env.example .symphony.local.env
# edit .symphony.local.env and set SYMPHONY_LINEAR_PROJECT_SLUG
./scripts/run_symphony.sh
```

The launcher always enables the observability UI. By default it serves at `http://localhost:4000/`; pass `--port <port>` to override.

See `docs/SYMPHONY_SETUP.md` for full setup and customization options.
