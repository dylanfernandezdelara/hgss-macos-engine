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
        #expect(content.maps.count == 3)
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

    @Test("Includes first interior destination maps for the New Bark slice")
    func loadsInteriorDestinationMaps() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let loader = StubContentLoader()
        let content = try loader.loadPlayableContent(from: stubPath)
        let newBark = content.initialMap
        let newBarkDestinations = Set(newBark.warps.map(\.destinationMapID))

        #expect(newBarkDestinations == ["MAP_NEW_BARK_ELMS_LAB_1F", "MAP_NEW_BARK_PLAYER_HOUSE_1F"])

        let elmLab = try #require(content.map(id: "MAP_NEW_BARK_ELMS_LAB_1F"))
        let playerHouse = try #require(content.map(id: "MAP_NEW_BARK_PLAYER_HOUSE_1F"))
        let elmArrival = try #require(elmLab.entryPoint(id: "ENTRY_FROM_NEW_BARK"))
        let playerArrival = try #require(playerHouse.entryPoint(id: "ENTRY_FROM_NEW_BARK"))

        #expect(elmArrival.localPosition == NormalizedTileCoordinate(x: 2, y: 3))
        #expect(playerArrival.localPosition == NormalizedTileCoordinate(x: 2, y: 3))
        #expect(elmLab.warps.first?.destinationMapID == "MAP_NEW_BARK")
        #expect(playerHouse.warps.first?.destinationMapID == "MAP_NEW_BARK")
    }
}
