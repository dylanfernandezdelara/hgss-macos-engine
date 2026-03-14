# HGSS macOS Engine (Repo Bootstrap)

Native macOS Pokémon HeartGold/SoulSilver engine foundation with a thin app shell and shared Swift package modules.

This repository is intentionally initialized for workflow readiness, not full gameplay implementation.

## What Exists Today

- Thin macOS app shell at `Apps/HGSSMac`
- Shared Swift package targets:
  - `HGSSDataModel`
  - `HGSSContent`
  - `HGSSCore`
  - `HGSSTelemetry`
  - `HGSSExtractCLI` (stub extractor CLI)
- Checked-in fake content at `DevContent/Stub`
- Local-only content area at `Content/Local`
- Smoke tests and CI
- Ticket-oriented workflow docs for Symphony + Linear

## Quick Start

```bash
./scripts/bootstrap.sh
./scripts/test.sh
./scripts/run_extractor_stub.sh
./scripts/run_app.sh
./scripts/check_repo.sh
```

## Repo Layout

- `Apps/HGSSMac`: Native macOS shell (UI and app entry only)
- `Sources/*`: Shared package modules and CLI
- `Tests/*`: Smoke tests and future module tests
- `DevContent/Stub`: Tiny fake checked-in content
- `Content/Local`: Local extracted content (ignored in git)
- `docs`: Architecture, schema, legal/asset hygiene, roadmap docs
- `scripts`: Stable local automation commands
- `.github`: CI and issue/PR templates

## Content Policy

- `DevContent/Stub` is fake, tiny, and safe to commit.
- `Content/Local` is for local extracted data and never committed.
- ROMs, extracted commercial assets, saves, and dumps are never committed.

See `docs/LEGAL_AND_ASSET_HYGIENE.md` and `.gitignore` for strict rules.

## Workflow

- Use small Linear-ticketed PRs.
- Include proof-of-work in every PR.
- Keep app shell thin; build engine behavior in shared package modules.

See `WORKFLOW.md` and `.github/pull_request_template.md`.
