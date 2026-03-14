import Foundation
import HGSSDataModel

public struct NormalizedTileCoordinate: Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    init(_ point: HGSSManifest.GridPoint) {
        self.init(x: point.x, y: point.y)
    }
}

public struct NormalizedSourceCoordinate: Hashable, Sendable {
    public let x: Int
    public let z: Int
    public let y: Int

    public init(x: Int, z: Int, y: Int) {
        self.x = x
        self.z = z
        self.y = y
    }

    init(_ point: HGSSManifest.SourcePoint) {
        self.init(x: point.x, z: point.z, y: point.y)
    }
}

public struct NormalizedMapProvenance: Equatable, Sendable {
    public let upstreamMapID: String
    public let mapHeaderSymbol: String
    public let matrixID: String
    public let eventsBank: String
}

public struct NormalizedMapHeader: Equatable, Sendable {
    public let wildEncounterBank: String
    public let areaDataBank: Int
    public let moveModelBank: Int
    public let worldMapX: Int
    public let worldMapY: Int
    public let mapSection: String
    public let mapType: String
    public let followMode: String
    public let bikeAllowed: Bool
    public let flyAllowed: Bool
    public let isKanto: Bool
    public let weather: Int
    public let cameraType: Int
}

public struct NormalizedMapEntryPoint: Equatable, Sendable {
    public let id: String
    public let localPosition: NormalizedTileCoordinate
    public let facing: String?
    public let summary: String
}

public struct NormalizedMapWarp: Equatable, Sendable {
    public let id: String
    public let localPosition: NormalizedTileCoordinate
    public let sourcePosition: NormalizedSourceCoordinate
    public let destinationMapID: String
    public let destinationAnchor: Int
    public let summary: String
}

public enum NormalizedPlacementKind: String, Equatable, Sendable {
    case object
    case coordinateTrigger
    case backgroundEvent
}

public struct NormalizedMapPlacement: Equatable, Sendable {
    public let id: String
    public let kind: NormalizedPlacementKind
    public let localPosition: NormalizedTileCoordinate
    public let sourcePosition: NormalizedSourceCoordinate
    public let width: Int
    public let height: Int
    public let scriptReference: String?
    public let summary: String

    public var occupiedTiles: Set<NormalizedTileCoordinate> {
        var tiles: Set<NormalizedTileCoordinate> = []
        for y in localPosition.y..<(localPosition.y + height) {
            for x in localPosition.x..<(localPosition.x + width) {
                tiles.insert(NormalizedTileCoordinate(x: x, y: y))
            }
        }
        return tiles
    }
}

public struct NormalizedPlayableMap: Sendable {
    public let id: String
    public let displayName: String
    public let provenance: NormalizedMapProvenance
    public let header: NormalizedMapHeader
    public let width: Int
    public let height: Int
    public let sourceOrigin: NormalizedSourceCoordinate
    public let blockedTiles: Set<NormalizedTileCoordinate>
    public let entryPoints: [NormalizedMapEntryPoint]
    public let warps: [NormalizedMapWarp]
    public let placements: [NormalizedMapPlacement]
    public let warpTiles: Set<NormalizedTileCoordinate>
    public let placementTiles: Set<NormalizedTileCoordinate>

    private let entryPointsByID: [String: NormalizedMapEntryPoint]

    public init(
        id: String,
        displayName: String,
        provenance: NormalizedMapProvenance,
        header: NormalizedMapHeader,
        width: Int,
        height: Int,
        sourceOrigin: NormalizedSourceCoordinate,
        blockedTiles: Set<NormalizedTileCoordinate>,
        entryPoints: [NormalizedMapEntryPoint],
        warps: [NormalizedMapWarp],
        placements: [NormalizedMapPlacement]
    ) {
        self.id = id
        self.displayName = displayName
        self.provenance = provenance
        self.header = header
        self.width = width
        self.height = height
        self.sourceOrigin = sourceOrigin
        self.blockedTiles = blockedTiles
        self.entryPoints = entryPoints
        self.warps = warps
        self.placements = placements
        self.entryPointsByID = Dictionary(uniqueKeysWithValues: entryPoints.map { ($0.id, $0) })
        self.warpTiles = Set(warps.map(\.localPosition))
        self.placementTiles = placements.reduce(into: Set<NormalizedTileCoordinate>()) { partialResult, placement in
            partialResult.formUnion(placement.occupiedTiles)
        }
    }

    public func contains(_ tile: NormalizedTileCoordinate) -> Bool {
        tile.x >= 0 && tile.x < width && tile.y >= 0 && tile.y < height
    }

    public func isBlocked(_ tile: NormalizedTileCoordinate) -> Bool {
        blockedTiles.contains(tile)
    }

