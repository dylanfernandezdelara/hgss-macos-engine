# Content Schema

`DevContent/Stub/manifest.json` is a checked-in normalized fixture for the first New Bark-centered multi-map slice.

## Manifest Shape (v2)

```json
{
  "schemaVersion": 2,
  "initialMapID": "MAP_NEW_BARK",
  "initialEntryPointID": "ENTRY_BOOT_DEFAULT",
  "maps": [
    {
      "mapID": "MAP_NEW_BARK",
      "provenance": {
        "upstreamMapID": "MAP_NEW_BARK",
        "mapHeaderSymbol": "sMapHeaders[MAP_NEW_BARK]",
        "matrixID": "NARC_map_matrix_map_matrix_0000_EVERYWHERE_bin",
        "eventsBank": "NARC_zone_event_057_T20_bin"
      },
      "header": {
        "mapSection": "MAPSEC_NEW_BARK_TOWN",
        "mapType": "MAP_TYPE_CITY_TOWN"
      },
      "layout": {
        "width": 25,
        "height": 18,
        "sourceOrigin": { "x": 676, "z": 391, "y": 0 }
      },
      "collision": {
        "impassableTiles": [{ "x": 3, "y": 1 }]
      },
      "entryPoints": [
        {
          "id": "ENTRY_BOOT_DEFAULT",
          "localPosition": { "x": 1, "y": 1 }
        }
      ],
      "warps": [
        {
          "id": "WARP_ELMS_LAB_1F",
          "localPosition": { "x": 8, "y": 2 },
          "sourcePosition": { "x": 684, "z": 393, "y": 0 },
          "destinationMapID": "MAP_NEW_BARK_ELMS_LAB_1F",
          "destinationAnchor": 0
        }
      ],
      "placements": [
        {
          "id": "coord_T20_east_exit",
          "kind": "coordinateTrigger",
          "localPosition": { "x": 24, "y": 7 },
          "sourcePosition": { "x": 700, "z": 398, "y": 0 },
          "width": 1,
          "height": 5
        }
      ]
    }
  ]
}
```

The checked-in fixture currently includes three maps:

- `MAP_NEW_BARK`: upstream-informed outdoor excerpt for the first traversal slice.
- `MAP_NEW_BARK_ELMS_LAB_1F`: tiny synthetic entry-room slice that satisfies the first interior destination from New Bark.
- `MAP_NEW_BARK_PLAYER_HOUSE_1F`: tiny synthetic entry-room slice that satisfies the second pret-backed New Bark interior destination.

The two interior maps deliberately stop at the first room boundary. Their map IDs are real HGSS destinations, but their local bounds, collision, and source coordinates are small synthetic stand-ins until broader extractor coverage exists.

## Design Rules

- `HGSSCore` consumes only normalized local coordinates.
- Upstream `MapHeader`, `map_matrix`, and `zone_event` details stay in provenance or extractor-facing fields.
- `entryPoints` are engine-defined boot/arrival anchors.
- `warps.destinationMapID` must point at another normalized map record even while arrival-anchor semantics remain deferred.
- `warps` and `placements` preserve upstream source coordinates for validation and debugging.
- Collision in the current fixture is still checked-in stand-in data; long-term it should be derived offline from upstream map data into the same normalized contract.
- The extractor may combine local profile fields such as excerpt bounds, entry points, and temporary collision with upstream-derived header/event data until full extraction is implemented.
- The current fixture keeps only New Bark plus its first two pret-backed interior destinations; rival house, southwest house, and deeper interiors remain out of scope for this slice.

## Validation Rules

- `initialMapID` must exist.
- `initialEntryPointID` must exist on the initial map.
- `layout.width` and `layout.height` must be positive.
- `entryPoints`, `warps`, and `placements` must be inside local bounds.
- Each `warps.destinationMapID` must reference a defined map in the same manifest.
- `sourcePosition` must normalize to the declared `localPosition`.
- `placements` must have positive extents and remain inside bounds.
- `Tests/Fixtures/PretNewBark/generated_new_bark_map.json` is the committed extractor parity contract for generated header provenance, warps, and placements using fixture-only upstream inputs.
- `Tests/Fixtures/PretNewBark/generated_new_bark_manifest.json` is the full generated-manifest snapshot emitted from the committed pret-style fixtures.
- `PretNewBarkNormalizationTests` asserts the normalizer output matches that manifest snapshot exactly, while also pinning the generated map slice and normalization invariants.

## Evolution Policy

- Increment `schemaVersion` for breaking changes.
- Prefer extending the normalized contract over exposing raw upstream formats to `HGSSCore`.
- Add new extractor output only after the runtime needs it.
