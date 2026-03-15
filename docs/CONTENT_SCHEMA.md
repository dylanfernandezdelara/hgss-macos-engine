# Content Schema

The checked-in normalized fixture still lives at `DevContent/Stub/manifest.json`, but the exact contract is defined by the current code and summarized in `docs/ENGINE_CONTRACT.md`.

Use these files as the source of truth for schema shape:

- `Sources/HGSSDataModel/HGSSManifest.swift` for the manifest records
- `Sources/HGSSContent/StubWorldContent.swift` for loader validation and normalized runtime-facing content
- `docs/ENGINE_CONTRACT.md` for compatibility rules, unstable areas, and additive-vs-breaking guidance

## Current Shape Summary

The manifest is broader than the original slice doc. In addition to boot map fields, it currently includes:

- bundle metadata: `schemaVersion`, `title`, `build`, `pokemon`, `notes`
- per-map metadata: `mapID`, `displayName`, `provenance`, `header`, `layout`, `collision`
- normalized traversal references: `entryPoints`, `warps`, `placements`

The runtime-facing normalization boundary is still the same:

- `HGSSCore` consumes normalized local tile coordinates
- upstream references stay in provenance and preserved metadata fields
- warps and placements keep `sourcePosition` for validation and debugging
- the current extractor flow may still combine local profile data with upstream-derived fields

## Compatibility Rule

Treat `docs/ENGINE_CONTRACT.md` as the contributor-facing policy document for deciding whether a schema or runtime proposal is additive or breaking. Breaking normalized manifest changes must bump `schemaVersion`.
