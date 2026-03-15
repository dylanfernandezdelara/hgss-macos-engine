# Content Schema

The checked-in normalized fixture still lives at `DevContent/Stub/manifest.json`, but the exact contract is defined by the current code and summarized in `docs/ENGINE_CONTRACT.md`.

Use these files as the source of truth for schema shape:

- `Sources/HGSSDataModel/HGSSManifest.swift` for the manifest records
- `Sources/HGSSContent/StubWorldContent.swift` for loader validation and normalized runtime-facing content
- `docs/ENGINE_CONTRACT.md` for compatibility rules, unstable areas, and additive-vs-breaking guidance

## Current Shape Summary

The current content contract has two layers:

- the serialized manifest checked into `DevContent/Stub/manifest.json`
- the validated in-memory normalized content exposed by `NormalizedWorldContent` and `NormalizedPlayableMap`

The manifest is broader than the original slice doc. In addition to boot map fields, it currently includes:

- bundle metadata: `schemaVersion`, `title`, `build`, `pokemon`, `notes`
- per-map metadata: `mapID`, `displayName`, `provenance`, `header`, `layout`, `collision`
- normalized traversal references: `entryPoints`, `warps`, `placements`

The runtime-facing normalization boundary is still the same:

- `HGSSCore` consumes normalized local tile coordinates
- upstream references stay in provenance and preserved metadata fields
- warps and placements keep `sourcePosition` for validation and debugging
- the current extractor flow may still combine local profile data with upstream-derived fields

Current validation and extractor-parity expectations include:

- `initialMapID` must exist.
- `initialEntryPointID` must exist on the initial map.
- `layout.width` and `layout.height` must be positive.
- `entryPoints`, `warps`, and `placements` must be inside local bounds.
- `sourcePosition` must normalize to the declared `localPosition`.
- `placements` must have positive extents and remain inside bounds.
- `Tests/Fixtures/PretNewBark/generated_new_bark_map.json` is the committed extractor parity contract for generated header provenance, warps, and placements using fixture-only upstream inputs.
- `Tests/Fixtures/PretNewBark/generated_new_bark_manifest.json` is the full generated-manifest snapshot emitted from the committed pret-style fixtures.
- `PretNewBarkNormalizationTests` asserts the normalizer output matches that manifest snapshot exactly, while also pinning the generated map slice and normalization invariants.

## Compatibility Rule

Treat `docs/ENGINE_CONTRACT.md` as the contributor-facing policy document for deciding whether a schema or runtime proposal is additive or breaking. Breaking normalized manifest changes must bump `schemaVersion`.
