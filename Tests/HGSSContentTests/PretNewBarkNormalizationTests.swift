import Foundation
import Testing
import HGSSContent
import HGSSDataModel

struct PretNewBarkNormalizationTests {
    @Test("Normalizes New Bark from pret fixtures plus local profile")
    func buildsManifestFromPretFixtures() throws {
        let fixtures = try loadFixtures()
        let normalizer = PretNewBarkNormalizer()
        let manifest = try normalizer.buildManifest(
            from: fixtures.profileManifest,
            mapHeadersText: fixtures.mapHeadersText,
            zoneEventData: fixtures.zoneEventData
        )
        let content = try NormalizedWorldContent(manifest: manifest)
        let map = try #require(content.map(id: "MAP_NEW_BARK"))

        #expect(manifest.schemaVersion == 2)
        #expect(map.provenance.eventsBank == "NARC_zone_event_057_T20_bin")
        #expect(map.provenance.matrixID == "NARC_map_matrix_map_matrix_0000_EVERYWHERE_bin")
        #expect(map.header.wildEncounterBank == "ENCDATA_T20")
        #expect(map.warps.count == 2)
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

    @Test("Falls back to checked-in profile collision when extracted collision is absent")
    func fallsBackToProfileCollision() throws {
        let fixtures = try loadFixtures()
        let normalizer = PretNewBarkNormalizer()
        let manifest = try normalizer.buildManifest(
            from: fixtures.profileManifest,
            mapHeadersText: fixtures.mapHeadersText,
            zoneEventData: fixtures.zoneEventData
        )

        let profileMap = try #require(fixtures.profileManifest.maps.first(where: { $0.mapID == "MAP_NEW_BARK" }))
        let manifestMap = try #require(manifest.maps.first(where: { $0.mapID == "MAP_NEW_BARK" }))

        #expect(manifestMap.collision == profileMap.collision)
    }

    @Test("Normalizes extracted collision into local impassable tiles")
    func normalizesExtractedCollision() throws {
        let fixtures = try loadFixtures()
        let normalizer = PretNewBarkNormalizer()
        let manifest = try normalizer.buildManifest(
            from: fixtures.profileManifest,
            mapHeadersText: fixtures.mapHeadersText,
            zoneEventData: fixtures.zoneEventData,
            extractedCollision: PretExtractedCollisionInput(
                blockedTiles: [
                    makeBlockedTile(x: 681, z: 394, y: 0),
                    makeBlockedTile(x: 676, z: 391, y: 0),
                    makeBlockedTile(x: 677, z: 392, y: 0),
                    makeBlockedTile(x: 677, z: 392, y: 0)
                ]
            )
        )

        let map = try #require(manifest.maps.first(where: { $0.mapID == "MAP_NEW_BARK" }))
        #expect(
            map.collision.impassableTiles == [
                HGSSManifest.GridPoint(x: 0, y: 0),
                HGSSManifest.GridPoint(x: 1, y: 1),
                HGSSManifest.GridPoint(x: 5, y: 3)
            ]
        )
    }

