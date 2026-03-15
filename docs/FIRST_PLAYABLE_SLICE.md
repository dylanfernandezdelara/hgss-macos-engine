# First Playable Slice

## Scope

The first slice is a New Bark-centered multi-map excerpt backed by a normalized content contract.

Included:

- fixed-timestep core loop
- one controllable player
- local collision and bounds checks
- normalized warps across three checked-in maps
- normalized placement references for objects, coordinate triggers, and background events
- thin macOS grid renderer

Not included:

- script execution
- map transitions
- encounters
- battle system
- art-complete rendering

## Why This Slice

This proves the engine shape against upstream-informed data without committing the runtime to raw ROM structures. It also defines the minimum extractor output we need next.

## Included Map Boundaries

- `MAP_NEW_BARK`: 25x18 outdoor excerpt with the two pret-backed door warps that stay inside the current slice.
- `MAP_NEW_BARK_ELMS_LAB_1F`: 6x4 synthetic entrance-room slice with one synthetic arrival entry point and one return warp back to New Bark.
- `MAP_NEW_BARK_PLAYER_HOUSE_1F`: 5x4 synthetic entrance-room slice with one synthetic arrival entry point and one return warp back to New Bark.

Current cross-map contract:

- New Bark door warps must resolve to real normalized interior map records in the same manifest.
- Each included interior exposes an engine-defined `ENTRY_FROM_NEW_BARK` landing tile so later traversal tickets have a concrete arrival record to target.
- `destinationAnchor` is still preserved as upstream metadata only; runtime anchor-to-entry-point resolution is intentionally deferred.

Still excluded on purpose:

- rival house, southwest house, and other New Bark-linked interiors
- deeper interior floors or rooms beyond the first doorway landing
- runtime map transitions and anchor resolution semantics

## Exit Criteria

- contributor can run the app and move around the New Bark excerpt
- loader validates normalized provenance and local coordinates
- core boots from `initialMapID` and `initialEntryPointID`
- snapshots expose collision, warp, and placement tiles
- tests cover determinism and normalization invariants

## Next Slice

The next chunk should validate cross-map destinations and arrival-anchor behavior, then let the runtime actually traverse between these already-declared maps. After that, the synthetic interior stand-ins can be replaced with broader extractor-produced normalized output.
