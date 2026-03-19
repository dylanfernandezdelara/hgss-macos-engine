import Foundation

public struct HGSSOpeningFeatureAvailability: Codable, Equatable, Sendable {
    public let mysteryGiftEnabled: Bool?
    public let rangerEnabled: Bool
    public let connectToWiiEnabled: Bool
    public let connectedAGBGame: HGSSOpeningAGBGame

    public init(
        mysteryGiftEnabled: Bool? = nil,
        rangerEnabled: Bool = false,
        connectToWiiEnabled: Bool = false,
        connectedAGBGame: HGSSOpeningAGBGame = .none
    ) {
        self.mysteryGiftEnabled = mysteryGiftEnabled
        self.rangerEnabled = rangerEnabled
        self.connectToWiiEnabled = connectToWiiEnabled
        self.connectedAGBGame = connectedAGBGame
    }

    public static let none = HGSSOpeningFeatureAvailability()
}

public struct HGSSOpeningLocalSaveSummaryLoader: Sendable {
    public static let environmentSaveFileKey = "HGSS_SAVE_FILE"
    public static let featureAvailabilityFilename = "opening_feature_flags.json"
    public static let localSaveFilenames = [
        "opening_savedata.sav",
        "opening_savedata.dsv",
        "opening_savedata.duc",
    ]

    private static let rawSaveSize = 0x80000
    private static let mirrorSize = 0x40000
    private static let saveChunkMagic: UInt32 = 0x2006_0623

    private static let sysInfoChunkIndex = 0
    private static let pokedexChunkIndex = 6
    private static let saveMiscChunkIndex = 9
    private static let mysteryGiftChunkIndex = 27

    private static let sysInfoMysteryGiftActiveOffset = 0x48
    private static let pokedexDexEnabledOffset = 0x336
    private static let pokedexNationalDexOffset = 0x337
    private static let saveMiscExtraChunksExistOffset = 0x29B
    private static let saveMiscExtraChunkCurrentOffset = 0x2A8
    private static let saveMiscExtraChunkPreviousOffset = 0x2BC
    private static let saveMiscExtraChunkActiveSlotOffset = 0x2D0
    private static let mysteryGiftReceivedFlagsOffset = 0xFF
    private static let mysteryGiftReceivedFlagsMask: UInt8 = 0x80
    private static let noExtraChunkToken: UInt32 = 0xFFFF_FFFF

    private static let frontierChunkDefinitions: [FrontierExtraChunkDefinition] = [
        .init(chunkID: 1, sector: 38, payloadSize: 0xBA0, category: .battleHall),
        .init(chunkID: 2, sector: 39, payloadSize: 0x1D50, category: .battleVideo),
        .init(chunkID: 3, sector: 41, payloadSize: 0x1D50, category: .battleVideo),
        .init(chunkID: 4, sector: 43, payloadSize: 0x1D50, category: .battleVideo),
        .init(chunkID: 5, sector: 45, payloadSize: 0x1D50, category: .battleVideo),
    ]

    public init() {}

    public func load(
        from root: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> HGSSOpeningSaveSummary? {
        let featureAvailability = try loadFeatureAvailability(from: root)
        guard let saveURL = try resolveSaveFileURL(from: root, environment: environment) else {
            return nil
        }
        return try loadSummary(from: saveURL, featureAvailability: featureAvailability)
    }

    private func resolveSaveFileURL(
        from root: URL,
        environment: [String: String]
    ) throws -> URL? {
        if let override = environment[Self.environmentSaveFileKey], override.isEmpty == false {
            let url = URL(fileURLWithPath: override, isDirectory: false)
            guard FileManager.default.fileExists(atPath: url.path()) else {
                throw NSError(
                    domain: "HGSSCore",
                    code: 201,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Configured HGSS save file does not exist: \(url.path())"
                    ]
                )
            }
            return url
        }

        for filename in Self.localSaveFilenames {
            let url = root.appendingPathComponent(filename, isDirectory: false)
            if FileManager.default.fileExists(atPath: url.path()) {
                return url
            }
        }

        return nil
    }

    private func loadFeatureAvailability(from root: URL) throws -> HGSSOpeningFeatureAvailability {
        let url = root.appendingPathComponent(Self.featureAvailabilityFilename, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path()) else {
            return .none
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(HGSSOpeningFeatureAvailability.self, from: data)
    }

    private func loadSummary(
        from saveURL: URL,
        featureAvailability: HGSSOpeningFeatureAvailability
    ) throws -> HGSSOpeningSaveSummary {
        let container = try Data(contentsOf: saveURL)
        for candidate in rawSaveCandidates(from: container) {
            if let summary = makeSummary(from: candidate, featureAvailability: featureAvailability) {
                return summary
            }
        }

        throw NSError(
            domain: "HGSSCore",
            code: 202,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Failed to parse a supported HeartGold save snapshot from \(saveURL.lastPathComponent)."
            ]
        )
    }

