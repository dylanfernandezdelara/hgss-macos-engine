import XCTest
import HGSSContent
import HGSSCore
import HGSSDataModel

final class GameReducerTriggerDetectionTests: XCTestCase {
    func testEnteringTriggerTileEmitsTypedHitsInPlacementOrder() throws {
        let map = try makeMap(
            placements: [
                placement(
                    id: "object_npc",
                    kind: .object,
                    x: 1,
                    y: 1,
                    scriptReference: "script:100"
                ),
                placement(
                    id: "coord_gate",
                    kind: .coordinateTrigger,
                    x: 1,
                    y: 1,
                    width: 1,
                    height: 2,
                    scriptReference: "script:200"
                ),
                placement(
                    id: "bg_sign",
                    kind: .backgroundEvent,
                    x: 1,
                    y: 1,
                    scriptReference: "script:300"
                )
            ]
        )

        let result = GameReducer.step(
            state: GameState(
                tick: 0,
                currentMapID: map.id,
                playerPosition: TilePosition(x: 0, y: 1)
            ),
            command: .move(.right),
            map: map
        )

        XCTAssertEqual(result.outcome, .moved(.right))
        XCTAssertEqual(result.state.tick, 1)
        XCTAssertEqual(result.state.playerPosition, TilePosition(x: 1, y: 1))
        XCTAssertEqual(result.triggerEvents.map(\.trigger.id), ["object_npc", "coord_gate", "bg_sign"])
        XCTAssertEqual(result.triggerEvents.map(\.trigger.kind), [.object, .coordinateTrigger, .backgroundEvent])
        XCTAssertTrue(result.triggerEvents.allSatisfy { $0.tick == 1 })
        XCTAssertTrue(result.triggerEvents.allSatisfy { $0.playerPosition == TilePosition(x: 1, y: 1) })
        XCTAssertTrue(result.triggerEvents.allSatisfy { $0.map.mapID == "MAP_TEST" })
        XCTAssertTrue(result.triggerEvents.allSatisfy { $0.map.eventsBank == "TEST_EVENTS" })
    }

    func testCoordinateTriggerOccupancyCoversFullDeclaredRectangle() throws {
        let map = try makeMap(
            placements: [
                placement(
                    id: "coord_gate",
                    kind: .coordinateTrigger,
                    x: 2,
                    y: 1,
                    width: 2,
                    height: 2,
                    scriptReference: "script:200"
                )
            ]
        )

        let result = GameReducer.step(
            state: GameState(
                tick: 5,
                currentMapID: map.id,
                playerPosition: TilePosition(x: 3, y: 1)
            ),
            command: .move(.down),
            map: map
        )

        XCTAssertEqual(result.outcome, .moved(.down))
        XCTAssertEqual(result.state.playerPosition, TilePosition(x: 3, y: 2))
        XCTAssertEqual(result.triggerEvents.count, 1)
        XCTAssertEqual(result.triggerEvents.first?.trigger.id, "coord_gate")
        XCTAssertEqual(result.triggerEvents.first?.trigger.localPosition, TilePosition(x: 2, y: 1))
        XCTAssertEqual(result.triggerEvents.first?.trigger.width, 2)
        XCTAssertEqual(result.triggerEvents.first?.trigger.height, 2)
    }

    func testIdleAndBlockedTicksDoNotEmitTriggerEvents() throws {
        let triggerTile = placement(id: "object_npc", kind: .object, x: 1, y: 1, scriptReference: "script:100")
        let map = try makeMap(
            placements: [triggerTile],
            blockedTiles: [NormalizedTileCoordinate(x: 1, y: 0)]
        )

        let idleResult = GameReducer.step(
            state: GameState(
                tick: 2,
                currentMapID: map.id,
                playerPosition: TilePosition(x: 1, y: 1)
            ),
            command: .idle,
            map: map
        )

        let blockedResult = GameReducer.step(
            state: GameState(
                tick: 2,
                currentMapID: map.id,
                playerPosition: TilePosition(x: 0, y: 0)
            ),
            command: .move(.right),
            map: map
        )

        XCTAssertEqual(idleResult.outcome, .idle)
        XCTAssertTrue(idleResult.triggerEvents.isEmpty)
        XCTAssertEqual(blockedResult.outcome, .blocked(.right))
        XCTAssertTrue(blockedResult.triggerEvents.isEmpty)
    }

