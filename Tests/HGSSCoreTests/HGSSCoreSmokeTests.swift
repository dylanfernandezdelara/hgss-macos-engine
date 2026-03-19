import Foundation
import Testing
import HGSSCore

struct HGSSCoreSmokeTests {
    @Test("Opening bootstrap loader falls back to no-save defaults")
    func openingBootstrapLoaderFallsBackToNoSaveDefaults() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let loaded = try HGSSOpeningBootstrapLoader().load(from: root)

        #expect(loaded == .noSave)
        #expect(loaded.programFlags()["main_menu_has_save_data"] == 0)
    }

    @Test("Opening bootstrap loader decodes explicit menu and save flags")
    func openingBootstrapLoaderDecodesExplicitFlags() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let expected = HGSSOpeningBootstrapState(
            checkSaveStatusFlags: 3,
            mainMenuHasSaveData: true,
            mainMenuHasPokedex: true,
            drawMysteryGift: true,
            drawRanger: false,
            drawConnectToWii: true,
            connectedAgbGame: 2
        )
        let data = try JSONEncoder().encode(expected)
        try data.write(to: root.appendingPathComponent("opening_bootstrap_state.json", isDirectory: false))

        let loaded = try HGSSOpeningBootstrapLoader().load(from: root)

        #expect(loaded == expected)
        #expect(loaded.programFlags()["check_save_status_flags"] == 3)
        #expect(loaded.programFlags()["main_menu_connected_agb_game"] == 2)
    }

    @Test("Opening bootstrap loader prefers typed save summary input when present")
    func openingBootstrapLoaderPrefersTypedSaveSummary() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bootstrap = HGSSOpeningBootstrapState(
            checkSaveStatusFlags: 0,
            mainMenuHasSaveData: false,
            mainMenuHasPokedex: false,
            drawMysteryGift: false,
            drawRanger: false,
            drawConnectToWii: false,
            connectedAgbGame: 0
        )
        try JSONEncoder().encode(bootstrap).write(
            to: root.appendingPathComponent(HGSSOpeningBootstrapLoader.bootstrapFilename, isDirectory: false)
        )

        let summary = HGSSOpeningSaveSummary(
            hasUsableSaveData: true,
            mainSaveStatus: .valid,
            battleHallStatus: .absent,
            battleVideoStatus: .absent,
            hasPokedex: true,
            mysteryGiftEnabled: true,
            rangerEnabled: false,
            connectToWiiEnabled: true,
            connectedAGBGame: .emerald
        )
        try JSONEncoder().encode(summary).write(
            to: root.appendingPathComponent(HGSSOpeningBootstrapLoader.saveSummaryFilename, isDirectory: false)
        )

        let loaded = try HGSSOpeningBootstrapLoader().load(from: root)

        #expect(loaded == HGSSOpeningBootstrapState(saveSummary: summary))
        #expect(loaded.programFlags()["main_menu_has_save_data"] == 1)
        #expect(loaded.programFlags()["main_menu_connected_agb_game"] == 5)
    }

    @Test("Opening bootstrap loader prefers a real local save snapshot over JSON bootstrap fallbacks")
    func openingBootstrapLoaderPrefersLocalSaveSnapshot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bootstrap = HGSSOpeningBootstrapState.noSave
        try JSONEncoder().encode(bootstrap).write(
            to: root.appendingPathComponent(HGSSOpeningBootstrapLoader.bootstrapFilename, isDirectory: false)
        )

        let summary = HGSSOpeningSaveSummary.noSave
        try JSONEncoder().encode(summary).write(
            to: root.appendingPathComponent(HGSSOpeningBootstrapLoader.saveSummaryFilename, isDirectory: false)
        )

        let featureFlags = HGSSOpeningFeatureAvailability(
            mysteryGiftEnabled: nil,
            rangerEnabled: true,
            connectToWiiEnabled: true,
            connectedAGBGame: .emerald
        )
        try JSONEncoder().encode(featureFlags).write(
            to: root.appendingPathComponent(HGSSOpeningLocalSaveSummaryLoader.featureAvailabilityFilename, isDirectory: false)
        )

        let saveData = makeOpeningRawSave(
            primaryMirror: .init(
                saveNumber: 14,
                hasPokedex: true,
                hasNationalDex: true,
                mysteryGiftReceived: false,
                mysteryGiftSystemActive: true
            ),
            secondaryMirror: nil
        )
        try saveData.write(
            to: root.appendingPathComponent(HGSSOpeningLocalSaveSummaryLoader.localSaveFilenames[0], isDirectory: false)
        )

        let loaded = try HGSSOpeningBootstrapLoader().load(from: root)

        #expect(loaded.checkSaveStatus == [.saveCorrupted])
        #expect(loaded.mainMenuAvailability.hasSaveData)
        #expect(loaded.mainMenuAvailability.hasPokedex)
        #expect(loaded.mainMenuAvailability.drawMysteryGift)
        #expect(loaded.mainMenuAvailability.drawRanger)
        #expect(loaded.mainMenuAvailability.drawConnectToWii)
        #expect(loaded.mainMenuAvailability.connectedAGBGame == .emerald)
    }

    @Test("Local save summary loader decodes supported raw save containers")
    func localSaveSummaryLoaderDecodesRawSaveContainers() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let featureFlags = HGSSOpeningFeatureAvailability(
            mysteryGiftEnabled: false,
            rangerEnabled: false,
            connectToWiiEnabled: true,
            connectedAGBGame: .ruby
        )
        try JSONEncoder().encode(featureFlags).write(
            to: root.appendingPathComponent(HGSSOpeningLocalSaveSummaryLoader.featureAvailabilityFilename, isDirectory: false)
        )

        let rawSave = makeOpeningRawSave(
            primaryMirror: .init(
                saveNumber: 7,
                hasPokedex: true,
                hasNationalDex: false,
                mysteryGiftReceived: true,
                mysteryGiftSystemActive: false
            ),
            secondaryMirror: .init(
                saveNumber: 6,
                hasPokedex: true,
                hasNationalDex: false,
                mysteryGiftReceived: true,
                mysteryGiftSystemActive: false
            )
        )
        let container = rawSave + Data("DESMUME".utf8)
        try container.write(
            to: root.appendingPathComponent("opening_savedata.dsv", isDirectory: false)
        )

        let summary = try HGSSOpeningLocalSaveSummaryLoader().load(from: root)
        let loadedSummary = try #require(summary)

        #expect(loadedSummary.hasUsableSaveData)
        #expect(loadedSummary.mainSaveStatus == .valid)
        #expect(loadedSummary.battleHallStatus == .absent)
        #expect(loadedSummary.battleVideoStatus == .absent)
        #expect(loadedSummary.hasPokedex)
        #expect(loadedSummary.mysteryGiftEnabled)
        #expect(loadedSummary.connectToWiiEnabled)
        #expect(loadedSummary.connectedAGBGame == .none)
    }

    @Test("Local save summary loader decodes frontier extra save chunk corruption and erasure")
    func localSaveSummaryLoaderDecodesFrontierStatuses() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-bootstrap-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let rawSave = makeOpeningRawSave(
            primaryMirror: .init(
                saveNumber: 12,
                hasPokedex: true,
                hasNationalDex: false,
                mysteryGiftReceived: false,
                mysteryGiftSystemActive: false,
                frontierMetadataByChunkID: [
                    1: .init(currentToken: 0x0102_0304, previousToken: 0xFFFF_FFFF, activeSlot: 1),
                    2: .init(currentToken: 0x1112_1314, previousToken: 0xFFFF_FFFF, activeSlot: 0),
                ],
                frontierChunkCopiesByChunkID: [
                    1: .init(token: 0x0102_0304),
                ]
            ),
            secondaryMirror: nil
        )
        try rawSave.write(
            to: root.appendingPathComponent(HGSSOpeningLocalSaveSummaryLoader.localSaveFilenames[0], isDirectory: false)
        )

        let summary = try HGSSOpeningLocalSaveSummaryLoader().load(from: root)
        let loadedSummary = try #require(summary)

        #expect(loadedSummary.mainSaveStatus == .corrupted)
        #expect(loadedSummary.battleHallStatus == .corrupted)
        #expect(loadedSummary.battleVideoStatus == .erased)
        #expect(loadedSummary.checkSaveStatus == [.saveCorrupted, .battleHallCorrupted, .battleVideoErased])
    }

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
        #expect(snapshot.playerFacing == .down)
        #expect(snapshot.entryPointTiles.contains(TilePosition(x: 1, y: 1)))
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
        #expect(snapshot.playerFacing == .right)
        #expect(snapshot.tick == 1)
        await runtime.stop()
    }

    @Test("Tick results expose typed trigger event contract")
    func exposesTickResultContract() async throws {
        let runtime = try await makeRuntime()
        let result = await runtime.sendStep(command: .move(.right))

        #expect(result.snapshot.playerPosition == TilePosition(x: 2, y: 1))
        #expect(result.outcome == .moved(.right))
        #expect(result.triggerEvents.isEmpty)
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
        #expect(snapshot.playerFacing == .right)
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

    @Test("TriggerEvent schema carries map context and trigger identity")
    func triggerEventSchema() {
        let event = TriggerEvent(
            tick: 7,
            playerPosition: TilePosition(x: 24, y: 9),
            map: TriggerEvent.MapContext(
                mapID: "MAP_NEW_BARK",
                mapName: "New Bark Town (Excerpt)",
                upstreamMapID: "MAP_NEW_BARK",
                eventsBank: "NARC_zone_event_057_T20_bin"
            ),
            trigger: TriggerEvent.Identity(
                id: "coord_T20_east_exit",
                kind: .coordinateTrigger,
                localPosition: TilePosition(x: 24, y: 7),
                width: 1,
                height: 5,
                scriptReference: "script:20002"
            )
        )

        #expect(event.tick == 7)
        #expect(event.map.mapID == "MAP_NEW_BARK")
        #expect(event.map.eventsBank == "NARC_zone_event_057_T20_bin")
        #expect(event.trigger.id == "coord_T20_east_exit")
        #expect(event.trigger.kind == .coordinateTrigger)
        #expect(event.trigger.height == 5)
        #expect(event.trigger.scriptReference == "script:20002")
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

private struct SyntheticOpeningSaveMirror {
    let saveNumber: UInt32
    let hasPokedex: Bool
    let hasNationalDex: Bool
    let mysteryGiftReceived: Bool
    let mysteryGiftSystemActive: Bool

    let frontierMetadataByChunkID: [Int: SyntheticOpeningFrontierMetadata]
    let frontierChunkCopiesByChunkID: [Int: SyntheticOpeningExtraChunkCopy]

    init(
        saveNumber: UInt32,
        hasPokedex: Bool,
        hasNationalDex: Bool,
        mysteryGiftReceived: Bool,
        mysteryGiftSystemActive: Bool,
        frontierMetadataByChunkID: [Int: SyntheticOpeningFrontierMetadata] = [:],
        frontierChunkCopiesByChunkID: [Int: SyntheticOpeningExtraChunkCopy] = [:]
    ) {
        self.saveNumber = saveNumber
        self.hasPokedex = hasPokedex
        self.hasNationalDex = hasNationalDex
        self.mysteryGiftReceived = mysteryGiftReceived
        self.mysteryGiftSystemActive = mysteryGiftSystemActive
        self.frontierMetadataByChunkID = frontierMetadataByChunkID
        self.frontierChunkCopiesByChunkID = frontierChunkCopiesByChunkID
    }
}

private struct SyntheticOpeningFrontierMetadata {
    let currentToken: UInt32
    let previousToken: UInt32
    let activeSlot: UInt8
}

private struct SyntheticOpeningExtraChunkCopy {
    let token: UInt32
    let footerIsValid: Bool

    init(token: UInt32, footerIsValid: Bool = true) {
        self.token = token
        self.footerIsValid = footerIsValid
    }
}

private func makeOpeningRawSave(
    primaryMirror: SyntheticOpeningSaveMirror?,
    secondaryMirror: SyntheticOpeningSaveMirror?
) -> Data {
    var rawSave = Data(repeating: 0, count: 0x80000)
    if let primaryMirror {
        let bytes = makeOpeningSaveMirror(primaryMirror)
        rawSave.replaceSubrange(0 ..< 0x40000, with: bytes)
    }
    if let secondaryMirror {
        let bytes = makeOpeningSaveMirror(secondaryMirror)
        rawSave.replaceSubrange(0x40000 ..< 0x80000, with: bytes)
    }
    return rawSave
}

private func makeOpeningSaveMirror(_ mirror: SyntheticOpeningSaveMirror) -> Data {
    var data = Data(repeating: 0, count: 0x40000)
    var cursor = 0x200

    writeOpeningChunk(
        index: 0,
        payload: makeSysInfoPayload(mysteryGiftSystemActive: mirror.mysteryGiftSystemActive),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )
    writeOpeningChunk(
        index: 6,
        payload: makePokedexPayload(hasPokedex: mirror.hasPokedex, hasNationalDex: mirror.hasNationalDex),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )
    writeOpeningChunk(
        index: 27,
        payload: makeMysteryGiftPayload(receivedFlag7FF: mirror.mysteryGiftReceived),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )
    writeOpeningChunk(
        index: 9,
        payload: makeSaveMiscPayload(frontierMetadataByChunkID: mirror.frontierMetadataByChunkID),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )

    for (chunkID, copy) in mirror.frontierChunkCopiesByChunkID {
        writeOpeningExtraChunk(
            chunkID: chunkID,
            copy: copy,
            saveNumber: mirror.saveNumber,
            into: &data
        )
    }

    return data
}

private func writeOpeningChunk(
    index: UInt16,
    payload: Data,
    saveNumber: UInt32,
    into mirror: inout Data,
    cursor: inout Int
) {
    let footerSize = 16
    let chunkRange = cursor ..< (cursor + payload.count + footerSize)
    mirror.replaceSubrange(cursor ..< (cursor + payload.count), with: payload)

    var footerPrefix = Data()
    footerPrefix.appendLittleEndian(UInt32(0x2006_0623))
    footerPrefix.appendLittleEndian(saveNumber)
    footerPrefix.appendLittleEndian(UInt32(payload.count))
    footerPrefix.appendLittleEndian(index)

    let crc = openingTestCRC16(payload + footerPrefix)
    var footer = footerPrefix
    footer.appendLittleEndian(crc)
    mirror.replaceSubrange((cursor + payload.count) ..< chunkRange.upperBound, with: footer)

    cursor = chunkRange.upperBound + 0x80
}

private func makeSysInfoPayload(mysteryGiftSystemActive: Bool) -> Data {
    var payload = Data(repeating: 0, count: 0x5C)
    payload[0x48] = mysteryGiftSystemActive ? 1 : 0
    return payload
}

private func makePokedexPayload(hasPokedex: Bool, hasNationalDex: Bool) -> Data {
    var payload = Data(repeating: 0, count: 0x340)
    payload[0x336] = hasPokedex ? 1 : 0
    payload[0x337] = hasNationalDex ? 1 : 0
    return payload
}

private func makeMysteryGiftPayload(receivedFlag7FF: Bool) -> Data {
    var payload = Data(repeating: 0, count: 0x1680)
    payload[0xFF] = receivedFlag7FF ? 0x80 : 0
    return payload
}

private func makeSaveMiscPayload(
    frontierMetadataByChunkID: [Int: SyntheticOpeningFrontierMetadata]
) -> Data {
    var payload = Data(repeating: 0, count: 0x2E0)
    if frontierMetadataByChunkID.isEmpty == false {
        payload[0x29B] = 0x01
    }

    for index in 0..<5 {
        payload.replaceSubrange((0x2A8 + (index * 4)) ..< (0x2AC + (index * 4)), with: [0xFF, 0xFF, 0xFF, 0xFF])
        payload.replaceSubrange((0x2BC + (index * 4)) ..< (0x2C0 + (index * 4)), with: [0xFF, 0xFF, 0xFF, 0xFF])
    }

    for (chunkID, metadata) in frontierMetadataByChunkID {
        let metadataIndex = chunkID - 1
        guard metadataIndex >= 0 && metadataIndex < 5 else {
            continue
        }
        payload.replaceLittleEndian(metadata.currentToken, at: 0x2A8 + (metadataIndex * 4))
        payload.replaceLittleEndian(metadata.previousToken, at: 0x2BC + (metadataIndex * 4))
        payload[0x2D0 + metadataIndex] = metadata.activeSlot
    }

    return payload
}

private func writeOpeningExtraChunk(
    chunkID: Int,
    copy: SyntheticOpeningExtraChunkCopy,
    saveNumber: UInt32,
    into mirror: inout Data
) {
    let sectorByChunkID: [Int: Int] = [1: 38, 2: 39, 3: 41, 4: 43, 5: 45]
    let payloadSizeByChunkID: [Int: Int] = [1: 0xBA0, 2: 0x1D50, 3: 0x1D50, 4: 0x1D50, 5: 0x1D50]
    guard let sector = sectorByChunkID[chunkID],
          let payloadSize = payloadSizeByChunkID[chunkID] else {
        return
    }

    let start = sector * 0x1000
    let end = start + payloadSize + 16
    guard end <= mirror.count else {
        return
    }

    var payload = Data(repeating: 0, count: payloadSize)
    payload.replaceLittleEndian(copy.token, at: 0)
    mirror.replaceSubrange(start ..< (start + payloadSize), with: payload)

    var footerPrefix = Data()
    footerPrefix.appendLittleEndian(UInt32(0x2006_0623))
    footerPrefix.appendLittleEndian(saveNumber)
    footerPrefix.appendLittleEndian(UInt32(payloadSize))
    footerPrefix.appendLittleEndian(UInt16(chunkID))

    let crc = copy.footerIsValid ? openingTestCRC16(payload + footerPrefix) : 0
    var footer = footerPrefix
    footer.appendLittleEndian(crc)
    if copy.footerIsValid == false {
        footer.replaceLittleEndian(UInt32(0xBAD0_F00D), at: 0)
    }
    mirror.replaceSubrange((start + payloadSize) ..< end, with: footer)
}

private func openingTestCRC16(_ data: Data) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in data {
        crc ^= UInt16(byte) << 8
        for _ in 0 ..< 8 {
            if (crc & 0x8000) != 0 {
                crc = (crc << 1) ^ 0x1021
            } else {
                crc <<= 1
            }
        }
    }
    return crc
}

private extension Data {
    mutating func replaceLittleEndian(_ value: UInt32, at offset: Int) {
        replaceSubrange(offset ..< (offset + 4), with: [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 24),
        ])
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