    private func rawSaveCandidates(from container: Data) -> [Data] {
        if container.count == Self.rawSaveSize {
            return [container]
        }

        guard container.count > Self.rawSaveSize else {
            return []
        }

        var candidates: [Data] = []
        candidates.append(Data(container.prefix(Self.rawSaveSize)))

        let tailStart = container.count - Self.rawSaveSize
        let tail = container.subdata(in: tailStart ..< container.count)
        if tail != candidates[0] {
            candidates.append(tail)
        }
        return candidates
    }

    private func makeSummary(
        from rawSaveData: Data,
        featureAvailability: HGSSOpeningFeatureAvailability
    ) -> HGSSOpeningSaveSummary? {
        guard rawSaveData.count == Self.rawSaveSize else {
            return nil
        }

        let mirrors = [
            parseMirror(rawSaveData.subdata(in: 0 ..< Self.mirrorSize)),
            parseMirror(rawSaveData.subdata(in: Self.mirrorSize ..< Self.rawSaveSize))
        ]
        let validMirrors = mirrors.compactMap { $0 }

        let selectedMirror = validMirrors.max { lhs, rhs in
            if lhs.saveNumber == rhs.saveNumber {
                return lhs.chunkCount < rhs.chunkCount
            }
            return lhs.saveNumber < rhs.saveNumber
        }

        let mainSaveStatus: HGSSOpeningSaveRecordStatus
        switch validMirrors.count {
        case 0:
            mainSaveStatus = rawSaveData.allSatisfy { $0 == 0xFF } ? .absent : .erased
        case 1:
            mainSaveStatus = .corrupted
        default:
            mainSaveStatus = .valid
        }

        let hasUsableSaveData = selectedMirror != nil
        let hasPokedex = selectedMirror?.chunkByte(Self.pokedexChunkIndex, offset: Self.pokedexDexEnabledOffset) != 0
        let hasNationalDex = selectedMirror?.chunkByte(Self.pokedexChunkIndex, offset: Self.pokedexNationalDexOffset) != 0
        let mysteryGiftFromSave =
            (selectedMirror?.chunkByte(Self.mysteryGiftChunkIndex, offset: Self.mysteryGiftReceivedFlagsOffset) ?? 0)
            & Self.mysteryGiftReceivedFlagsMask != 0
        let mysteryGiftFromSystem =
            (selectedMirror?.chunkByte(Self.sysInfoChunkIndex, offset: Self.sysInfoMysteryGiftActiveOffset) ?? 0) != 0
        let frontierStatuses = frontierStatuses(
            from: rawSaveData,
            selectedMirror: selectedMirror
        )

        return HGSSOpeningSaveSummary(
            hasUsableSaveData: hasUsableSaveData,
            mainSaveStatus: mainSaveStatus,
            battleHallStatus: frontierStatuses.battleHall,
            battleVideoStatus: frontierStatuses.battleVideo,
            hasPokedex: hasPokedex,
            mysteryGiftEnabled: mysteryGiftFromSave || mysteryGiftFromSystem || featureAvailability.mysteryGiftEnabled == true,
            rangerEnabled: featureAvailability.rangerEnabled,
            connectToWiiEnabled: featureAvailability.connectToWiiEnabled,
            connectedAGBGame: hasNationalDex ? featureAvailability.connectedAGBGame : .none
        )
    }

    private func frontierStatuses(
        from rawSaveData: Data,
        selectedMirror: ParsedMirror?
    ) -> (battleHall: HGSSOpeningSaveRecordStatus, battleVideo: HGSSOpeningSaveRecordStatus) {
        guard let saveMisc = selectedMirror?.chunks[Self.saveMiscChunkIndex],
              saveMisc.byte(at: Self.saveMiscExtraChunksExistOffset).map({ ($0 & 0x01) != 0 }) == true
        else {
            return (.absent, .absent)
        }

        var battleHallStatuses: [HGSSOpeningSaveRecordStatus] = []
        var battleVideoStatuses: [HGSSOpeningSaveRecordStatus] = []

        for definition in Self.frontierChunkDefinitions {
            guard let metadata = frontierChunkMetadata(
                for: definition.chunkID,
                saveMisc: saveMisc
            ) else {
                continue
            }

            let status = frontierChunkStatus(
                in: rawSaveData,
                definition: definition,
                metadata: metadata
            )
            switch definition.category {
            case .battleHall:
                battleHallStatuses.append(status)
            case .battleVideo:
                battleVideoStatuses.append(status)
            }
        }

        return (
            reduceFrontierStatuses(battleHallStatuses),
            reduceFrontierStatuses(battleVideoStatuses)
        )
    }

