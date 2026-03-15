# First Playable Slice

## Scope

The first slice is a playable excerpt of `MAP_NEW_BARK` backed by a normalized content contract.

Included:

- fixed-timestep core loop
- one controllable player
- local collision and bounds checks
- normalized warps
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

## Exit Criteria

- contributor can run the app and move around the New Bark excerpt
- loader validates normalized provenance and local coordinates
- core boots from `initialMapID` and `initialEntryPointID`
- snapshots expose collision, warp, and placement tiles
- tests cover determinism and normalization invariants

## Next Slice

The next chunk should replace more hand-authored layout stand-ins and add map transitions on top of the same normalized model. Collision for the New Bark excerpt is now expected to flow through the pret-backed extractor path while preserving the existing runtime contract.
