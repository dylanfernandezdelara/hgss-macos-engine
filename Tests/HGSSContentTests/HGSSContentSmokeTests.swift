import Foundation
import XCTest
import HGSSContent

final class HGSSContentSmokeTests: XCTestCase {
    func testLoadsStubManifest() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let loader = StubContentLoader()
        let content = try loader.loadPlayableContent(from: stubPath)
        let map = content.initialMap
        let entryPoint = try XCTUnwrap(map.entryPoint(id: content.initialEntryPointID))

        XCTAssertEqual(content.manifest.schemaVersion, 2)
        XCTAssertEqual(content.initialMapID, "MAP_NEW_BARK")
        XCTAssertEqual(map.width, 25)
        XCTAssertEqual(map.height, 18)
        XCTAssertEqual(entryPoint.localPosition, NormalizedTileCoordinate(x: 1, y: 1))
        XCTAssertEqual(map.provenance.eventsBank, "NARC_zone_event_057_T20_bin")
        XCTAssertEqual(map.header.mapSection, "MAPSEC_NEW_BARK_TOWN")
    }

    func testNormalizesUpstreamCoordinates() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let loader = StubContentLoader()
        let content = try loader.loadPlayableContent(from: stubPath)
        let map = content.initialMap
        let elmWarp = try XCTUnwrap(map.warps.first(where: { $0.id == "WARP_ELMS_LAB_1F" }))
        let eastExit = try XCTUnwrap(map.placements.first(where: { $0.id == "coord_T20_east_exit" }))

        XCTAssertEqual(elmWarp.localPosition, NormalizedTileCoordinate(x: 8, y: 2))
        XCTAssertEqual(elmWarp.sourcePosition.x, 684)
        XCTAssertEqual(elmWarp.sourcePosition.z, 393)
        XCTAssertEqual(eastExit.localPosition, NormalizedTileCoordinate(x: 24, y: 7))
        XCTAssertTrue(eastExit.occupiedTiles.contains(NormalizedTileCoordinate(x: 24, y: 11)))
        XCTAssertTrue(map.placementTiles.contains(NormalizedTileCoordinate(x: 6, y: 0)))
    }
}