    private func frontierChunkMetadata(
        for chunkID: Int,
        saveMisc: Data
    ) -> FrontierExtraChunkMetadata? {
        let metadataIndex = chunkID - 1
        guard metadataIndex >= 0 && metadataIndex < 5,
              let currentToken = saveMisc.readUInt32LE(at: Self.saveMiscExtraChunkCurrentOffset + (metadataIndex * 4)),
              let previousToken = saveMisc.readUInt32LE(at: Self.saveMiscExtraChunkPreviousOffset + (metadataIndex * 4)),
              let activeSlot = saveMisc.byte(at: Self.saveMiscExtraChunkActiveSlotOffset + metadataIndex)
        else {
            return nil
        }

        guard currentToken != Self.noExtraChunkToken || previousToken != Self.noExtraChunkToken else {
            return nil
        }

        return FrontierExtraChunkMetadata(
            currentToken: currentToken,
            previousToken: previousToken,
            activeSlot: activeSlot
        )
    }

    private func frontierChunkStatus(
        in rawSaveData: Data,
        definition: FrontierExtraChunkDefinition,
        metadata: FrontierExtraChunkMetadata
    ) -> HGSSOpeningSaveRecordStatus {
        let primaryCopy = readFrontierChunkCopy(
            rawSaveData: rawSaveData,
            definition: definition,
            mirrorOffset: 0
        )
        let secondaryCopy = readFrontierChunkCopy(
            rawSaveData: rawSaveData,
            definition: definition,
            mirrorOffset: Self.mirrorSize
        )

        let primaryValid = primaryCopy?.isValid == true
        let secondaryValid = secondaryCopy?.isValid == true

        if primaryValid && !secondaryValid && metadata.currentToken == primaryCopy?.token {
            return metadata.activeSlot == 1 ? .corrupted : .valid
        }

        if !primaryValid && secondaryValid && metadata.currentToken == secondaryCopy?.token {
            return metadata.activeSlot == 0 ? .corrupted : .valid
        }

        if primaryValid && secondaryValid {
            if metadata.activeSlot == 0 {
                if metadata.currentToken == primaryCopy?.token {
                    return .valid
                }
                if metadata.previousToken == secondaryCopy?.token {
                    return .corrupted
                }
            } else {
                if metadata.currentToken == secondaryCopy?.token {
                    return .valid
                }
                if metadata.previousToken == primaryCopy?.token {
                    return .corrupted
                }
            }
        }

        return .erased
    }

    private func readFrontierChunkCopy(
        rawSaveData: Data,
        definition: FrontierExtraChunkDefinition,
        mirrorOffset: Int
    ) -> ParsedFrontierExtraChunkCopy? {
        let start = mirrorOffset + (definition.sector * 0x1000)
        let end = start + definition.payloadSize + 16
        guard start >= 0, end <= rawSaveData.count else {
            return nil
        }

        let chunkData = rawSaveData.subdata(in: start ..< end)
        let payload = chunkData.prefix(definition.payloadSize)
        let footerOffset = definition.payloadSize
        guard let magic = chunkData.readUInt32LE(at: footerOffset),
              let footerSize = chunkData.readUInt32LE(at: footerOffset + 8),
              let chunkID = chunkData.readUInt16LE(at: footerOffset + 12),
              let storedCRC = chunkData.readUInt16LE(at: footerOffset + 14)
        else {
            return nil
        }

        let calculatedCRC = NitroCRC16CCITT.compute(Data(chunkData.prefix(definition.payloadSize + 14)))
        let token = Data(payload).readUInt32LE(at: 0)
        return ParsedFrontierExtraChunkCopy(
            token: token,
            isValid: magic == Self.saveChunkMagic
                && footerSize == definition.payloadSize
                && chunkID == UInt16(definition.chunkID)
                && storedCRC == calculatedCRC
        )
    }

    private func reduceFrontierStatuses(
        _ statuses: [HGSSOpeningSaveRecordStatus]
    ) -> HGSSOpeningSaveRecordStatus {
        guard statuses.isEmpty == false else {
            return .absent
        }
        if statuses.contains(.erased) {
            return .erased
        }
        if statuses.contains(.corrupted) {
            return .corrupted
        }
        if statuses.contains(.valid) {
            return .valid
        }
        return .absent
    }

