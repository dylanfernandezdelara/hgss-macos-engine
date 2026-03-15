import Foundation
import Testing
import HGSSCore
import HGSSContent
import HGSSDataModel

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

    @Test("Extracted collision blocks movement without runtime API changes")
    func blocksMovementFromExtractedCollisionManifest() async throws {
        let (runtime, tempRoot) = try await makeRuntimeWithExtractedCollision(
            blockedTiles: [
                PretExtractedCollisionInput.BlockedTile(
                    sourcePosition: HGSSManifest.SourcePoint(x: 678, z: 392, y: 0)
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        await runtime.setHeldDirection(.right)
        let snapshot = await runtime.advanceOneTick()

        #expect(snapshot.playerPosition == TilePosition(x: 1, y: 1))
        #expect(snapshot.tick == 1)
        #expect(snapshot.blockedTiles.contains(TilePosition(x: 2, y: 1)))
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

    @Test("Same command sequence yields same final state")
    func deterministicSequence() async throws {
        let first = try await runSequence([.right, .down, .down, .left, .up, nil])
        let second = try await runSequence([.right, .down, .down, .left, .up, nil])

        #expect(first == second)
    }

    private func makeRuntime() async throws -> HGSSCoreRuntime {
        try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubRootURL())
    }

    private func makeRuntimeWithExtractedCollision(
        blockedTiles: [PretExtractedCollisionInput.BlockedTile]
    ) async throws -> (runtime: HGSSCoreRuntime, tempRoot: URL) {
        let fixtures = try loadPretFixtures()
        let manifest = try PretNewBarkNormalizer().buildManifest(
            from: fixtures.profileManifest,
            mapHeadersText: fixtures.mapHeadersText,
            zoneEventData: fixtures.zoneEventData,
            extractedCollision: PretExtractedCollisionInput(blockedTiles: blockedTiles)
        )

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: tempRoot.appendingPathComponent("manifest.json", isDirectory: false))

        return (try await HGSSCoreRuntime.bootWithStubContent(stubRoot: tempRoot), tempRoot)
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

    private func stubRootURL() -> URL {
        repoRootURL().appendingPathComponent("DevContent/Stub", isDirectory: true)
    }

    private func loadPretFixtures() throws -> (profileManifest: HGSSManifest, mapHeadersText: String, zoneEventData: Data) {
        let loader = StubContentLoader()
        let fixturesRoot = repoRootURL().appendingPathComponent("Tests/Fixtures/PretNewBark", isDirectory: true)
        let profileManifest = try loader.loadManifest(from: stubRootURL())
        let mapHeadersText = try String(
            contentsOf: fixturesRoot.appendingPathComponent("map_headers_new_bark.h", isDirectory: false),
            encoding: .utf8
        )
        let zoneEventData = try Data(contentsOf: fixturesRoot.appendingPathComponent("057_T20.json", isDirectory: false))

        return (profileManifest, mapHeadersText, zoneEventData)
    }
}
