import Foundation
import HGSSDataModel

public enum PretNormalizationError: LocalizedError {
    case missingProfileMap(String)
    case missingMapHeader(String)
    case malformedMapHeader(String)
    case missingMapHeaderField(mapID: String, field: String)
    case invalidIntegerField(mapID: String, field: String, value: String)
    case invalidBooleanField(mapID: String, field: String, value: String)
    case eventDecodeFailed(underlying: Error)
    case malformedMapMatrix(String)
    case malformedCollisionArchive(String)
    case missingCollisionModel(mapID: String, modelIndex: Int)
    case invalidCollisionMatrixCell(mapID: String, cellX: Int, cellZ: Int)
    case invalidCollisionModelReference(mapID: String, cellX: Int, cellZ: Int, modelIndex: Int)
    case excerptCrossesCollisionModelBoundary(mapID: String, sourceX: Int, sourceZ: Int, width: Int, height: Int)
    case invalidCollisionSourceTile(mapID: String, x: Int, z: Int, y: Int)
    case invalidCollisionSourcePlane(mapID: String, expectedY: Int, actualY: Int)

    public var errorDescription: String? {
        switch self {
        case let .missingProfileMap(mapID):
            return "The profile manifest does not contain map '\(mapID)'."
        case let .missingMapHeader(mapID):
            return "Could not find map header block for '\(mapID)' in map_headers.h."
        case let .malformedMapHeader(mapID):
            return "The map header block for '\(mapID)' could not be parsed."
        case let .missingMapHeaderField(mapID, field):
            return "Map header '\(mapID)' is missing required field '\(field)'."
        case let .invalidIntegerField(mapID, field, value):
            return "Map header '\(mapID)' field '\(field)' is not a valid integer: \(value)."
        case let .invalidBooleanField(mapID, field, value):
            return "Map header '\(mapID)' field '\(field)' is not a valid boolean token: \(value)."
        case let .eventDecodeFailed(underlying):
            return "Failed to decode zone event JSON: \(underlying.localizedDescription)"
        case let .malformedMapMatrix(details):
            return "Failed to parse pret map_matrix data: \(details)"
        case let .malformedCollisionArchive(details):
            return "Failed to parse pret collision archive: \(details)"
        case let .missingCollisionModel(mapID, modelIndex):
            return "Map '\(mapID)' references missing collision model \(modelIndex)."
        case let .invalidCollisionMatrixCell(mapID, cellX, cellZ):
            return "Map '\(mapID)' source origin resolves outside the pret map_matrix bounds at cell (\(cellX), \(cellZ))."
        case let .invalidCollisionModelReference(mapID, cellX, cellZ, modelIndex):
            return "Map '\(mapID)' has invalid collision model \(modelIndex) at matrix cell (\(cellX), \(cellZ))."
        case let .excerptCrossesCollisionModelBoundary(mapID, sourceX, sourceZ, width, height):
            return "Map '\(mapID)' excerpt starting at (\(sourceX), \(sourceZ)) with size \(width)x\(height) crosses a 32x32 pret collision model boundary."
        case let .invalidCollisionSourceTile(mapID, x, z, y):
            return "Map '\(mapID)' has extracted collision tile (\(x), \(z), \(y)) outside the normalized excerpt bounds."
        case let .invalidCollisionSourcePlane(mapID, expectedY, actualY):
            return "Map '\(mapID)' has extracted collision tile on source y-plane \(actualY), expected \(expectedY)."
        }
    }
}

public struct PretExtractedCollisionInput: Equatable, Sendable {
    public struct BlockedTile: Equatable, Sendable {
        public let sourcePosition: HGSSManifest.SourcePoint

        public init(sourcePosition: HGSSManifest.SourcePoint) {
            self.sourcePosition = sourcePosition
        }
    }

    public let blockedTiles: [BlockedTile]

    public init(blockedTiles: [BlockedTile]) {
        self.blockedTiles = blockedTiles
    }
}

public struct PretExtractedCollisionAdapter {
    public init() {}

