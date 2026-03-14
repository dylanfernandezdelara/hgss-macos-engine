# Workflow

This repository is optimized for Symphony + Linear as development infrastructure.

## Branching and Ticket Scope

1. Create or pick a Linear issue (one issue per coherent change).
2. Create a short-lived branch named `<linear-key>-<slug>`.
3. Keep changes small and reviewable.

## Pull Requests

Every PR must include:

- Linked Linear ticket (`ABC-123` style key)
- Problem statement and scope
- Proof-of-work (commands, tests, screenshots/log snippets)
- Explicit non-goals

Use `.github/pull_request_template.md`.

## Proof-of-Work Expectations

At minimum include:

- `./scripts/check_repo.sh` output summary
- `./scripts/test.sh` output summary
- App run confirmation for shell changes
- Extractor run confirmation for content/tooling changes

## Agent Operating Rules

- Treat Symphony and Linear as workflow tooling, not runtime dependencies.
- Keep engine logic in package modules under `Sources/`.
- Keep app shell in `Apps/HGSSMac` thin and declarative.
- Never commit ROMs, extracted proprietary assets, saves, or dumps.

## Definition of Done

A ticket is complete when:

- Code builds locally and in CI
- Relevant tests pass
- Docs are updated when boundaries or commands changed
- Asset hygiene rules are still satisfied
