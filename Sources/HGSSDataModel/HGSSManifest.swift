import Foundation

public struct HGSSManifest: Codable, Equatable, Sendable {
    public struct GridPoint: Codable, Equatable, Hashable, Sendable {
        public let x: Int
        public let y: Int

        public init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
    }

    public struct SourcePoint: Codable, Equatable, Hashable, Sendable {
        public let x: Int
        public let z: Int
        public let y: Int

        public init(x: Int, z: Int, y: Int) {
            self.x = x
            self.z = z
            self.y = y
        }
    }

    public struct MapProvenance: Codable, Equatable, Sendable {
        public let upstreamMapID: String
        public let mapHeaderSymbol: String
        public let matrixID: String
        public let eventsBank: String

        public init(upstreamMapID: String, mapHeaderSymbol: String, matrixID: String, eventsBank: String) {
            self.upstreamMapID = upstreamMapID
            self.mapHeaderSymbol = mapHeaderSymbol
            self.matrixID = matrixID
            self.eventsBank = eventsBank
        }
    }

    public struct MapHeaderMetadata: Codable, Equatable, Sendable {
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

        public init(
            wildEncounterBank: String,
            areaDataBank: Int,
            moveModelBank: Int,
            worldMapX: Int,
            worldMapY: Int,
            mapSection: String,
            mapType: String,
            followMode: String,
            bikeAllowed: Bool,
            flyAllowed: Bool,
            isKanto: Bool,
            weather: Int,
            cameraType: Int
        ) {
            self.wildEncounterBank = wildEncounterBank
            self.areaDataBank = areaDataBank
            self.moveModelBank = moveModelBank
            self.worldMapX = worldMapX
            self.worldMapY = worldMapY
            self.mapSection = mapSection
            self.mapType = mapType
            self.followMode = followMode
            self.bikeAllowed = bikeAllowed
            self.flyAllowed = flyAllowed
            self.isKanto = isKanto
            self.weather = weather
            self.cameraType = cameraType
        }
    }

    public struct MapLayout: Codable, Equatable, Sendable {
        public let width: Int
        public let height: Int
        public let sourceOrigin: SourcePoint

        public init(width: Int, height: Int, sourceOrigin: SourcePoint) {
            self.width = width
            self.height = height
            self.sourceOrigin = sourceOrigin
        }
    }

    public struct CollisionLayer: Codable, Equatable, Sendable {
        public let impassableTiles: [GridPoint]

        public init(impassableTiles: [GridPoint]) {
            self.impassableTiles = impassableTiles
        }
    }

    public struct EntryPoint: Codable, Equatable, Sendable {
        public let id: String
        public let localPosition: GridPoint
        public let facing: String?
        public let summary: String

        public init(id: String, localPosition: GridPoint, facing: String?, summary: String) {
            self.id = id
            self.localPosition = localPosition
            self.facing = facing
            self.summary = summary
        }
    }

    public struct Warp: Codable, Equatable, Sendable {
        public let id: String
        public let localPosition: GridPoint
        public let sourcePosition: SourcePoint
        public let destinationMapID: String
        public let destinationAnchor: Int
        public let summary: String

        public init(
            id: String,
            localPosition: GridPoint,
            sourcePosition: SourcePoint,
            destinationMapID: String,
            destinationAnchor: Int,
            summary: String
        ) {
            self.id = id
            self.localPosition = localPosition
            self.sourcePosition = sourcePosition
            self.destinationMapID = destinationMapID
            self.destinationAnchor = destinationAnchor
            self.summary = summary
        }
    }

    public enum PlacementKind: String, Codable, Equatable, Sendable {
        case object
        case coordinateTrigger
        case backgroundEvent
    }

    public struct Placement: Codable, Equatable, Sendable {
        public let id: String
        public let kind: PlacementKind
        public let localPosition: GridPoint
        public let sourcePosition: SourcePoint
        public let width: Int
        public let height: Int
        public let scriptReference: String?
        public let summary: String

        public init(
            id: String,
            kind: PlacementKind,
            localPosition: GridPoint,
            sourcePosition: SourcePoint,
            width: Int,
            height: Int,
            scriptReference: String?,
            summary: String
        ) {
            self.id = id
            self.kind = kind
            self.localPosition = localPosition
            self.sourcePosition = sourcePosition
            self.width = width
            self.height = height
            self.scriptReference = scriptReference
            self.summary = summary
        }
    }

    public struct MapEntry: Codable, Equatable, Sendable {
        public let mapID: String
        public let displayName: String
        public let provenance: MapProvenance
        public let header: MapHeaderMetadata
        public let layout: MapLayout
        public let collision: CollisionLayer
        public let entryPoints: [EntryPoint]
        public let warps: [Warp]
        public let placements: [Placement]

        public init(
            mapID: String,
            displayName: String,
            provenance: MapProvenance,
            header: MapHeaderMetadata,
            layout: MapLayout,
            collision: CollisionLayer,
            entryPoints: [EntryPoint],
            warps: [Warp],
            placements: [Placement]
        ) {
            self.mapID = mapID
            self.displayName = displayName
            self.provenance = provenance
            self.header = header
            self.layout = layout
            self.collision = collision
            self.entryPoints = entryPoints
            self.warps = warps
            self.placements = placements
        }
    }

    public struct PokemonEntry: Codable, Equatable, Sendable {
        public let species: String
        public let nationalDex: Int

        public init(species: String, nationalDex: Int) {
            self.species = species
            self.nationalDex = nationalDex
        }
    }

    public let schemaVersion: Int
    public let title: String
    public let build: String
    public let initialMapID: String
    public let initialEntryPointID: String
    public let maps: [MapEntry]
    public let pokemon: [PokemonEntry]
    public let notes: String

    public init(
        schemaVersion: Int,
        title: String,
        build: String,
        initialMapID: String,
        initialEntryPointID: String,
        maps: [MapEntry],
        pokemon: [PokemonEntry],
        notes: String
    ) {
        self.schemaVersion = schemaVersion
        self.title = title
        self.build = build
        self.initialMapID = initialMapID
        self.initialEntryPointID = initialEntryPointID
        self.maps = maps
        self.pokemon = pokemon
        self.notes = notes
    }
}