    public func entryPoint(id: String) -> NormalizedMapEntryPoint? {
        entryPointsByID[id]
    }
}

public struct NormalizedWorldContent: Sendable {
    public let manifest: HGSSManifest
    public let maps: [NormalizedPlayableMap]
    public let initialMapID: String
    public let initialEntryPointID: String

    private let mapsByID: [String: NormalizedPlayableMap]

    public var initialMap: NormalizedPlayableMap {
        mapsByID[initialMapID]!
    }

    public var initialEntryPoint: NormalizedMapEntryPoint {
        initialMap.entryPoint(id: initialEntryPointID)!
    }

    public init(manifest: HGSSManifest) throws {
        guard !manifest.maps.isEmpty else {
            throw HGSSContentError.noMapsDefined
        }

        var seenMapIDs = Set<String>()
        var builtMaps: [NormalizedPlayableMap] = []
        var builtLookup: [String: NormalizedPlayableMap] = [:]

        for map in manifest.maps {
            guard seenMapIDs.insert(map.mapID).inserted else {
                throw HGSSContentError.duplicateMapID(map.mapID)
            }

            guard map.layout.width > 0, map.layout.height > 0 else {
                throw HGSSContentError.invalidMapBounds(
                    mapID: map.mapID,
                    width: map.layout.width,
                    height: map.layout.height
                )
            }

            let origin = NormalizedSourceCoordinate(map.layout.sourceOrigin)

            let blockedTiles = try Self.buildBlockedTiles(map: map)
            let entryPoints = try Self.buildEntryPoints(map: map)
            let warps = try Self.buildWarps(map: map, origin: origin, width: map.layout.width, height: map.layout.height)
            let placements = try Self.buildPlacements(
                map: map,
                origin: origin,
                width: map.layout.width,
                height: map.layout.height
            )

            let playableMap = NormalizedPlayableMap(
                id: map.mapID,
                displayName: map.displayName,
                provenance: NormalizedMapProvenance(
                    upstreamMapID: map.provenance.upstreamMapID,
                    mapHeaderSymbol: map.provenance.mapHeaderSymbol,
                    matrixID: map.provenance.matrixID,
                    eventsBank: map.provenance.eventsBank
                ),
                header: NormalizedMapHeader(
                    wildEncounterBank: map.header.wildEncounterBank,
                    areaDataBank: map.header.areaDataBank,
                    moveModelBank: map.header.moveModelBank,
                    worldMapX: map.header.worldMapX,
                    worldMapY: map.header.worldMapY,
                    mapSection: map.header.mapSection,
                    mapType: map.header.mapType,
                    followMode: map.header.followMode,
                    bikeAllowed: map.header.bikeAllowed,
                    flyAllowed: map.header.flyAllowed,
                    isKanto: map.header.isKanto,
                    weather: map.header.weather,
                    cameraType: map.header.cameraType
                ),
                width: map.layout.width,
                height: map.layout.height,
                sourceOrigin: origin,
                blockedTiles: blockedTiles,
                entryPoints: entryPoints,
                warps: warps,
                placements: placements
            )

            builtMaps.append(playableMap)
            builtLookup[playableMap.id] = playableMap
        }

        guard let initialMap = builtLookup[manifest.initialMapID] else {
            throw HGSSContentError.missingInitialMap(manifest.initialMapID)
        }

        guard initialMap.entryPoint(id: manifest.initialEntryPointID) != nil else {
            throw HGSSContentError.missingInitialEntryPoint(
                mapID: manifest.initialMapID,
                entryPointID: manifest.initialEntryPointID
            )
        }

        self.manifest = manifest
        self.maps = builtMaps
        self.initialMapID = manifest.initialMapID
        self.initialEntryPointID = manifest.initialEntryPointID
        self.mapsByID = builtLookup
    }

    public func map(id: String) -> NormalizedPlayableMap? {
        mapsByID[id]
    }

    private static func buildBlockedTiles(map: HGSSManifest.MapEntry) throws -> Set<NormalizedTileCoordinate> {
        let blockedTiles = Set(map.collision.impassableTiles.map(NormalizedTileCoordinate.init))
        for tile in blockedTiles {
            guard contains(tile, width: map.layout.width, height: map.layout.height) else {
                throw HGSSContentError.invalidBlockedTile(mapID: map.mapID, x: tile.x, y: tile.y)
            }
        }
        return blockedTiles
    }

