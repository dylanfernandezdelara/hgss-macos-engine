import Foundation
import Testing
import HGSSContent

struct HGSSContentSmokeTests {
    @Test("Loads normalized New Bark fixture and entry point")
    func loadsStubManifest() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let loader = StubContentLoader()
        let content = try loader.loadPlayableContent(from: stubPath)
        let map = content.initialMap
        let entryPoint = try #require(map.entryPoint(id: content.initialEntryPointID))

        #expect(content.manifest.schemaVersion == 2)
        #expect(content.initialMapID == "MAP_NEW_BARK")
        #expect(map.width == 25)
        #expect(map.height == 18)
        #expect(entryPoint.localPosition == NormalizedTileCoordinate(x: 1, y: 1))
        #expect(map.provenance.eventsBank == "NARC_zone_event_057_T20_bin")
        #expect(map.header.mapSection == "MAPSEC_NEW_BARK_TOWN")
    }

    @Test("Preserves normalized warp and placement coordinates")
    func normalizesUpstreamCoordinates() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let loader = StubContentLoader()
        let content = try loader.loadPlayableContent(from: stubPath)
        let map = content.initialMap
        let elmWarp = try #require(map.warps.first(where: { $0.id == "WARP_ELMS_LAB_1F" }))
        let eastExit = try #require(map.placements.first(where: { $0.id == "coord_T20_east_exit" }))

        #expect(elmWarp.localPosition == NormalizedTileCoordinate(x: 8, y: 2))
        #expect(elmWarp.sourcePosition.x == 684)
        #expect(elmWarp.sourcePosition.z == 393)
        #expect(eastExit.localPosition == NormalizedTileCoordinate(x: 24, y: 7))
        #expect(eastExit.occupiedTiles.contains(NormalizedTileCoordinate(x: 24, y: 11)))
        #expect(map.placementTiles.contains(NormalizedTileCoordinate(x: 6, y: 0)))
    }
}
