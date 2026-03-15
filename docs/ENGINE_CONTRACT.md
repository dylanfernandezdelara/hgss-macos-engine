# Engine Contract and Change Policy

## Status

This document describes the engine contract implemented in the repository today. It is a pre-v1 contract snapshot, not a final freeze.

The source of truth for the shapes below is the current code in:

- `Sources/HGSSDataModel/HGSSManifest.swift`
- `Sources/HGSSContent/StubWorldContent.swift`
- `Sources/HGSSCore/GameModels.swift`
- `Sources/HGSSCore/GameReducer.swift`
- `Sources/HGSSCore/CoreRuntime.swift`

The goal is to let contributors extend the engine without accidentally changing existing content or runtime meaning.

## Normalized Content Contract

### Manifest shape

`HGSSManifest` currently contains these top-level fields:

| Field | Meaning today |
| --- | --- |
| `schemaVersion` | Schema compatibility marker for normalized content. Breaking manifest changes must bump this. |
| `title` | Human-readable content bundle title. Surfaced in `CoreSnapshot`. |
| `build` | Human-readable content build identifier. Surfaced in `CoreSnapshot`. |
| `initialMapID` | Map loaded when the runtime boots. Must match a defined map. |
| `initialEntryPointID` | Entry point used for boot on the initial map. Must exist on `initialMapID`. |
| `maps` | Normalized playable map records. At least one map is required. |
| `pokemon` | Bundle-level Pokemon metadata records. Preserved in content, not used by `HGSSCore` yet. |
| `notes` | Freeform bundle notes. Preserved in content, not used by `HGSSCore` yet. |

### Map shape

Each `maps[]` entry currently contains:

| Field | Meaning today |
| --- | --- |
| `mapID` | Stable normalized map identifier. Must be unique within the manifest. |
| `displayName` | Human-readable map name. Surfaced in `CoreSnapshot.mapName`. |
| `provenance` | Upstream references preserved for debugging and extractor traceability. |
| `header` | Selected upstream map-header metadata preserved in normalized form. |
| `layout.width` / `layout.height` | Playable local-tile bounds. Both must be positive. |
| `layout.sourceOrigin` | Upstream origin used to normalize upstream coordinates into local tile coordinates. |
| `collision.impassableTiles` | Local tiles that block movement today. |
| `entryPoints` | Engine-defined anchors used for boot and later arrival handling. |
| `warps` | Normalized warp tiles with preserved upstream source coordinates and destination metadata. |
| `placements` | Normalized object, coordinate-trigger, and background-event references. |

### Supporting record fields

The nested record fields currently carried by the manifest are:

| Record | Fields |
| --- | --- |
| `GridPoint` | `x`, `y` |
| `SourcePoint` | `x`, `z`, `y` |
| `MapProvenance` | `upstreamMapID`, `mapHeaderSymbol`, `matrixID`, `eventsBank` |
| `MapHeaderMetadata` | `wildEncounterBank`, `areaDataBank`, `moveModelBank`, `worldMapX`, `worldMapY`, `mapSection`, `mapType`, `followMode`, `bikeAllowed`, `flyAllowed`, `isKanto`, `weather`, `cameraType` |
| `MapLayout` | `width`, `height`, `sourceOrigin` |
| `CollisionLayer` | `impassableTiles` |
| `PokemonEntry` | `species`, `nationalDex` |

These fields are preserved without exposing raw upstream file formats to `HGSSCore`.

`HGSSCore` does not currently use the preserved header metadata for gameplay decisions. It is part of the normalized content contract because the loader retains it and downstream tooling can rely on it being present.

### Coordinate normalization

The runtime-facing coordinate system is local 2D tile space. For warps and placements, normalization currently means:

- `local.x = sourcePosition.x - layout.sourceOrigin.x`
- `local.y = sourcePosition.z - layout.sourceOrigin.z`
- `sourcePosition.y` is preserved as metadata and is not used by current 2D movement logic

This local coordinate frame is the main boundary between extractor-facing data and runtime-facing data.

### Entry points, warps, and placements

The current normalized records are:

