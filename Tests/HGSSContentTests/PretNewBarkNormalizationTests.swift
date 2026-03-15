import Foundation
import Testing
import HGSSContent
import HGSSDataModel

struct PretNewBarkNormalizationTests {
    @Test("Normalizes New Bark from pret fixtures plus local profile")
    func buildsManifestFromPretFixtures() throws {
        let repoRoot = repoRootURL()
        let profileRoot = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)
        let fixturesRoot = repoRoot.appendingPathComponent("Tests/Fixtures/PretNewBark", isDirectory: true)

        let loader = StubContentLoader()
        let profileManifest = try loader.loadManifest(from: profileRoot)
        let mapHeadersText = try String(
            contentsOf: fixturesRoot.appendingPathComponent("map_headers_new_bark.h", isDirectory: false),
            encoding: .utf8
        )
        let zoneEventData = try Data(contentsOf: fixturesRoot.appendingPathComponent("057_T20.json", isDirectory: false))

        let normalizer = PretNewBarkNormalizer()
        let manifest = try normalizer.buildManifest(
            from: profileManifest,
            mapHeadersText: mapHeadersText,
            zoneEventData: zoneEventData
        )
        let content = try NormalizedWorldContent(manifest: manifest)
        let map = try #require(content.map(id: "MAP_NEW_BARK"))

        #expect(manifest.schemaVersion == 2)
        #expect(content.maps.count == 3)
        #expect(map.provenance.eventsBank == "NARC_zone_event_057_T20_bin")
        #expect(map.provenance.matrixID == "NARC_map_matrix_map_matrix_0000_EVERYWHERE_bin")
        #expect(map.header.wildEncounterBank == "ENCDATA_T20")
        #expect(map.warps.count == 2)
        #expect(content.map(id: "MAP_NEW_BARK_ELMS_LAB_1F") != nil)
        #expect(content.map(id: "MAP_NEW_BARK_PLAYER_HOUSE_1F") != nil)
        #expect(map.placements.filter { $0.kind == .object }.count == 1)
        #expect(map.placements.filter { $0.kind == .coordinateTrigger }.count == 2)
        #expect(map.placements.filter { $0.kind == .backgroundEvent }.count == 2)
        #expect(map.placements.contains { $0.id == "obj_T20_gswoman1" })
        #expect(!map.placements.contains { $0.id == "obj_T20_doctor" })
        #expect(map.warpTiles.contains(NormalizedTileCoordinate(x: 19, y: 5)))
        #expect(map.placementTiles.contains(NormalizedTileCoordinate(x: 24, y: 11)))
        #expect(map.placementTiles.contains(NormalizedTileCoordinate(x: 0, y: 11)))
        #expect(content.initialEntryPoint.localPosition == NormalizedTileCoordinate(x: 1, y: 1))
    }

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