    @Test("Rejects out-of-bounds extracted collision deterministically")
    func rejectsOutOfBoundsExtractedCollision() throws {
        let fixtures = try loadFixtures()
        let normalizer = PretNewBarkNormalizer()

        do {
            _ = try normalizer.buildManifest(
                from: fixtures.profileManifest,
                mapHeadersText: fixtures.mapHeadersText,
                zoneEventData: fixtures.zoneEventData,
                extractedCollision: PretExtractedCollisionInput(
                    blockedTiles: [makeBlockedTile(x: 701, z: 391, y: 0)]
                )
            )
            Issue.record("Expected out-of-bounds extracted collision to fail normalization.")
        } catch let error as PretNormalizationError {
            switch error {
            case let .invalidCollisionSourceTile(mapID, x, z, y):
                #expect(mapID == "MAP_NEW_BARK")
                #expect(x == 701)
                #expect(z == 391)
                #expect(y == 0)
            default:
                Issue.record("Unexpected normalization error: \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

    @Test("Rejects extracted collision on a different source plane")
    func rejectsExtractedCollisionOnDifferentPlane() throws {
        let fixtures = try loadFixtures()
        let normalizer = PretNewBarkNormalizer()

        do {
            _ = try normalizer.buildManifest(
                from: fixtures.profileManifest,
                mapHeadersText: fixtures.mapHeadersText,
                zoneEventData: fixtures.zoneEventData,
                extractedCollision: PretExtractedCollisionInput(
                    blockedTiles: [makeBlockedTile(x: 676, z: 391, y: 1)]
                )
            )
            Issue.record("Expected mismatched source plane to fail normalization.")
        } catch let error as PretNormalizationError {
            switch error {
            case let .invalidCollisionSourcePlane(mapID, expectedY, actualY):
                #expect(mapID == "MAP_NEW_BARK")
                #expect(expectedY == 0)
                #expect(actualY == 1)
            default:
                Issue.record("Unexpected normalization error: \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

    @Test("Extracts pret collision from matrix and model inputs")
    func extractsPretCollisionInput() throws {
        let extractor = PretNewBarkCollisionExtractor()
        let layout = HGSSManifest.MapLayout(
            width: 3,
            height: 3,
            sourceOrigin: HGSSManifest.SourcePoint(x: 65, z: 34, y: 0)
        )

        let mapMatrixData = makeMapMatrixData(
            width: 3,
            height: 2,
            models: [0, 0, 0, 0, 0, 1]
        )
        let modelArchiveData = makeNARCData(
            members: [
                makeCollisionModelData(),
                makeCollisionModelData(words: [
                    (1, 2, 0x8000),
                    (3, 3, 0x8006),
                    (2, 4, 0x0600)
                ])
            ]
        )

        let input = try extractor.extractCollisionInput(
            layout: layout,
            mapMatrixData: mapMatrixData,
            modelArchiveData: modelArchiveData
        )

        #expect(
            input.blockedTiles.map(\.sourcePosition) == [
                HGSSManifest.SourcePoint(x: 65, z: 34, y: 0),
                HGSSManifest.SourcePoint(x: 67, z: 35, y: 0)
            ]
        )
    }

    @Test("Rejects excerpts that cross a 32x32 pret collision model boundary")
    func rejectsExcerptCrossingCollisionModelBoundary() throws {
        let extractor = PretNewBarkCollisionExtractor()
        let layout = HGSSManifest.MapLayout(
            width: 2,
            height: 1,
            sourceOrigin: HGSSManifest.SourcePoint(x: 31, z: 0, y: 0)
        )
        let mapMatrixData = makeMapMatrixData(width: 1, height: 1, models: [0])
        let modelArchiveData = makeNARCData(members: [makeCollisionModelData()])

        do {
            _ = try extractor.extractCollisionInput(
                layout: layout,
                mapMatrixData: mapMatrixData,
                modelArchiveData: modelArchiveData
            )
            Issue.record("Expected excerpt crossing the model boundary to fail collision extraction.")
        } catch let error as PretNormalizationError {
            switch error {
            case let .excerptCrossesCollisionModelBoundary(mapID, sourceX, sourceZ, width, height):
                #expect(mapID == "MAP_NEW_BARK")
                #expect(sourceX == 31)
                #expect(sourceZ == 0)
                #expect(width == 2)
                #expect(height == 1)
            default:
                Issue.record("Unexpected normalization error: \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
        }
    }

    @Test("Pret-backed manifests replace stand-in collision notes")
    func updatesNotesWhenCollisionIsExtracted() throws {
        let fixtures = try loadFixtures()
        let manifest = try PretNewBarkNormalizer().buildManifest(
            from: fixtures.profileManifest,
            mapHeadersText: fixtures.mapHeadersText,
            zoneEventData: fixtures.zoneEventData,
            extractedCollision: PretExtractedCollisionInput(
                blockedTiles: [makeBlockedTile(x: 676, z: 391, y: 0)]
            )
        )

        #expect(!manifest.notes.localizedCaseInsensitiveContains("stand-in"))
        #expect(manifest.notes.contains("pret/pokeheartgold"))
    }

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadFixtures() throws -> (profileManifest: HGSSManifest, mapHeadersText: String, zoneEventData: Data) {
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

        return (profileManifest, mapHeadersText, zoneEventData)
    }

    private func makeBlockedTile(x: Int, z: Int, y: Int) -> PretExtractedCollisionInput.BlockedTile {
        PretExtractedCollisionInput.BlockedTile(
            sourcePosition: HGSSManifest.SourcePoint(x: x, z: z, y: y)
        )
    }

    private func makeMapMatrixData(width: Int, height: Int, models: [UInt16], name: String = "TEST") -> Data {
        precondition(models.count == width * height)

        var data = Data()
        data.append(UInt8(width))
        data.append(UInt8(height))
        data.append(0)
        data.append(0)
        data.append(UInt8(name.utf8.count))
        data.append(contentsOf: name.utf8)

        for model in models {
            appendLE16(model, to: &data)
        }

        return data
    }

    private func makeCollisionModelData(words: [(Int, Int, UInt16)] = []) -> Data {
        let size = 32
        var permissionWords = Array(repeating: UInt16(0), count: size * size)

        for (mapX, mapZ, word) in words {
            precondition(mapX >= 0 && mapX < size)
            precondition(mapZ >= 0 && mapZ < size)

            let storedRow = (size - 1) - mapZ
            permissionWords[(storedRow * size) + mapX] = word
        }

        var data = Data()
        appendLE32(0x00000800, to: &data)
        appendLE32(0, to: &data)
        appendLE32(0, to: &data)
        appendLE32(0, to: &data)
        appendLE32(0, to: &data)

        for word in permissionWords {
            appendLE16(word, to: &data)
        }

        return data
    }

    private func makeNARCData(members: [Data]) -> Data {
        var btafPayload = Data()
        appendLE16(UInt16(members.count), to: &btafPayload)
        appendLE16(0, to: &btafPayload)

        var cursor = 0
        var gmifPayload = Data()
        for member in members {
            appendLE32(UInt32(cursor), to: &btafPayload)
            cursor += member.count
            appendLE32(UInt32(cursor), to: &btafPayload)
            gmifPayload.append(member)
        }

        let btaf = makeNARCChunk(magic: "BTAF", payload: btafPayload)
        let btnf = makeNARCChunk(
            magic: "BTNF",
            payload: Data([0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00])
        )
        let gmif = makeNARCChunk(magic: "GMIF", payload: gmifPayload)

        var data = Data()
        data.append(contentsOf: [0x4E, 0x41, 0x52, 0x43])
        data.append(contentsOf: [0xFE, 0xFF, 0x00, 0x01])
        appendLE32(UInt32(16 + btaf.count + btnf.count + gmif.count), to: &data)
        appendLE16(16, to: &data)
        appendLE16(3, to: &data)
        data.append(btaf)
        data.append(btnf)
        data.append(gmif)
        return data
    }

    private func makeNARCChunk(magic: String, payload: Data) -> Data {
        var data = Data()
        data.append(contentsOf: magic.utf8)
        appendLE32(UInt32(8 + payload.count), to: &data)
        data.append(payload)
        return data
    }

    private func appendLE16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private func appendLE32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
