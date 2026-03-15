# Architecture

## Current Modules

- `HGSSDataModel`: shared schema types for normalized content and tooling.
- `HGSSContent`: loads checked-in fixtures today and will normalize extractor output later.
- `HGSSCore`: authoritative simulation loop, state updates, and render snapshots.
- `HGSSTelemetry`: event sinks and counters.
- `HGSSExtractCLI`: offline extraction entrypoint.
- `Apps/HGSSMac`: thin macOS shell for input and presentation.

## Dependency Direction

- App shell depends on core.
- Core depends on content, telemetry, and shared data model.
- Content depends on data model.
- Extractor depends on content and data model.

No package target should depend on app-shell code.

## Runtime Data Flow

1. App or tests locate `DevContent/Stub/manifest.json`.
2. `HGSSContent` decodes a normalized New Bark-centered multi-map slice with upstream and synthetic fixture provenance.
3. `HGSSCore` boots from `initialMapID` plus `initialEntryPointID`.
4. The fixed-timestep loop advances authoritative state against normalized collision data.
5. `HGSSCore` tick results can emit typed `TriggerEvent` envelopes keyed by map context and trigger identity.
6. The app shell renders snapshots and never owns gameplay rules.

## Normalization Boundary

- Upstream `MapHeader` fields are preserved as metadata.
- Upstream `map_matrix` and `zone_event` references are preserved as provenance.
- Upstream coordinates are converted into local tile coordinates before `HGSSCore` sees them.
- `entryPoints` are engine-defined anchors, not canonical upstream records.

This keeps the runtime stable while letting the extractor evolve around upstream file quirks.

## Future Modules (Documented, Not Yet Created)

Potential future targets once implementation warrants them:

- `HGSSScriptVM`
- `HGSSRender`
- `HGSSAudio`
- `HGSSHarness`

## Extraction Direction

Extraction stays offline and explicit:

- Input: user-local legally obtained files.
- Process: read upstream structures such as headers, matrix references, and event banks, then combine them with local normalization profiles where extraction is not complete yet.
- Output: normalized content under `Content/Local`.
- Runtime: load the normalized schema version that `HGSSCore` already understands.

The current checked-in fixture exists to prove the engine contract before broad extraction work begins.
