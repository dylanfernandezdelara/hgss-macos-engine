# Architecture

## Current Modules

- `HGSSDataModel`: shared schema types for normalized content and tooling.
- `HGSSContent`: loads checked-in fixtures today and will normalize extractor output later.
- `HGSSCore`: authoritative simulation loop, state updates, and render snapshots.
- `HGSSRender`: render-bundle loading, DS screen layout rules, dual-screen presentation helpers, and the HeartGold opening-sequence player.
- `HGSSTelemetry`: event sinks and counters.
- `HGSSExtractCLI`: offline extraction entrypoint for normalized content and the HeartGold opening boot path.
- `Apps/HGSSMac`: thin macOS shell for input and presentation.

## Dependency Direction

- App shell depends on render for the default HeartGold opening boot path.
- Core depends on content, telemetry, and shared data model.
- Render depends on data model and still imports core for the legacy New Bark-oriented dual-screen shell.
- Content depends on data model.
- Extractor depends on content and data model.

No package target should depend on app-shell code.

Opening-specific render types must stay isolated from `CoreSnapshot` and `HGSSCore`, even while `HGSSRender` still contains older traversal-facing helpers.

## Runtime Data Flow

There are now two active runtime tracks:

1. `HGSSExtractCLI --mode opening-heartgold` emits `opening_bundle.json`, provenance, reports, and local-only assets under `Content/Local/Boot/HeartGold`.
2. The dev-only reference harness reruns that extraction, writes `opening_reference.json`, and captures local trace artifacts for opening cue/timing validation without shipping emulator code in the app.
3. `HGSSRender` loads `HGSSOpeningBundle`, advances a frame-driven playback controller, renders dual-screen layers, sprites, and models, and holds on the first stable HeartGold `title_handoff` frame.
4. `Apps/HGSSMac` boots directly into that opening player and owns only shell concerns such as windowing, skip-input routing, and dev-only overlays.
5. The older normalized-content path remains in parallel: `HGSSContent` decodes the New Bark-centered fixture, `HGSSCore` owns authoritative traversal state, and the legacy dual-screen render helpers remain available for non-default tests and follow-on work.

## Normalization Boundary

- Upstream `MapHeader` fields are preserved as metadata.
- Upstream `map_matrix` and `zone_event` references are preserved as provenance.
- Upstream coordinates are converted into local tile coordinates before `HGSSCore` sees them.
- `entryPoints` are engine-defined anchors, not canonical upstream records.

This keeps the runtime stable while letting the extractor evolve around upstream file quirks.

## Future Modules (Documented, Not Yet Created)

Potential future targets once implementation warrants them:

- `HGSSScriptVM`
- `HGSSAudio`
- `HGSSHarness`

## Extraction Direction

Extraction stays offline and explicit:

- Input: user-local legally obtained files.
- Process: read upstream structures and assets from [`pret/pokeheartgold`](https://github.com/pret/pokeheartgold), then extract deterministic native bundles rather than porting DS code directly into Swift.
- Output: local-only normalized content plus local-only opening playback bundles under `Content/Local`.
- Validation: a dev-only reference harness may emit additional local-only trace artifacts such as `opening_reference.json` and per-cue audio traces for parity work.
- Runtime: load the normalized schema version that `HGSSCore` understands for traversal work, and load `HGSSOpeningBundle` in the opening player for boot-sequence work.

`PokeSwift` is useful as an architectural reference for the extractor/runtime split, but it is not a behavioral source for HGSS timings, assets, or scene logic.

For the current content/runtime contract and change policy, see `docs/ENGINE_CONTRACT.md`. For the active visual milestone, see `docs/HEARTGOLD_OPENING_PARITY.md`.
