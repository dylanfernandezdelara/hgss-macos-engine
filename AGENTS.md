# AGENTS.md

Guidance for humans and coding agents working in this repository.

## Primary Goal

Build a native macOS HGSS engine incrementally with strict legal/asset hygiene and small ticket-based delivery.

## Architecture Boundaries

- `Apps/HGSSMac`: UI shell only (windowing, basic state presentation)
- `Sources/HGSSDataModel`: Shared domain and content schema types
- `Sources/HGSSContent`: Content loading and validation layer
- `Sources/HGSSCore`: Headless game/runtime core
- `Sources/HGSSTelemetry`: Metrics/event sinks
- `Sources/HGSSExtractCLI`: Offline extraction tooling stubs and future pipeline

Do not place game logic in app shell code.

## Content and Legal Hygiene

- Allowed in git: tiny synthetic fixtures in `DevContent/Stub`
- Never commit: ROMs, save files, extracted game assets, reverse-engineering dumps
- Keep local extraction outputs under `Content/Local`

## Required Commands Before PR

```bash
./scripts/check_repo.sh
./scripts/test.sh
./scripts/run_extractor_stub.sh
```

Run app manually when shell/UI changes:

```bash
./scripts/run_app.sh
```

## PR Expectations

- Link a Linear ticket
- Keep PR focused and small
- Include proof-of-work in PR body
- Update docs when module boundaries or developer workflows change
