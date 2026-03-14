import Foundation

public struct HGSSManifest: Codable, Equatable, Sendable {
    public struct MapEntry: Codable, Equatable, Sendable {
        public let id: String
        public let displayName: String

        public init(id: String, displayName: String) {
            self.id = id
            self.displayName = displayName
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
    public let maps: [MapEntry]
    public let pokemon: [PokemonEntry]
    public let notes: String

    public init(
        schemaVersion: Int,
        title: String,
        build: String,
        maps: [MapEntry],
        pokemon: [PokemonEntry],
        notes: String
    ) {
        self.schemaVersion = schemaVersion
        self.title = title
        self.build = build
        self.maps = maps
        self.pokemon = pokemon
        self.notes = notes
    }
}
