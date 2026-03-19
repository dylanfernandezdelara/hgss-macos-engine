# HeartGold Opening Parity

## Status

This is the active visual milestone for the repository.

The app now boots into the HeartGold opening movie path, plays scenes `scene1` through `scene5`, and enters a source-backed title-screen runtime driven by `opening_program_ir.json`. The current native endpoint is the title-to-menu handoff boundary; `CheckSave` and `MainMenu` remain the next milestone.

## Authority and Reference Model

- [`pret/pokeheartgold`](https://github.com/pret/pokeheartgold) is the sole behavioral and content authority for opening scene order, frame timing, transitions, provenance, title state flow, title handoff, and audio cue positions.
- [`PokeSwift`](https://github.com/Dimillian/PokeSwift) is architectural reference only for the offline-extractor-plus-native-runtime pattern.
- The implementation strategy is extraction, not direct porting. The extractor emits a deterministic `HGSSOpeningBundle`, and the Swift runtime plays that bundle.

## Bundle Contract

`HGSSOpeningBundle` lives in `Sources/HGSSDataModel/HGSSOpeningBundle.swift`.

Current invariants:

- `schemaVersion = 1`
- `canonicalVariant = heartGold`
- scene order is exactly `scene1`, `scene2`, `scene3`, `scene4`, `scene5`, `title_handoff`
- `title_handoff.durationFrames = 1`
- scene asset references point at emitted local-only assets
- skip behavior is gated by extracted `skipAllowedFromFrame`
- opening-specific render types must not depend on `HGSSCore` or `CoreSnapshot`

The bundle currently carries:

- screen dimensions for top and bottom DS screens
- shared asset table
- per-scene top/bottom layers
- sprite and model animation refs
- transition cues for fades, wipes, viewport/window changes, palette/brightness behavior, and scrolls
- audio cue metadata for start/stop timing and provenance

## Extractor Outputs

`HGSSExtractCLI --mode opening-heartgold` emits:

- `Content/Local/Boot/HeartGold/opening_bundle.json`
- `Content/Local/Boot/HeartGold/opening_program_ir.json`
- `Content/Local/Boot/HeartGold/opening_provenance.json`
- `Content/Local/Boot/HeartGold/opening_reference.json`
- `Content/Local/Boot/HeartGold/opening_extract_report.json`
- `Content/Local/Boot/HeartGold/assets/<scene>/...`
- `Content/Local/Boot/HeartGold/audio/<scene>/...`
- `Content/Local/Boot/HeartGold/intermediate/{nitro2d,model3d,audio}/...`

`opening_reference.json` is a dev-only extracted contract for parity work. It records:

- the canonical scene timing contract used by the current extraction
- the source files that informed that extraction pass
- local relative paths to per-cue WAV output
- local relative paths to per-cue audio trace JSON files

The audio trace JSON files under `intermediate/audio/...` are intended for regression and diff tooling. They expose rendered-note spans plus per-track controller timelines so native audio changes can be compared against a stable extracted reference.

Tooling rules:

- `nitrogfx` decodes Nitro 2D assets
- `apicula` converts Nitro 3D assets
- `ndspy` inspects and extracts SDAT-backed cue metadata
- runtime playback never shells out to these tools

Audio scope for this milestone is `cue + direct`: cue timing and provenance must be extracted and validated, while only directly emitted runtime-playable assets are in scope. Full DS sequence synthesis is out of scope.

## Renderer Boundary

The opening player is isolated from the overworld shell.

Responsibilities owned by `HGSSRender` for this milestone:

- dual-screen timed layer composition
- palette fades and brightness overlays
- background scroll
- sprite/cell animation playback
- simple 3D model animation playback
- circle wipes and viewport/window narrowing
- frame-driven audio cue dispatch
- source-backed title-screen state sequencing through the title-to-menu handoff boundary

Responsibilities intentionally out of scope:

- native `CheckSave` rendering
- native `MainMenu` rendering
- gameplay state boot from `HGSSCore`
- overworld traversal or script execution
- emulator-dependent validation

## Validation

The required checks for this milestone are:

- `./scripts/check_repo.sh`
- `./scripts/test.sh`
- `./scripts/run_extractor_stub.sh`
- `./scripts/run_opening_reference_harness.sh` when opening timing, transition, or audio behavior changes
- `./scripts/run_opening_menu_parity_harness.sh` when parser-backed opening/menu IR or post-title runtime behavior changes
- `./scripts/run_app.sh` for app-shell or opening-player changes

The reference harness may also be used in diff mode:

```bash
./scripts/run_opening_reference_harness.sh /path/to/previous/HeartGold
```

This reruns extraction and compares the current `opening_reference.json` plus referenced audio trace files against a previous local snapshot.

Extractor tests must cover:

- exact canonical scene set
- local asset resolution for scene refs
- provenance coverage for visual and audio sources
- placeholder-term rejection
- byte-stable repeated writes

Renderer tests must cover:

- scene order and frame durations
- skip gating
- title-screen IR state progression through menu handoff
- audio cue dispatch timing