    private static func buildEntryPoints(map: HGSSManifest.MapEntry) throws -> [NormalizedMapEntryPoint] {
        var seenIDs = Set<String>()
        var entryPoints: [NormalizedMapEntryPoint] = []

        for entryPoint in map.entryPoints {
            guard seenIDs.insert(entryPoint.id).inserted else {
                throw HGSSContentError.duplicateEntryPointID(mapID: map.mapID, entryPointID: entryPoint.id)
            }

            let localPosition = NormalizedTileCoordinate(entryPoint.localPosition)
            guard contains(localPosition, width: map.layout.width, height: map.layout.height) else {
                throw HGSSContentError.invalidEntryPoint(
                    mapID: map.mapID,
                    entryPointID: entryPoint.id,
                    x: localPosition.x,
                    y: localPosition.y
                )
            }

            entryPoints.append(
                NormalizedMapEntryPoint(
                    id: entryPoint.id,
                    localPosition: localPosition,
                    facing: entryPoint.facing,
                    summary: entryPoint.summary
                )
            )
        }

        return entryPoints
    }

    private static func buildWarps(
        map: HGSSManifest.MapEntry,
        origin: NormalizedSourceCoordinate,
        width: Int,
        height: Int
    ) throws -> [NormalizedMapWarp] {
        var seenIDs = Set<String>()
        var warps: [NormalizedMapWarp] = []

        for warp in map.warps {
            guard seenIDs.insert(warp.id).inserted else {
                throw HGSSContentError.duplicateWarpID(mapID: map.mapID, warpID: warp.id)
            }

            let localPosition = NormalizedTileCoordinate(warp.localPosition)
            guard contains(localPosition, width: width, height: height) else {
                throw HGSSContentError.invalidWarpTile(
                    mapID: map.mapID,
                    warpID: warp.id,
                    x: localPosition.x,
                    y: localPosition.y
                )
            }

            let sourcePosition = NormalizedSourceCoordinate(warp.sourcePosition)
            guard normalizedTile(for: sourcePosition, origin: origin) == localPosition else {
                throw HGSSContentError.invalidWarpNormalization(mapID: map.mapID, warpID: warp.id)
            }

            warps.append(
                NormalizedMapWarp(
                    id: warp.id,
                    localPosition: localPosition,
                    sourcePosition: sourcePosition,
                    destinationMapID: warp.destinationMapID,
                    destinationAnchor: warp.destinationAnchor,
                    summary: warp.summary
                )
            )
        }

        return warps
    }

    private static func buildPlacements(
        map: HGSSManifest.MapEntry,
        origin: NormalizedSourceCoordinate,
        width: Int,
        height: Int
    ) throws -> [NormalizedMapPlacement] {
        var seenIDs = Set<String>()
        var placements: [NormalizedMapPlacement] = []

        for placement in map.placements {
            guard seenIDs.insert(placement.id).inserted else {
                throw HGSSContentError.duplicatePlacementID(mapID: map.mapID, placementID: placement.id)
            }

            guard placement.width > 0, placement.height > 0 else {
                throw HGSSContentError.invalidPlacementSize(
                    mapID: map.mapID,
                    placementID: placement.id,
                    width: placement.width,
                    height: placement.height
                )
            }

            let localPosition = NormalizedTileCoordinate(placement.localPosition)
            let maxTile = NormalizedTileCoordinate(
                x: localPosition.x + placement.width - 1,
                y: localPosition.y + placement.height - 1
            )
            guard contains(localPosition, width: width, height: height), contains(maxTile, width: width, height: height) else {
                throw HGSSContentError.invalidPlacementTile(
                    mapID: map.mapID,
                    placementID: placement.id,
                    x: localPosition.x,
                    y: localPosition.y
                )
            }

            let sourcePosition = NormalizedSourceCoordinate(placement.sourcePosition)
            guard normalizedTile(for: sourcePosition, origin: origin) == localPosition else {
                throw HGSSContentError.invalidPlacementNormalization(mapID: map.mapID, placementID: placement.id)
            }

            let kind = NormalizedPlacementKind(rawValue: placement.kind.rawValue)!
            placements.append(
                NormalizedMapPlacement(
                    id: placement.id,
                    kind: kind,
                    localPosition: localPosition,
                    sourcePosition: sourcePosition,
                    width: placement.width,
                    height: placement.height,
                    scriptReference: placement.scriptReference,
                    summary: placement.summary
                )
            )
        }

        return placements
    }

    private static func normalizedTile(
        for sourcePosition: NormalizedSourceCoordinate,
        origin: NormalizedSourceCoordinate
    ) -> NormalizedTileCoordinate {
        NormalizedTileCoordinate(
            x: sourcePosition.x - origin.x,
            y: sourcePosition.z - origin.z
        )
    }

    private static func contains(
        _ tile: NormalizedTileCoordinate,
        width: Int,
        height: Int
    ) -> Bool {
        tile.x >= 0 && tile.x < width && tile.y >= 0 && tile.y < height
    }
}