    private func parseMirror(_ mirrorData: Data) -> ParsedMirror? {
        let candidates = collectChunkCandidates(in: mirrorData)
        guard candidates.isEmpty == false else {
            return nil
        }

        let groupedBySaveNo = Dictionary(grouping: candidates, by: \.saveNumber)
        let rankedGroups = groupedBySaveNo.values.sorted { lhs, rhs in
            let lhsUnique = Set(lhs.map(\.index)).count
            let rhsUnique = Set(rhs.map(\.index)).count
            if lhsUnique == rhsUnique {
                return lhs.first!.saveNumber > rhs.first!.saveNumber
            }
            return lhsUnique > rhsUnique
        }

        guard let bestGroup = rankedGroups.first else {
            return nil
        }

        var chunks: [Int: Data] = [:]
        for candidate in bestGroup {
            if chunks[candidate.index] == nil {
                chunks[candidate.index] = candidate.payload
            }
        }

        guard chunks.isEmpty == false else {
            return nil
        }

        return ParsedMirror(
            saveNumber: bestGroup[0].saveNumber,
            chunks: chunks
        )
    }

    private func collectChunkCandidates(in mirrorData: Data) -> [ParsedChunkCandidate] {
        guard mirrorData.count >= 16 else {
            return []
        }

        var candidates: [ParsedChunkCandidate] = []
        for footerStart in 0 ... (mirrorData.count - 16) {
            guard mirrorData.readUInt32LE(at: footerStart) == Self.saveChunkMagic,
                  let saveNumber = mirrorData.readUInt32LE(at: footerStart + 4),
                  let payloadSize = mirrorData.readUInt32LE(at: footerStart + 8),
                  let chunkIndex = mirrorData.readUInt16LE(at: footerStart + 12),
                  let storedCRC = mirrorData.readUInt16LE(at: footerStart + 14)
            else {
                continue
            }

            let payloadByteCount = Int(payloadSize)
            let chunkIndexInt = Int(chunkIndex)
            guard chunkIndexInt >= 0,
                  chunkIndexInt < 42,
                  payloadByteCount > 0,
                  payloadByteCount <= footerStart
            else {
                continue
            }

            let payloadStart = footerStart - payloadByteCount
            let crcRange = payloadStart ..< (footerStart + 14)
            guard crcRange.upperBound <= mirrorData.count else {
                continue
            }

            let calculatedCRC = NitroCRC16CCITT.compute(mirrorData[crcRange])
            guard calculatedCRC == storedCRC else {
                continue
            }

            let payload = mirrorData.subdata(in: payloadStart ..< footerStart)
            candidates.append(
                ParsedChunkCandidate(
                    index: chunkIndexInt,
                    saveNumber: saveNumber,
                    payload: payload
                )
            )
        }

        return candidates
    }
}

private struct ParsedChunkCandidate {
    let index: Int
    let saveNumber: UInt32
    let payload: Data
}

private struct ParsedMirror {
    let saveNumber: UInt32
    let chunks: [Int: Data]

    var chunkCount: Int {
        chunks.count
    }

    func chunkByte(_ index: Int, offset: Int) -> UInt8? {
        chunks[index]?.byte(at: offset)
    }
}

private struct FrontierExtraChunkDefinition {
    enum Category {
        case battleHall
        case battleVideo
    }

    let chunkID: Int
    let sector: Int
    let payloadSize: Int
    let category: Category
}

private struct FrontierExtraChunkMetadata {
    let currentToken: UInt32
    let previousToken: UInt32
    let activeSlot: UInt8
}

private struct ParsedFrontierExtraChunkCopy {
    let token: UInt32?
    let isValid: Bool
}

private enum NitroCRC16CCITT {
    static func compute(_ data: Data) -> UInt16 {
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
}

private extension Data {
    func byte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < count else {
            return nil
        }
        return self[startIndex.advanced(by: offset)]
    }

    func readUInt16LE(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else {
            return nil
        }
        return withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }
            let pointer = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
            let low = UInt16(pointer[0])
            let high = UInt16(pointer[1]) << 8
            return low | high
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else {
            return nil
        }
        return withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }
            let pointer = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
            let b0 = UInt32(pointer[0])
            let b1 = UInt32(pointer[1]) << 8
            let b2 = UInt32(pointer[2]) << 16
            let b3 = UInt32(pointer[3]) << 24
            return b0 | b1 | b2 | b3
        }
    }
}
