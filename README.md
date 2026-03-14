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

## Content and Legal Hygiene

- Commit only source code, docs, and synthetic fixtures.
- Never commit ROMs, save files, proprietary extracted assets, or dumps.
- Keep local extraction outputs in `Content/Local/`.

See `docs/LEGAL_AND_ASSET_HYGIENE.md`.

## Workflow

- Use small Linear-ticketed PRs.
- Include proof-of-work in PRs.
- Keep game logic in `Sources/`, not in `Apps/HGSSMac`.

See `WORKFLOW.md`, `AGENTS.md`, and `.github/pull_request_template.md`.
