import Foundation
import HGSSContent
import HGSSDataModel
import XCTest

final class PretNewBarkNormalizationTests: XCTestCase {
    func testRegressesHeaderAndProvenance() throws {
        let manifest = try generatedManifest()
        let actualMap = try generatedMap(from: manifest)
        let expectedMap = try expectedGeneratedMap()

        XCTAssertEqual(manifest.schemaVersion, 2)
        XCTAssertEqual(manifest.title, "HGSS Normalized Stub Content")
        XCTAssertEqual(manifest.build, "0.2.0-normalized")
        XCTAssertEqual(manifest.initialMapID, expectedMap.mapID)
        XCTAssertEqual(manifest.initialEntryPointID, "ENTRY_BOOT_DEFAULT")
        XCTAssertEqual(manifest.maps.count, 1)
        XCTAssertEqual(actualMap.displayName, expectedMap.displayName)
        XCTAssertEqual(actualMap.layout, expectedMap.layout)
        XCTAssertEqual(actualMap.entryPoints, expectedMap.entryPoints)
        XCTAssertEqual(actualMap.provenance, expectedMap.provenance)
        XCTAssertEqual(actualMap.header, expectedMap.header)
    }

    func testRegressesWarpsAndPlacements() throws {
        let actualMap = try generatedMap()
        let expectedMap = try expectedGeneratedMap()

        XCTAssertEqual(actualMap.warps, expectedMap.warps)
        XCTAssertEqual(actualMap.placements, expectedMap.placements)
    }

    func testPreservesNormalizationInvariants() throws {
        let manifest = try generatedManifest()
        let content = try NormalizedWorldContent(manifest: manifest)
        let map = try XCTUnwrap(content.map(id: "MAP_NEW_BARK"))

        XCTAssertEqual(map.warpTiles, Set([
            NormalizedTileCoordinate(x: 8, y: 2),
            NormalizedTileCoordinate(x: 19, y: 5),
        ]))
        XCTAssertTrue(map.placementTiles.contains(NormalizedTileCoordinate(x: 0, y: 11)))
        XCTAssertTrue(map.placementTiles.contains(NormalizedTileCoordinate(x: 24, y: 11)))
        XCTAssertEqual(content.initialEntryPoint.localPosition, NormalizedTileCoordinate(x: 1, y: 1))

        for warp in map.warps {
            XCTAssertTrue(map.contains(warp.localPosition))
            XCTAssertEqual(warp.localPosition, normalizedTile(for: warp.sourcePosition, origin: map.sourceOrigin))
        }

        for placement in map.placements {
            XCTAssertTrue(map.contains(placement.localPosition))
            XCTAssertEqual(
                placement.localPosition,
                normalizedTile(for: placement.sourcePosition, origin: map.sourceOrigin)
            )
            for tile in placement.occupiedTiles {
                XCTAssertTrue(map.contains(tile))
            }
        }
    }

    private func generatedManifest() throws -> HGSSManifest {
        let loader = StubContentLoader()
        let profileManifest = try loader.loadManifest(from: repoRootURL().appendingPathComponent("DevContent/Stub", isDirectory: true))
        let normalizer = PretNewBarkNormalizer()

        return try normalizer.buildManifest(
            from: profileManifest,
            mapHeadersText: try String(
                contentsOf: fixturesRootURL().appendingPathComponent("map_headers_new_bark.h", isDirectory: false),
                encoding: .utf8
            ),
            zoneEventData: try Data(
                contentsOf: fixturesRootURL().appendingPathComponent("057_T20.json", isDirectory: false)
            )
        )
    }

    private func generatedMap(from manifest: HGSSManifest? = nil) throws -> HGSSManifest.MapEntry {
        let resolvedManifest: HGSSManifest
        if let manifest {
            resolvedManifest = manifest
        } else {
            resolvedManifest = try generatedManifest()
        }
        return try XCTUnwrap(resolvedManifest.maps.first(where: { $0.mapID == "MAP_NEW_BARK" }))
    }

    private func expectedGeneratedMap() throws -> HGSSManifest.MapEntry {
        try loadFixture(named: "generated_new_bark_map.json", as: HGSSManifest.MapEntry.self)
    }

    private func loadFixture<T: Decodable>(named fileName: String, as _: T.Type) throws -> T {
        let data = try Data(contentsOf: fixturesRootURL().appendingPathComponent(fileName, isDirectory: false))
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func fixturesRootURL() -> URL {
        repoRootURL().appendingPathComponent("Tests/Fixtures/PretNewBark", isDirectory: true)
    }

    private func normalizedTile(
        for sourcePosition: NormalizedSourceCoordinate,
        origin: NormalizedSourceCoordinate
    ) -> NormalizedTileCoordinate {
        NormalizedTileCoordinate(
            x: sourcePosition.x - origin.x,
            y: sourcePosition.z - origin.z
        )
    }

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