    public func collisionLayer(
        from input: PretExtractedCollisionInput,
        layout: HGSSManifest.MapLayout,
        mapID: String
    ) throws -> HGSSManifest.CollisionLayer {
        var localTiles: Set<HGSSManifest.GridPoint> = []

        for tile in input.blockedTiles {
            guard tile.sourcePosition.y == layout.sourceOrigin.y else {
                throw PretNormalizationError.invalidCollisionSourcePlane(
                    mapID: mapID,
                    expectedY: layout.sourceOrigin.y,
                    actualY: tile.sourcePosition.y
                )
            }

            let localTile = HGSSManifest.GridPoint(
                x: tile.sourcePosition.x - layout.sourceOrigin.x,
                y: tile.sourcePosition.z - layout.sourceOrigin.z
            )

            guard contains(localTile, layout: layout) else {
                throw PretNormalizationError.invalidCollisionSourceTile(
                    mapID: mapID,
                    x: tile.sourcePosition.x,
                    z: tile.sourcePosition.z,
                    y: tile.sourcePosition.y
                )
            }

            localTiles.insert(localTile)
        }

        let sortedTiles = localTiles.sorted { lhs, rhs in
            if lhs.y == rhs.y {
                return lhs.x < rhs.x
            }
            return lhs.y < rhs.y
        }

        return HGSSManifest.CollisionLayer(impassableTiles: sortedTiles)
    }

    private func contains(_ tile: HGSSManifest.GridPoint, layout: HGSSManifest.MapLayout) -> Bool {
        tile.x >= 0 && tile.x < layout.width && tile.y >= 0 && tile.y < layout.height
    }
}

private enum PretCollisionConstants {
    static let collisionModelTileWidth = 32
    static let collisionHeaderSize = 0x14
    static let permissionSectionSize = collisionModelTileWidth * collisionModelTileWidth * 2
    static let solidMovementPermission: UInt8 = 0x80
}

public struct PretNewBarkCollisionExtractor {
    public init() {}

    public func extractCollisionInput(
        layout: HGSSManifest.MapLayout,
        mapMatrixData: Data,
        modelArchiveData: Data,
        mapID: String = "MAP_NEW_BARK"
    ) throws -> PretExtractedCollisionInput {
        let mapMatrix = try PretMapMatrix(data: mapMatrixData)
        let collisionArchive = try PretNARCArchive(data: modelArchiveData)

        let sourceOrigin = layout.sourceOrigin
        let cellX = sourceOrigin.x / PretCollisionConstants.collisionModelTileWidth
        let cellZ = sourceOrigin.z / PretCollisionConstants.collisionModelTileWidth
        let tileOffsetX = sourceOrigin.x % PretCollisionConstants.collisionModelTileWidth
        let tileOffsetZ = sourceOrigin.z % PretCollisionConstants.collisionModelTileWidth

        guard tileOffsetX + layout.width <= PretCollisionConstants.collisionModelTileWidth,
              tileOffsetZ + layout.height <= PretCollisionConstants.collisionModelTileWidth else {
            throw PretNormalizationError.excerptCrossesCollisionModelBoundary(
                mapID: mapID,
                sourceX: sourceOrigin.x,
                sourceZ: sourceOrigin.z,
                width: layout.width,
                height: layout.height
            )
        }

        let modelIndex = try mapMatrix.modelIndex(atCellX: cellX, cellZ: cellZ, mapID: mapID)
        let collisionModel = try collisionArchive.member(at: modelIndex, mapID: mapID)
        let permissions = try PretCollisionPermissionTable(data: collisionModel)

        var blockedTiles: [PretExtractedCollisionInput.BlockedTile] = []

        for localY in 0..<layout.height {
            for localX in 0..<layout.width {
                let modelTileX = tileOffsetX + localX
                let modelTileZ = tileOffsetZ + localY
                let permission = try permissions.permission(atMapTileX: modelTileX, mapTileZ: modelTileZ)
                let movementPermission = UInt8((permission >> 8) & 0xFF)
                guard movementPermission == 0x00
                    || movementPermission == 0x04
                    || movementPermission == 0x06
                    || movementPermission == PretCollisionConstants.solidMovementPermission else {
                    throw PretNormalizationError.malformedCollisionArchive(
                        "Unsupported movement permission byte \(movementPermission) at model tile (\(modelTileX), \(modelTileZ))."
                    )
                }
                guard movementPermission == PretCollisionConstants.solidMovementPermission else {
                    continue
                }

                blockedTiles.append(
                    PretExtractedCollisionInput.BlockedTile(
                        sourcePosition: HGSSManifest.SourcePoint(
                            x: sourceOrigin.x + localX,
                            z: sourceOrigin.z + localY,
                            y: sourceOrigin.y
                        )
                    )
                )
            }
        }

        return PretExtractedCollisionInput(blockedTiles: blockedTiles)
    }
}

