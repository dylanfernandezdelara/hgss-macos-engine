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

    func testBootsCoreWithGeneratedManifest() async throws {
        let repoRoot = repoRootURL()
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        try FileManager.default.copyItem(
            at: repoRoot.appendingPathComponent(
                "Tests/Fixtures/PretNewBark/generated_new_bark_manifest.json",
                isDirectory: false
            ),
            to: tempRoot.appendingPathComponent("manifest.json", isDirectory: false)
        )

        let runtime = try await HGSSCoreRuntime.bootWithStubContent(stubRoot: tempRoot)
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

    func testBlocksMovementIntoObstacle() async throws {
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

    func testBlocksMovementOutOfBounds() async throws {
        let runtime = try await makeRuntime()
        await runtime.setHeldDirection(.left)
        _ = await runtime.advanceOneTick()
        await runtime.setHeldDirection(.left)
        let snapshot = await runtime.advanceOneTick()

        XCTAssertEqual(snapshot.playerPosition, TilePosition(x: 0, y: 1))
        XCTAssertEqual(snapshot.tick, 2)
        await runtime.stop()
    }

    func testDeterministicSequence() async throws {
        let first = try await runSequence([.right, .down, .down, .left, .up, nil])
        let second = try await runSequence([.right, .down, .down, .left, .up, nil])

        XCTAssertEqual(first, second)
    }

    private func makeRuntime() async throws -> HGSSCoreRuntime {
        let stubPath = repoRootURL().appendingPathComponent("DevContent/Stub", isDirectory: true)

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

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
