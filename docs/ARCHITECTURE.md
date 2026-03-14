# Architecture

## Current Modules

- `HGSSDataModel`: Codable domain/content schema types used across modules.
- `HGSSContent`: Loads and validates content manifests and future extracted bundles.
- `HGSSCore`: Headless runtime boot path and future gameplay simulation state.
- `HGSSTelemetry`: Event sinks and instrumentation hooks.
- `HGSSExtractCLI`: Offline extraction pipeline entrypoint (currently stub).
- `Apps/HGSSMac`: Native macOS shell and presentation layer.

## Dependency Direction

- App shell depends on core.
- Core depends on content + telemetry + shared data model.
- Content depends on data model.
- Extractor depends on content/data model.

No package target should depend on app shell code.

## Future Modules (Documented, Not Yet Created)

Potential future targets once real implementation warrants them:

- `HGSSScriptVM`
- `HGSSRender`
- `HGSSAudio`
- `HGSSHarness`

These are intentionally deferred to avoid empty-target churn.

## Runtime Data Flow (Today)

1. App or tests locate `DevContent/Stub/manifest.json`.
2. `HGSSContent` decodes manifest into `HGSSManifest`.
3. `HGSSCore` boots headless runtime with telemetry events.
4. App displays status from core runtime.

## Extraction Integration Direction

Long-term extraction should remain offline and explicit:

- Input: user-local legally obtained files
- Process: extractor transforms into normalized local content layout
- Output: `Content/Local` only
- Runtime: content layer loads extracted output by schema version
