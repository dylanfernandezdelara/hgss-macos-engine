import Foundation
import Testing
import HGSSCore

struct HGSSCoreSmokeTests {
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
        #expect(snapshot.tick == 1)
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
