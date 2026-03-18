# HGSS macOS Engine

Native macOS Pokemon HeartGold/SoulSilver engine scaffold (Swift + SPM), with a thin app shell and headless shared core modules.

## Current Scope

- `Apps/HGSSMac`: macOS app shell only
- `Sources/HGSSDataModel`: shared schema/domain types
- `Sources/HGSSContent`: content loading
- `Sources/HGSSCore`: headless runtime
- `Sources/HGSSRender`: DS-style render contract loading plus a dedicated HeartGold opening-sequence player
- `Sources/HGSSTelemetry`: telemetry/event sink
- `Sources/HGSSExtractCLI`: offline extractor pipeline for the HeartGold opening boot path
- `DevContent/Stub`: tiny checked-in synthetic content
- `Content/Local`: local extracted content (ignored)

## Current Visual Milestone

The canonical first visual target is the HeartGold opening movie boot path:

- scenes `scene1` through `scene5`
- terminal `title_handoff`
- deterministic local-only output under `Content/Local/Boot/HeartGold`

The New Bark normalized content slice remains in-repo for non-default tests and later traversal work, but it is no longer the app's default boot experience.

The opening extractor emits local-only assets and metadata:

- `Content/Local/Boot/HeartGold/opening_bundle.json`
- `Content/Local/Boot/HeartGold/opening_provenance.json`
- `Content/Local/Boot/HeartGold/opening_reference.json`
- `Content/Local/Boot/HeartGold/opening_extract_report.json`
- `Content/Local/Boot/HeartGold/assets/<scene>/...`
- `Content/Local/Boot/HeartGold/audio/<scene>/...`
- `Content/Local/Boot/HeartGold/intermediate/{nitro2d,model3d,audio}/...`

## Quick Start

```bash
./scripts/bootstrap.sh
./scripts/run_extractor_stub.sh
./scripts/run_opening_reference_harness.sh
./scripts/run_app.sh
./scripts/test.sh
./scripts/check_repo.sh
```

`run_extractor_stub.sh` now defaults to `--mode opening-heartgold` and requires a local `pret/pokeheartgold` clone. The script will auto-use `External/pokeheartgold` when it exists.

Explicit pret-backed extractor run:

```bash
POKEHEARTGOLD_ROOT=/path/to/pokeheartgold ./scripts/run_extractor_stub.sh
```

To regenerate the opening reference contract and enriched audio traces, run:

```bash
./scripts/run_opening_reference_harness.sh
```

To diff the current opening extraction against an earlier local reference root or a copied `opening_reference.json`, pass it as the first argument:

```bash
./scripts/run_opening_reference_harness.sh /path/to/previous/HeartGold
```

The extractor resolves Nitro and audio tooling offline:

- `nitrogfx` for Nitro 2D decode
- `apicula` for 3D model conversion
- `ndspy` from the repo-local venv at `Content/Local/Tooling/ndspy-venv`

The reference harness is dev-only. It produces scene/timing metadata plus per-cue audio trace JSON under `Content/Local/Boot/HeartGold/intermediate/audio/...` so native playback changes can be compared against a stable extracted contract without shipping emulator code in the app.

The macOS shell now boots into the HeartGold opening player by default. Skip requests map to `A`, `Return`, and bottom-screen click. Developer overlays remain opt-in via `HGSS_OPENING_DEBUG_OVERLAY=1`, then toggle with `D`.

## Reference Model

- [`pret/pokeheartgold`](https://github.com/pret/pokeheartgold) is the sole source of truth for HeartGold opening scene behavior, timing, assets, provenance, and audio cue positions.
- [`PokeSwift`](https://github.com/Dimillian/PokeSwift) is an architectural reference only for the offline-extractor-plus-native-runtime pattern.
- The implementation model is extraction, not direct porting. The app plays a deterministic `HGSSOpeningBundle`; it does not translate DS C code into Swift line-by-line at runtime.

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

See `docs/HEARTGOLD_OPENING_PARITY.md`, `docs/ENGINE_CONTRACT.md`, `WORKFLOW.md`, `AGENTS.md`, and `.github/pull_request_template.md`.

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