public struct PretNewBarkNormalizer {
    public init() {}

    public func buildManifest(
        from profileManifest: HGSSManifest,
        mapHeadersText: String,
        zoneEventData: Data,
        extractedCollision: PretExtractedCollisionInput? = nil,
        mapID: String = "MAP_NEW_BARK"
    ) throws -> HGSSManifest {
        guard let profileMap = profileManifest.maps.first(where: { $0.mapID == mapID }) else {
            throw PretNormalizationError.missingProfileMap(mapID)
        }

        let headerFields = try parseMapHeaderFields(mapHeadersText: mapHeadersText, mapID: mapID)
        let zoneEvents = try decodeZoneEvents(data: zoneEventData)

        let generatedMap = HGSSManifest.MapEntry(
            mapID: profileMap.mapID,
            displayName: profileMap.displayName,
            provenance: HGSSManifest.MapProvenance(
                upstreamMapID: mapID,
                mapHeaderSymbol: "sMapHeaders[\(mapID)]",
                matrixID: try requiredField("matrixId", in: headerFields, mapID: mapID),
                eventsBank: try requiredField("eventsBank", in: headerFields, mapID: mapID)
            ),
            header: try buildMapHeader(from: headerFields, mapID: mapID),
            layout: profileMap.layout,
            collision: try buildCollision(
                extractedCollision: extractedCollision,
                fallbackCollision: profileMap.collision,
                layout: profileMap.layout,
                mapID: mapID
            ),
            entryPoints: profileMap.entryPoints,
            warps: buildWarps(from: zoneEvents.warps, layout: profileMap.layout),
            placements: buildPlacements(zoneEvents: zoneEvents, layout: profileMap.layout)
        )

        let maps = profileManifest.maps.map { map in
            map.mapID == mapID ? generatedMap : map
        }

        return HGSSManifest(
            schemaVersion: profileManifest.schemaVersion,
            title: profileManifest.title,
            build: profileManifest.build,
            initialMapID: profileManifest.initialMapID,
            initialEntryPointID: profileManifest.initialEntryPointID,
            maps: maps,
            pokemon: profileManifest.pokemon,
            notes: buildNotes(
                fallbackNotes: profileManifest.notes,
                extractedCollision: extractedCollision
            )
        )
    }

    private func buildCollision(
        extractedCollision: PretExtractedCollisionInput?,
        fallbackCollision: HGSSManifest.CollisionLayer,
        layout: HGSSManifest.MapLayout,
        mapID: String
    ) throws -> HGSSManifest.CollisionLayer {
        guard let extractedCollision else {
            return fallbackCollision
        }

        return try PretExtractedCollisionAdapter().collisionLayer(
            from: extractedCollision,
            layout: layout,
            mapID: mapID
        )
    }

    private func buildNotes(
        fallbackNotes: String,
        extractedCollision: PretExtractedCollisionInput?
    ) -> String {
        guard extractedCollision != nil else {
            return fallbackNotes
        }

        return "Normalized New Bark excerpt manifest built from local profile excerpt bounds and entry points plus pret/pokeheartgold header, event, and collision inputs."
    }

