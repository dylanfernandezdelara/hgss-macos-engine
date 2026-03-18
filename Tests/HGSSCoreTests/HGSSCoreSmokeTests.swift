import Foundation
import Testing
import HGSSCore

struct HGSSCoreSmokeTests {
    @Test("Opening bootstrap loader falls back to no-save defaults")
    func openingBootstrapLoaderFallsBackToNoSaveDefaults() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let loaded = try HGSSOpeningBootstrapLoader().load(from: root)

        #expect(loaded == .noSave)
        #expect(loaded.programFlags()["main_menu_has_save_data"] == 0)
    }

    @Test("Opening bootstrap loader decodes explicit menu and save flags")
    func openingBootstrapLoaderDecodesExplicitFlags() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let expected = HGSSOpeningBootstrapState(
            checkSaveStatusFlags: 3,
            mainMenuHasSaveData: true,
            mainMenuHasPokedex: true,
            drawMysteryGift: true,
            drawRanger: false,
            drawConnectToWii: true,
            connectedAgbGame: 2
        )
        let data = try JSONEncoder().encode(expected)
        try data.write(to: root.appendingPathComponent("opening_bootstrap_state.json", isDirectory: false))

        let loaded = try HGSSOpeningBootstrapLoader().load(from: root)

        #expect(loaded == expected)
        #expect(loaded.programFlags()["check_save_status_flags"] == 3)
        #expect(loaded.programFlags()["main_menu_connected_agb_game"] == 2)
    }

    @Test("Boots runtime at declared entry point")
    func bootsCoreWithStubContent() async throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let runtime = try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubPath)
        let snapshot = await runtime.snapshot()

        #expect(snapshot.mapID == "MAP_NEW_BARK")
        #expect(snapshot.mapWidth == 25)
        #expect(snapshot.mapHeight == 18)
        #expect(snapshot.playerPosition == TilePosition(x: 1, y: 1))
        #expect(snapshot.playerFacing == .down)
        #expect(snapshot.entryPointTiles.contains(TilePosition(x: 1, y: 1)))
        #expect(snapshot.warpTiles.contains(TilePosition(x: 8, y: 2)))
        #expect(snapshot.placementTiles.contains(TilePosition(x: 24, y: 11)))
        await runtime.stop()
    }

    @Test("Moves into an open tile")
    func movesIntoOpenTile() async throws {
        let runtime = try await makeRuntime()
        await runtime.setHeldDirection(.right)
        let snapshot = await runtime.advanceOneTick()

        #expect(snapshot.playerPosition == TilePosition(x: 2, y: 1))
        #expect(snapshot.playerFacing == .right)
        #expect(snapshot.tick == 1)
        await runtime.stop()
    }

    @Test("Tick results expose typed trigger event contract")
    func exposesTickResultContract() async throws {
        let runtime = try await makeRuntime()
        let result = await runtime.sendStep(command: .move(.right))

        #expect(result.snapshot.playerPosition == TilePosition(x: 2, y: 1))
        #expect(result.outcome == .moved(.right))
        #expect(result.triggerEvents.isEmpty)
        await runtime.stop()
    }

    @Test("Blocked movement leaves player in place")
    func blocksMovementIntoObstacle() async throws {
        let runtime = try await makeRuntime()
        await runtime.setHeldDirection(.right)
        _ = await runtime.advanceOneTick()
        await runtime.setHeldDirection(.right)
        let snapshot = await runtime.advanceOneTick()

        #expect(snapshot.playerPosition == TilePosition(x: 2, y: 1))
        #expect(snapshot.playerFacing == .right)
        #expect(snapshot.tick == 2)
        let counters = await runtime.telemetryCounters()
        #expect(counters["movement.blocked"] == 1)
        await runtime.stop()
    }

    @Test("Out-of-bounds movement is blocked")
    func blocksMovementOutOfBounds() async throws {
        let runtime = try await makeRuntime()
        await runtime.setHeldDirection(.left)
        _ = await runtime.advanceOneTick()
        await runtime.setHeldDirection(.left)
        let snapshot = await runtime.advanceOneTick()

        #expect(snapshot.playerPosition == TilePosition(x: 0, y: 1))
        #expect(snapshot.tick == 2)
        await runtime.stop()
    }

    @Test("Snapshot reads current state without advancing a tick")
    func snapshotDoesNotMutateState() async throws {
        let runtime = try await makeRuntime()
        let initial = await runtime.snapshot()

        await runtime.setHeldDirection(.right)
        let afterInput = await runtime.snapshot()

        #expect(afterInput == initial)
        #expect(afterInput.tick == 0)
        #expect(afterInput.playerPosition == TilePosition(x: 1, y: 1))
        await runtime.stop()
    }

    @Test("Held direction only affects future tick advances")
    func heldDirectionAffectsFutureTicksOnly() async throws {
        let runtime = try await makeRuntime()

        await runtime.setHeldDirection(.right)
        let beforeAdvance = await runtime.snapshot()
        #expect(beforeAdvance.tick == 0)
        #expect(beforeAdvance.playerPosition == TilePosition(x: 1, y: 1))

        let moved = await runtime.advanceOneTick()
        #expect(moved.tick == 1)
        #expect(moved.playerPosition == TilePosition(x: 2, y: 1))

        await runtime.setHeldDirection(nil)
        let idleTick = await runtime.advanceOneTick()
        #expect(idleTick.tick == 2)
        #expect(idleTick.playerPosition == TilePosition(x: 2, y: 1))
        await runtime.stop()
    }

    @Test("Same command sequence yields same final state")
    func deterministicSequence() async throws {
        let first = try await runSequence([.right, .down, .down, .left, .up, nil])
        let second = try await runSequence([.right, .down, .down, .left, .up, nil])

        #expect(first == second)
    }

    @Test("TriggerEvent schema carries map context and trigger identity")
    func triggerEventSchema() {
        let event = TriggerEvent(
            tick: 7,
            playerPosition: TilePosition(x: 24, y: 9),
            map: TriggerEvent.MapContext(
                mapID: "MAP_NEW_BARK",
                mapName: "New Bark Town (Excerpt)",
                upstreamMapID: "MAP_NEW_BARK",
                eventsBank: "NARC_zone_event_057_T20_bin"
            ),
            trigger: TriggerEvent.Identity(
                id: "coord_T20_east_exit",
                kind: .coordinateTrigger,
                localPosition: TilePosition(x: 24, y: 7),
                width: 1,
                height: 5,
                scriptReference: "script:20002"
            )
        )

        #expect(event.tick == 7)
        #expect(event.map.mapID == "MAP_NEW_BARK")
        #expect(event.map.eventsBank == "NARC_zone_event_057_T20_bin")
        #expect(event.trigger.id == "coord_T20_east_exit")
        #expect(event.trigger.kind == .coordinateTrigger)
        #expect(event.trigger.height == 5)
        #expect(event.trigger.scriptReference == "script:20002")
    }

    private func makeRuntime() async throws -> HGSSCoreRuntime {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        return try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubPath)
    }

    private func runSequence(_ directions: [MovementDirection?]) async throws -> CoreSnapshot {
        let runtime = try await makeRuntime()
        var lastSnapshot = await runtime.snapshot()

        for direction in directions {
            await runtime.setHeldDirection(direction)
            lastSnapshot = await runtime.advanceOneTick()
        }

        await runtime.stop()
        return lastSnapshot
    }
}
