import Foundation
import Testing
import HGSSContent
import HGSSDataModel

struct PretNewBarkNormalizationTests {
    @Test("Regresses generated manifest against committed contract")
    func regressesGeneratedManifestAgainstCommittedContract() throws {
        #expect(try generatedManifest() == expectedGeneratedManifest())
    }

    @Test("Regresses generated header and provenance")
    func regressesHeaderAndProvenance() throws {
        let manifest = try generatedManifest()
        let actualMap = try generatedMap(from: manifest)
        let expectedMap = try expectedGeneratedMap()

        #expect(manifest.schemaVersion == 2)
        #expect(manifest.title == "HGSS Normalized Stub Content")
        #expect(manifest.build == "0.2.0-normalized")
        #expect(manifest.initialMapID == expectedMap.mapID)
        #expect(manifest.initialEntryPointID == "ENTRY_BOOT_DEFAULT")
        #expect(manifest.maps.count == 1)
        #expect(actualMap.displayName == expectedMap.displayName)
        #expect(actualMap.layout == expectedMap.layout)
        #expect(actualMap.entryPoints == expectedMap.entryPoints)
        #expect(actualMap.provenance == expectedMap.provenance)
        #expect(actualMap.header == expectedMap.header)
    }

    @Test("Regresses generated warps and placements")
    func regressesWarpsAndPlacements() throws {
        let actualMap = try generatedMap()
        let expectedMap = try expectedGeneratedMap()

        #expect(actualMap.warps == expectedMap.warps)
        #expect(actualMap.placements == expectedMap.placements)
    }

    @Test("Preserves normalization invariants")
    func preservesNormalizationInvariants() throws {
        let manifest = try generatedManifest()
        let content = try NormalizedWorldContent(manifest: manifest)
        let map = try #require(content.map(id: "MAP_NEW_BARK"))

        #expect(map.warpTiles == Set([
            NormalizedTileCoordinate(x: 8, y: 2),
            NormalizedTileCoordinate(x: 19, y: 5),
        ]))
        #expect(map.placementTiles.contains(NormalizedTileCoordinate(x: 0, y: 11)))
        #expect(map.placementTiles.contains(NormalizedTileCoordinate(x: 24, y: 11)))
        #expect(content.initialEntryPoint.localPosition == NormalizedTileCoordinate(x: 1, y: 1))

        for warp in map.warps {
            #expect(map.contains(warp.localPosition))
            #expect(warp.localPosition == normalizedTile(for: warp.sourcePosition, origin: map.sourceOrigin))
        }

        for placement in map.placements {
            #expect(map.contains(placement.localPosition))
            #expect(placement.localPosition == normalizedTile(for: placement.sourcePosition, origin: map.sourceOrigin))
            for tile in placement.occupiedTiles {
                #expect(map.contains(tile))
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
        return try #require(resolvedManifest.maps.first(where: { $0.mapID == "MAP_NEW_BARK" }))
    }

    private func expectedGeneratedMap() throws -> HGSSManifest.MapEntry {
        try loadFixture(named: "generated_new_bark_map.json", as: HGSSManifest.MapEntry.self)
    }

    private func expectedGeneratedManifest() throws -> HGSSManifest {
        try loadFixture(named: "generated_new_bark_manifest.json", as: HGSSManifest.self)
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
