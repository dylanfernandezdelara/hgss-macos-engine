import Foundation
import XCTest
import HGSSCore

final class HGSSCoreSmokeTests: XCTestCase {
    func testBootsCoreWithStubContent() async throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let runtime = try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubPath)
        let snapshot = await runtime.snapshot()

        XCTAssertEqual(snapshot.mapID, "MAP_NEW_BARK")
        XCTAssertEqual(snapshot.mapWidth, 25)
        XCTAssertEqual(snapshot.mapHeight, 18)
        XCTAssertEqual(snapshot.playerPosition, TilePosition(x: 1, y: 1))
        XCTAssertTrue(snapshot.warpTiles.contains(TilePosition(x: 8, y: 2)))
        XCTAssertTrue(snapshot.placementTiles.contains(TilePosition(x: 24, y: 11)))
        await runtime.stop()
    }

    func testMovesIntoOpenTile() async throws {
        let runtime = try await makeRuntime()
        await runtime.setHeldDirection(.right)
        let snapshot = await runtime.advanceOneTick()

        XCTAssertEqual(snapshot.playerPosition, TilePosition(x: 2, y: 1))
        XCTAssertEqual(snapshot.tick, 1)
        await runtime.stop()
    }

    func testTickResultsExposeTypedTriggerEventContract() async throws {
        let runtime = try await makeRuntime()
        let result = await runtime.sendStep(command: .move(.right))

        XCTAssertEqual(result.snapshot.playerPosition, TilePosition(x: 2, y: 1))
        XCTAssertEqual(result.outcome, .moved(.right))
        XCTAssertTrue(result.triggerEvents.isEmpty)
        await runtime.stop()
    }

    func testBlockedMovementLeavesPlayerInPlace() async throws {
        let runtime = try await makeRuntime()
        await runtime.setHeldDirection(.right)
        _ = await runtime.advanceOneTick()
        await runtime.setHeldDirection(.right)
        let snapshot = await runtime.advanceOneTick()

        XCTAssertEqual(snapshot.playerPosition, TilePosition(x: 2, y: 1))
        XCTAssertEqual(snapshot.tick, 2)
        let counters = await runtime.telemetryCounters()
        XCTAssertEqual(counters["movement.blocked"], 1)
        await runtime.stop()
    }

    func testOutOfBoundsMovementIsBlocked() async throws {
        let runtime = try await makeRuntime()
        await runtime.setHeldDirection(.left)
        _ = await runtime.advanceOneTick()
        await runtime.setHeldDirection(.left)
        let snapshot = await runtime.advanceOneTick()

        XCTAssertEqual(snapshot.playerPosition, TilePosition(x: 0, y: 1))
        XCTAssertEqual(snapshot.tick, 2)
        await runtime.stop()
    }

    func testSameCommandSequenceYieldsSameFinalState() async throws {
        let first = try await runSequence([.right, .down, .down, .left, .up, nil])
        let second = try await runSequence([.right, .down, .down, .left, .up, nil])

        XCTAssertEqual(first, second)
    }

    func testTriggerEventSchemaCarriesMapContextAndTriggerIdentity() {
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

        XCTAssertEqual(event.tick, 7)
        XCTAssertEqual(event.map.mapID, "MAP_NEW_BARK")
        XCTAssertEqual(event.map.eventsBank, "NARC_zone_event_057_T20_bin")
        XCTAssertEqual(event.trigger.id, "coord_T20_east_exit")
        XCTAssertEqual(event.trigger.kind, .coordinateTrigger)
        XCTAssertEqual(event.trigger.height, 5)
        XCTAssertEqual(event.trigger.scriptReference, "script:20002")
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