    func testSameStepInputsProduceIdenticalTriggerBatches() throws {
        let map = try makeMap(
            placements: [
                placement(id: "object_npc", kind: .object, x: 1, y: 1, scriptReference: "script:100"),
                placement(id: "coord_gate", kind: .coordinateTrigger, x: 1, y: 1, width: 1, height: 2, scriptReference: "script:200"),
                placement(id: "bg_sign", kind: .backgroundEvent, x: 1, y: 1, scriptReference: "script:300")
            ]
        )
        let state = GameState(
            tick: 9,
            currentMapID: map.id,
            playerPosition: TilePosition(x: 0, y: 1)
        )

        let first = GameReducer.step(state: state, command: .move(.right), map: map)
        let second = GameReducer.step(state: state, command: .move(.right), map: map)

        XCTAssertEqual(first, second)
    }

    private func makeMap(
        width: Int = 6,
        height: Int = 6,
        placements: [HGSSManifest.Placement],
        blockedTiles: Set<NormalizedTileCoordinate> = []
    ) throws -> NormalizedPlayableMap {
        let manifest = HGSSManifest(
            schemaVersion: 2,
            title: "Test Manifest",
            build: "test",
            initialMapID: "MAP_TEST",
            initialEntryPointID: "ENTRY_TEST",
            maps: [
                HGSSManifest.MapEntry(
                    mapID: "MAP_TEST",
                    displayName: "Test Map",
                    provenance: HGSSManifest.MapProvenance(
                        upstreamMapID: "MAP_TEST_UPSTREAM",
                        mapHeaderSymbol: "sMapHeaders[MAP_TEST]",
                        matrixID: "TEST_MATRIX",
                        eventsBank: "TEST_EVENTS"
                    ),
                    header: HGSSManifest.MapHeaderMetadata(
                        wildEncounterBank: "TEST_ENCDATA",
                        areaDataBank: 0,
                        moveModelBank: 0,
                        worldMapX: 0,
                        worldMapY: 0,
                        mapSection: "MAPSEC_TEST",
                        mapType: "MAP_TYPE_TEST",
                        followMode: "MAP_FOLLOWMODE_ALLOW",
                        bikeAllowed: true,
                        flyAllowed: true,
                        isKanto: false,
                        weather: 0,
                        cameraType: 0
                    ),
                    layout: HGSSManifest.MapLayout(
                        width: width,
                        height: height,
                        sourceOrigin: HGSSManifest.SourcePoint(x: 0, z: 0, y: 0)
                    ),
                    collision: HGSSManifest.CollisionLayer(
                        impassableTiles: blockedTiles.map {
                            HGSSManifest.GridPoint(x: $0.x, y: $0.y)
                        }
                    ),
                    entryPoints: [
                        HGSSManifest.EntryPoint(
                            id: "ENTRY_TEST",
                            localPosition: HGSSManifest.GridPoint(x: 0, y: 0),
                            facing: nil,
                            summary: "Test entry point."
                        )
                    ],
                    warps: [],
                    placements: placements
                )
            ],
            pokemon: [],
            notes: "Reducer trigger detection tests."
        )

        let content = try NormalizedWorldContent(manifest: manifest)
        return try XCTUnwrap(content.map(id: "MAP_TEST"))
    }

    private func placement(
        id: String,
        kind: NormalizedPlacementKind,
        x: Int,
        y: Int,
        width: Int = 1,
        height: Int = 1,
        scriptReference: String?
    ) -> HGSSManifest.Placement {
        HGSSManifest.Placement(
            id: id,
            kind: HGSSManifest.PlacementKind(rawValue: kind.rawValue)!,
            localPosition: HGSSManifest.GridPoint(x: x, y: y),
            sourcePosition: HGSSManifest.SourcePoint(x: x, z: y, y: 0),
            width: width,
            height: height,
            scriptReference: scriptReference,
            summary: "Test placement \(id)."
        )
    }
}