| Record | Fields |
| --- | --- |
| `EntryPoint` | `id`, `localPosition`, `facing`, `summary` |
| `Warp` | `id`, `localPosition`, `sourcePosition`, `destinationMapID`, `destinationAnchor`, `summary` |
| `Placement` | `id`, `kind`, `localPosition`, `sourcePosition`, `width`, `height`, `scriptReference`, `summary` |

`Placement.kind` is currently a closed enum with exactly these cases:

- `object`
- `coordinateTrigger`
- `backgroundEvent`

### Loader guarantees

`NormalizedWorldContent` currently guarantees all of the following before `HGSSCore` sees content:

- the manifest contains at least one map
- every `mapID` is unique
- `initialMapID` exists
- `initialEntryPointID` exists on the initial map
- every map has positive bounds
- blocked tiles are inside bounds
- entry point IDs are unique per map and stay inside bounds
- warp IDs are unique per map and stay inside bounds
- placement IDs are unique per map
- every placement has positive size and fully stays inside bounds
- each warp `sourcePosition` normalizes back to its declared `localPosition`
- each placement `sourcePosition` normalizes back to its declared `localPosition`

The loader does not currently guarantee all possible cross-record invariants. In particular:

- `destinationMapID` is preserved but not validated against the manifest
- `destinationAnchor` is preserved but not resolved to an entry point
- `facing` is preserved but not interpreted
- overlap between blocked tiles, warps, and placements is allowed
- overlap between warps and placements is allowed and exists in the stub fixture

## Runtime Contract

### Commands

`CoreCommand` currently has exactly two cases:

- `.idle`
- `.move(MovementDirection)`

`MovementDirection` currently has exactly four cases:

- `up`
- `down`
- `left`
- `right`

### Authoritative state

`GameState` currently contains:

| Field | Meaning today |
| --- | --- |
| `tick` | Monotonic tick counter advanced once per reducer step. |
| `currentMapID` | Current normalized map identifier. Booted from `initialMapID`. |
| `playerPosition` | Player location in local tile coordinates. |

### Reducer result surface

`GameReducer.step` currently returns `GameStepResult`:

| Field | Meaning today |
| --- | --- |
| `state` | The post-step authoritative state. |
| `outcome` | A reducer-classified result for the attempted command. |

`GameStepOutcome` currently has exactly three cases:

- `.idle`
- `.moved(MovementDirection)`
- `.blocked(MovementDirection)`

This reducer outcome is the only explicit movement-result classification today. `HGSSCoreRuntime.send(command:)` and `advanceOneTick()` currently return only the derived `CoreSnapshot`, not the reducer outcome.

### Reducer semantics

`GameReducer.step` currently behaves as follows:

- every call advances `tick` by exactly one, including `.idle` and blocked movement
- `.move(direction)` proposes one orthogonal tile move
- movement succeeds only when the proposed tile is inside map bounds and not in `blockedTiles`
- blocked moves leave `currentMapID` and `playerPosition` unchanged
- successful moves update `playerPosition` and keep `currentMapID` unchanged
- warps and placements are not consulted during movement resolution
- no trigger, script, encounter, or transition side effect is emitted

### Runtime boot and stepping

`HGSSCoreRuntime.bootWithStubContent` currently:

- loads normalized content from the caller-provided stub root
- repo scripts, tests, and the macOS shell currently point that boot path at `DevContent/Stub`
- boots on `initialMapID` and `initialEntryPointID`
- sets `tick = 0`
- sets `playerPosition` to the initial entry point tile

`HGSSCoreRuntime` currently supports two stepping styles:

- `send(command:)` applies one explicit command immediately
- `setHeldDirection(_:)` plus `advanceOneTick()` or `start()` applies the held direction on each tick until changed

The fixed-timestep loop uses `CoreLoopConfiguration.gameplay` by default:

- `tickDuration = 16_666_667ns`
- `maximumCatchUpTicks = 5`

If the loop falls behind by more than the catch-up budget, it clamps the accumulator and continues instead of replaying an unbounded number of ticks.

### Snapshot semantics

`CoreSnapshot` currently exposes:

