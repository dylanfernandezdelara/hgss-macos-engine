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
        }
    }
}

public struct PretNewBarkNormalizer {
    public init() {}

    public func buildManifest(
        from profileManifest: HGSSManifest,
        mapHeadersText: String,
        zoneEventData: Data,
        mapID: String = "MAP_NEW_BARK"
    ) throws -> HGSSManifest {
        guard let profileMap = profileManifest.maps.first(where: { $0.mapID == mapID }) else {
            throw PretNormalizationError.missingProfileMap(mapID)
        }

        let headerFields = try parseMapHeaderFields(mapHeadersText: mapHeadersText, mapID: mapID)
        let zoneEvents = try decodeZoneEvents(data: zoneEventData)
        let allowedDestinationMapIDs = Set(profileManifest.maps.map(\.mapID))

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
            collision: profileMap.collision,
            entryPoints: profileMap.entryPoints,
            warps: buildWarps(
                from: zoneEvents.warps,
                layout: profileMap.layout,
                allowedDestinationMapIDs: allowedDestinationMapIDs
            ),
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
            notes: profileManifest.notes
        )
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
        layout: HGSSManifest.MapLayout,
        allowedDestinationMapIDs: Set<String>
    ) -> [HGSSManifest.Warp] {
        let filtered = warps.filter {
            contains(sourceX: $0.x, sourceZ: $0.z, layout: layout) &&
            allowedDestinationMapIDs.contains($0.header)
        }
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