    private func parseMapHeaderFields(mapHeadersText: String, mapID: String) throws -> [String: String] {
        let pattern = "\\[\(NSRegularExpression.escapedPattern(for: mapID))\\]\\s*=\\s*\\{([\\s\\S]*?)\\n\\s*\\},"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(mapHeadersText.startIndex..<mapHeadersText.endIndex, in: mapHeadersText)
        guard let match = regex.firstMatch(in: mapHeadersText, options: [], range: range),
              match.numberOfRanges == 2,
              let blockRange = Range(match.range(at: 1), in: mapHeadersText) else {
            throw PretNormalizationError.missingMapHeader(mapID)
        }

        let block = String(mapHeadersText[blockRange])
        let assignmentRegex = try NSRegularExpression(pattern: "\\.([A-Za-z0-9_]+)\\s*=\\s*([^,]+),", options: [])
        let blockRangeNS = NSRange(block.startIndex..<block.endIndex, in: block)
        let matches = assignmentRegex.matches(in: block, options: [], range: blockRangeNS)
        guard !matches.isEmpty else {
            throw PretNormalizationError.malformedMapHeader(mapID)
        }

        var fields: [String: String] = [:]
        for match in matches where match.numberOfRanges == 3 {
            guard let keyRange = Range(match.range(at: 1), in: block),
                  let valueRange = Range(match.range(at: 2), in: block) else {
                continue
            }
            fields[String(block[keyRange])] = String(block[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fields
    }

    private func buildMapHeader(from fields: [String: String], mapID: String) throws -> HGSSManifest.MapHeaderMetadata {
        HGSSManifest.MapHeaderMetadata(
            wildEncounterBank: try requiredField("wildEncounterBank", in: fields, mapID: mapID),
            areaDataBank: try integerField("areaDataBank", in: fields, mapID: mapID),
            moveModelBank: try integerField("moveModelBank", in: fields, mapID: mapID),
            worldMapX: try integerField("worldMapX", in: fields, mapID: mapID),
            worldMapY: try integerField("worldMapY", in: fields, mapID: mapID),
            mapSection: try requiredField("mapsec", in: fields, mapID: mapID),
            mapType: try requiredField("mapType", in: fields, mapID: mapID),
            followMode: try requiredField("followMode", in: fields, mapID: mapID),
            bikeAllowed: try booleanField("bikeAllowed", in: fields, mapID: mapID),
            flyAllowed: try booleanField("flyAllowed", in: fields, mapID: mapID),
            isKanto: try booleanField("isKanto", in: fields, mapID: mapID),
            weather: try integerField("weather", in: fields, mapID: mapID),
            cameraType: try integerField("cameraType", in: fields, mapID: mapID)
        )
    }

    private func requiredField(_ name: String, in fields: [String: String], mapID: String) throws -> String {
        guard let value = fields[name] else {
            throw PretNormalizationError.missingMapHeaderField(mapID: mapID, field: name)
        }
        return value
    }

    private func integerField(_ name: String, in fields: [String: String], mapID: String) throws -> Int {
        let rawValue = try requiredField(name, in: fields, mapID: mapID)
        guard let value = Int(rawValue) else {
            throw PretNormalizationError.invalidIntegerField(mapID: mapID, field: name, value: rawValue)
        }
        return value
    }

    private func booleanField(_ name: String, in fields: [String: String], mapID: String) throws -> Bool {
        let rawValue = try requiredField(name, in: fields, mapID: mapID)
        switch rawValue {
        case "TRUE":
            return true
        case "FALSE":
            return false
        default:
            throw PretNormalizationError.invalidBooleanField(mapID: mapID, field: name, value: rawValue)
        }
    }

    private func decodeZoneEvents(data: Data) throws -> PretZoneEvents {
        do {
            return try JSONDecoder().decode(PretZoneEvents.self, from: data)
        } catch {
            throw PretNormalizationError.eventDecodeFailed(underlying: error)
        }
    }

    private func buildWarps(
        from warps: [PretZoneEvents.WarpEvent],
        layout: HGSSManifest.MapLayout
    ) -> [HGSSManifest.Warp] {
        let filtered = warps.filter { contains(sourceX: $0.x, sourceZ: $0.z, layout: layout) }
        var seenIDs: [String: Int] = [:]

        return filtered.map { warp in
            let baseID = "WARP_\(warp.header)"
            let id = uniquedIdentifier(baseID, seen: &seenIDs)
            return HGSSManifest.Warp(
                id: id,
                localPosition: localPoint(x: warp.x, z: warp.z, layout: layout),
                sourcePosition: HGSSManifest.SourcePoint(x: warp.x, z: warp.z, y: warp.y),
                destinationMapID: warp.header,
                destinationAnchor: warp.anchor,
                summary: "Normalized warp to \(warp.header)."
            )
        }
    }

    private func buildPlacements(
        zoneEvents: PretZoneEvents,
        layout: HGSSManifest.MapLayout
    ) -> [HGSSManifest.Placement] {
        var placements: [HGSSManifest.Placement] = []

        for object in zoneEvents.objects where contains(sourceX: object.x, sourceZ: object.z, layout: layout) {
            placements.append(
                HGSSManifest.Placement(
                    id: object.id,
                    kind: .object,
                    localPosition: localPoint(x: object.x, z: object.z, layout: layout),
                    sourcePosition: HGSSManifest.SourcePoint(x: object.x, z: object.z, y: object.y),
                    width: 1,
                    height: 1,
                    scriptReference: object.scriptId.reference,
                    summary: "Normalized upstream object event \(object.id)."
                )
            )
        }

        for (index, coord) in zoneEvents.coords.enumerated() {
            let origin = localPoint(x: coord.x, z: coord.z, layout: layout)
            let maxX = origin.x + coord.w - 1
            let maxY = origin.y + coord.h - 1
            guard contains(localX: origin.x, localY: origin.y, layout: layout),
                  contains(localX: maxX, localY: maxY, layout: layout) else {
                continue
            }

            let variableToken = sanitizeIdentifier(coord.variable)
            placements.append(
                HGSSManifest.Placement(
                    id: "coord_\(index)_\(variableToken)",
                    kind: .coordinateTrigger,
                    localPosition: origin,
                    sourcePosition: HGSSManifest.SourcePoint(x: coord.x, z: coord.z, y: coord.y),
                    width: coord.w,
                    height: coord.h,
                    scriptReference: coord.scriptId.reference,
                    summary: "Normalized upstream coordinate event for \(coord.variable)."
                )
            )
        }

        for (index, bg) in zoneEvents.bgs.enumerated() where contains(sourceX: bg.x, sourceZ: bg.z, layout: layout) {
            let reference = bg.scriptId.reference ?? "bg_\(index)"
            placements.append(
                HGSSManifest.Placement(
                    id: "bg_\(index)_\(sanitizeIdentifier(reference))",
                    kind: .backgroundEvent,
                    localPosition: localPoint(x: bg.x, z: bg.z, layout: layout),
                    sourcePosition: HGSSManifest.SourcePoint(x: bg.x, z: bg.z, y: bg.y),
                    width: 1,
                    height: 1,
                    scriptReference: bg.scriptId.reference,
                    summary: "Normalized upstream background event type \(bg.type)."
                )
            )
        }

        return placements
    }

    private func localPoint(x: Int, z: Int, layout: HGSSManifest.MapLayout) -> HGSSManifest.GridPoint {
        HGSSManifest.GridPoint(
            x: x - layout.sourceOrigin.x,
            y: z - layout.sourceOrigin.z
        )
    }

    private func contains(sourceX: Int, sourceZ: Int, layout: HGSSManifest.MapLayout) -> Bool {
        let point = localPoint(x: sourceX, z: sourceZ, layout: layout)
        return contains(localX: point.x, localY: point.y, layout: layout)
    }

    private func contains(localX: Int, localY: Int, layout: HGSSManifest.MapLayout) -> Bool {
        localX >= 0 && localX < layout.width && localY >= 0 && localY < layout.height
    }

    private func uniquedIdentifier(_ base: String, seen: inout [String: Int]) -> String {
        let next = seen[base, default: 0]
        seen[base] = next + 1
        return next == 0 ? base : "\(base)_\(next + 1)"
    }

    private func sanitizeIdentifier(_ raw: String) -> String {
        let sanitized = raw.replacingOccurrences(
            of: "[^A-Za-z0-9]+",
            with: "_",
            options: .regularExpression
        )
        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

private struct PretMapMatrix {
    let width: Int
    let height: Int
    let models: [Int]

    init(data: Data) throws {
        guard data.count >= 5 else {
            throw PretNormalizationError.malformedMapMatrix("Expected at least 5 bytes, found \(data.count).")
        }

        width = Int(data[0])
        height = Int(data[1])
        let hasHeaders = data[2] != 0
        let hasAltitudes = data[3] != 0
        let nameLength = Int(data[4])
        let cellCount = width * height
        var offset = 5 + nameLength

        let headerBytes = hasHeaders ? cellCount * 2 : 0
        let altitudeBytes = hasAltitudes ? cellCount : 0
        let modelBytes = cellCount * 2

        guard width > 0, height > 0 else {
            throw PretNormalizationError.malformedMapMatrix("Matrix dimensions must be positive, found \(width)x\(height).")
        }
        guard data.count >= offset + headerBytes + altitudeBytes + modelBytes else {
            throw PretNormalizationError.malformedMapMatrix(
                "Matrix payload is truncated for \(width)x\(height) cells."
            )
        }

        offset += headerBytes + altitudeBytes
        var models: [Int] = []
        models.reserveCapacity(cellCount)

        for cell in 0..<cellCount {
            models.append(Int(readUInt16LE(from: data, at: offset + (cell * 2))))
        }

        self.models = models
    }

    func modelIndex(atCellX cellX: Int, cellZ: Int, mapID: String) throws -> Int {
        guard cellX >= 0, cellX < width, cellZ >= 0, cellZ < height else {
            throw PretNormalizationError.invalidCollisionMatrixCell(mapID: mapID, cellX: cellX, cellZ: cellZ)
        }

        let modelIndex = models[(cellZ * width) + cellX]
        guard modelIndex != Int(UInt16.max) else {
            throw PretNormalizationError.invalidCollisionModelReference(
                mapID: mapID,
                cellX: cellX,
                cellZ: cellZ,
                modelIndex: modelIndex
            )
        }

        return modelIndex
    }
}

private struct PretNARCArchive {
    struct MemberRange {
        let start: Int
        let end: Int
    }

    let data: Data
    let members: [MemberRange]
    let memberDataStart: Int

    init(data: Data) throws {
        let headerSize = 16
        guard data.count >= headerSize else {
            throw PretNormalizationError.malformedCollisionArchive("File is smaller than the NARC header.")
        }
        guard asciiString(in: data, at: 0, length: 4) == "NARC" else {
            throw PretNormalizationError.malformedCollisionArchive("Missing NARC header magic.")
        }

        let btafOffset = headerSize
        guard asciiString(in: data, at: btafOffset, length: 4) == "BTAF" else {
            throw PretNormalizationError.malformedCollisionArchive("Missing BTAF chunk.")
        }

        let btafSize = Int(readUInt32LE(from: data, at: btafOffset + 4))
        let fileCount = Int(readUInt16LE(from: data, at: btafOffset + 8))
        let btafEntriesOffset = btafOffset + 12
        let btafEntriesSize = fileCount * 8
        guard data.count >= btafEntriesOffset + btafEntriesSize else {
            throw PretNormalizationError.malformedCollisionArchive("BTAF entries are truncated.")
        }

        let btnfOffset = btafOffset + btafSize
        guard data.count >= btnfOffset + 8, asciiString(in: data, at: btnfOffset, length: 4) == "BTNF" else {
            throw PretNormalizationError.malformedCollisionArchive("Missing BTNF chunk.")
        }

        let btnfSize = Int(readUInt32LE(from: data, at: btnfOffset + 4))
        let gmifOffset = btnfOffset + btnfSize
        guard data.count >= gmifOffset + 8, asciiString(in: data, at: gmifOffset, length: 4) == "GMIF" else {
            throw PretNormalizationError.malformedCollisionArchive("Missing GMIF chunk.")
        }

        memberDataStart = gmifOffset + 8
        guard data.count >= memberDataStart else {
            throw PretNormalizationError.malformedCollisionArchive("GMIF payload is truncated.")
        }

        var members: [MemberRange] = []
        members.reserveCapacity(fileCount)

        for fileIndex in 0..<fileCount {
            let entryOffset = btafEntriesOffset + (fileIndex * 8)
            let start = Int(readUInt32LE(from: data, at: entryOffset))
            let end = Int(readUInt32LE(from: data, at: entryOffset + 4))
            guard start <= end else {
                throw PretNormalizationError.malformedCollisionArchive(
                    "BTAF entry \(fileIndex) has invalid byte range \(start)..<\(end)."
                )
            }
            members.append(MemberRange(start: start, end: end))
        }

        self.data = data
        self.members = members
    }

    func member(at index: Int, mapID: String) throws -> Data {
        guard index >= 0, index < members.count else {
            throw PretNormalizationError.missingCollisionModel(mapID: mapID, modelIndex: index)
        }

        let member = members[index]
        guard data.count >= memberDataStart + member.end else {
            throw PretNormalizationError.malformedCollisionArchive(
                "Member \(index) exceeds the GMIF payload bounds."
            )
        }

        return data.subdata(in: (memberDataStart + member.start)..<(memberDataStart + member.end))
    }
}

private struct PretCollisionPermissionTable {
    let permissionBytes: Data

    init(data: Data) throws {
        guard data.count >= PretCollisionConstants.collisionHeaderSize + PretCollisionConstants.permissionSectionSize else {
            throw PretNormalizationError.malformedCollisionArchive(
                "Collision model is too small for a 32x32 permission table."
            )
        }

        let sectionSize = Int(readUInt32LE(from: data, at: 0))
        guard sectionSize >= PretCollisionConstants.permissionSectionSize else {
            throw PretNormalizationError.malformedCollisionArchive(
                "Collision model permission section is \(sectionSize) bytes, expected at least \(PretCollisionConstants.permissionSectionSize)."
            )
        }

        let permissionStart = PretCollisionConstants.collisionHeaderSize
        let permissionEnd = permissionStart + PretCollisionConstants.permissionSectionSize
        permissionBytes = data.subdata(in: permissionStart..<permissionEnd)
    }

    func permission(atMapTileX mapTileX: Int, mapTileZ: Int) throws -> UInt16 {
        let size = PretCollisionConstants.collisionModelTileWidth
        guard mapTileX >= 0, mapTileX < size, mapTileZ >= 0, mapTileZ < size else {
            throw PretNormalizationError.malformedCollisionArchive(
                "Collision tile request (\(mapTileX), \(mapTileZ)) is outside the 32x32 map model."
            )
        }

        // HGSS stores each 32x32 permission plane bottom-to-top in the serialized map model.
        let storedRow = (size - 1) - mapTileZ
        let offset = ((storedRow * size) + mapTileX) * 2
        return readUInt16LE(from: permissionBytes, at: offset)
    }
}

private func asciiString(in data: Data, at offset: Int, length: Int) -> String {
    guard data.count >= offset + length else {
        return ""
    }
    return String(decoding: data[offset..<(offset + length)], as: UTF8.self)
}

private func readUInt16LE(from data: Data, at offset: Int) -> UInt16 {
    UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

private func readUInt32LE(from data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset])
        | (UInt32(data[offset + 1]) << 8)
        | (UInt32(data[offset + 2]) << 16)
        | (UInt32(data[offset + 3]) << 24)
}

private struct PretZoneEvents: Codable {
    struct BackgroundEvent: Codable {
        let scriptId: PretScalar
        let type: Int
        let x: Int
        let z: Int
        let y: Int
    }

    struct ObjectEvent: Codable {
        let id: String
        let scriptId: PretScalar
        let x: Int
        let z: Int
        let y: Int
    }

    struct WarpEvent: Codable {
        let x: Int
        let z: Int
        let header: String
        let anchor: Int
        let y: Int
    }

    struct CoordinateEvent: Codable {
        let scriptId: PretScalar
        let x: Int
        let z: Int
        let w: Int
        let h: Int
        let y: Int
        let variable: String

        enum CodingKeys: String, CodingKey {
            case scriptId
            case x
            case z
            case w
            case h
            case y
            case variable = "var"
        }
    }

    let bgs: [BackgroundEvent]
    let objects: [ObjectEvent]
    let warps: [WarpEvent]
    let coords: [CoordinateEvent]
}

private enum PretScalar: Codable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        throw DecodingError.typeMismatch(
            PretScalar.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or int scalar.")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        }
    }

    var reference: String? {
        switch self {
        case let .string(value):
            return value
        case .int(0):
            return nil
        case let .int(value):
            return String(value)
        }
    }
}