| Field | Meaning today |
| --- | --- |
| `title` | Copied from `manifest.title`. |
| `build` | Copied from `manifest.build`. |
| `mapID` | Current map identifier. |
| `mapName` | Current map display name. |
| `mapWidth` / `mapHeight` | Current map bounds. |
| `blockedTiles` | All blocked local tiles on the current map. |
| `warpTiles` | All warp local tiles on the current map. Overlay/reference data only today. |
| `placementTiles` | Union of all placement-occupied local tiles on the current map. Overlay/reference data only today. |
| `tick` | Current tick value after the latest step. |
| `playerPosition` | Current player tile. |

`statusLine` is a convenience presentation string derived from other fields. Its exact wording is not a compatibility promise.

### Telemetry

`HGSSCoreRuntime` emits in-memory telemetry counters for operational visibility, including boot, tick, movement, and loop-clamp events.

The existence of telemetry as a debugging aid is part of the current implementation, but specific event names are not a frozen gameplay contract unless they are later documented separately.

## Known Unstable Areas

The following areas are intentionally not frozen yet.

### Warp transitions

Warps are normalized and surfaced as `warpTiles`, but stepping onto a warp tile does not currently change maps, emit a transition event, or resolve `destinationAnchor`.

Any work that turns a warp tile into actual traversal behavior should be treated as a contract-sensitive change.

### Arrival handling

`EntryPoint.facing` and `Warp.destinationAnchor` are preserved for future arrival logic, but the runtime does not currently consume them.

Arrival-facing behavior is therefore unstable in at least these ways:

- which arrival anchor type becomes canonical
- whether arrival state lives in `GameState`, a command result, a transition event, or a richer snapshot
- whether facing is represented as a string forever or normalized into a stricter type later

### Trigger and script emission

Placements currently preserve source coordinates, dimensions, kind, and optional `scriptReference`, but they do not emit gameplay events.

That means all of the following are still unstable:

- when coordinate triggers fire
- whether background events require facing or interaction commands
- how object placements participate in collisions, cutscenes, or scripting
- what event payload type the runtime will expose once triggers become active

### Multi-map behavior

The manifest can contain multiple maps, but the current runtime does not traverse between them. `currentMapID` is fixed after boot in the current implementation.

## Additive vs Breaking Changes

Use this section when evaluating proposals.

### Additive changes

A change is additive when existing manifests and existing runtime consumers keep their current meaning without reinterpretation.

Current examples of additive changes:

- adding more maps, warps, placements, entry points, blocked tiles, Pokemon metadata records, or notes within the existing schema rules
- adding new optional manifest metadata that older runtime code can ignore without changing behavior
- adding new snapshot fields while preserving the exact meaning of existing fields
- adding new runtime events or transition APIs alongside the existing movement/snapshot contract
- replacing hand-authored extraction inputs with offline-derived data when the normalized fields keep the same meaning

### Breaking changes

A change is breaking when existing manifests need rewriting, existing fields change meaning, or current runtime consumers would observe different semantics from the same inputs.

Current examples of breaking changes:

- removing, renaming, or changing the meaning of any existing manifest field
- changing the local coordinate frame or the source-to-local normalization rule
- changing how `tick` advances for `.idle`, successful movement, or blocked movement
- changing movement so existing `blockedTiles` no longer mean "cannot enter this tile"
- changing `warpTiles` or `placementTiles` from passive overlay/reference data into implicit behavior without introducing an explicit new contract surface
- changing `EntryPoint`, `Warp`, or `Placement` identifiers so existing references no longer resolve
- adding a new `Placement.kind` value without coordinating a schema/runtime update, because the enum is closed today
- changing `destinationAnchor` or `facing` semantics without documenting a migration path

## Change Rules Before a True v1 Freeze

Until the engine declares a true v1 freeze:

- prefer additive extensions over repurposing existing fields
- preserve normalized local coordinates as the runtime boundary
- keep unstable traversal and trigger work behind new fields or new runtime surfaces when possible
- bump `schemaVersion` for breaking manifest changes
- update this document, the relevant tests, and extractor/runtime code in the same change

The practical rule is simple: if the same manifest would behave differently after the change and the difference is not clearly modeled as a new surface, treat it as breaking.
