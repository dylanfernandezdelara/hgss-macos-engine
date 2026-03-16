# Architecture

## Current Modules

- `HGSSDataModel`: shared schema types for normalized content and tooling.
- `HGSSContent`: loads checked-in fixtures today and will normalize extractor output later.
- `HGSSCore`: authoritative simulation loop, state updates, and render snapshots.
- `HGSSRender`: render-bundle loading, DS screen layout rules, and dual-screen presentation helpers.
- `HGSSTelemetry`: event sinks and counters.
- `HGSSExtractCLI`: offline extraction entrypoint.
- `Apps/HGSSMac`: thin macOS shell for input and presentation.

## Dependency Direction

- App shell depends on core and render.
- Core depends on content, telemetry, and shared data model.
- Render depends on core and data model.
- Content depends on data model.
- Extractor depends on content and data model.

No package target should depend on app-shell code.

## Runtime Data Flow

1. `HGSSExtractCLI` emits a normalized `manifest.json` and a local-only `render_bundle.json` under `Content/Local`.
2. `HGSSContent` decodes the normalized New Bark-centered multi-map slice with upstream and synthetic provenance preserved in the contract.
3. `HGSSCore` boots from `initialMapID` plus `initialEntryPointID` and owns authoritative position and facing.
4. `HGSSCore` step results expose deterministic movement outcomes for render-side interpolation.
5. `HGSSRender` loads the render bundle, applies DS integer-scaling rules, and layers optional developer overlays over the extracted top and bottom screen assets.
6. `Apps/HGSSMac` hosts the window, boots the authoritative snapshot, toggles developer overlays, and never owns gameplay rules.

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
- Process: read upstream structures such as headers, matrix references, and event banks, then combine them with local normalization profiles where extraction is not complete yet.
- Output: normalized content plus local-only render bundles under `Content/Local`, currently including fixed New Bark parity assets for the top screen, bottom screen, and Ethan sprite-sheet slot.
- Runtime: load the normalized schema version that `HGSSCore` already understands and the render bundle that `HGSSRender` understands.

The current checked-in fixture exists to prove the engine contract before broad extraction work begins.

For the current content/runtime contract and change policy, see `docs/ENGINE_CONTRACT.md`.
