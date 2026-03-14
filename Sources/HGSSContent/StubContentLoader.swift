import Foundation
import HGSSDataModel

public enum HGSSContentError: LocalizedError {
    case manifestMissing(path: String)
    case manifestDecodeFailed(underlying: Error)
    case noMapsDefined
    case missingInitialMap(String)
    case missingInitialEntryPoint(mapID: String, entryPointID: String)
    case duplicateMapID(String)
    case invalidMapBounds(mapID: String, width: Int, height: Int)
    case duplicateEntryPointID(mapID: String, entryPointID: String)
    case invalidEntryPoint(mapID: String, entryPointID: String, x: Int, y: Int)
    case invalidBlockedTile(mapID: String, x: Int, y: Int)
    case duplicateWarpID(mapID: String, warpID: String)
    case invalidWarpTile(mapID: String, warpID: String, x: Int, y: Int)
    case invalidWarpNormalization(mapID: String, warpID: String)
    case duplicatePlacementID(mapID: String, placementID: String)
    case invalidPlacementSize(mapID: String, placementID: String, width: Int, height: Int)
    case invalidPlacementTile(mapID: String, placementID: String, x: Int, y: Int)
    case invalidPlacementNormalization(mapID: String, placementID: String)

    public var errorDescription: String? {
        switch self {
        case let .manifestMissing(path):
            return "Missing stub manifest at \(path)."
        case let .manifestDecodeFailed(underlying):
            return "Failed to decode stub manifest: \(underlying.localizedDescription)"
        case .noMapsDefined:
            return "Stub manifest must define at least one playable map."
        case let .missingInitialMap(mapID):
            return "Stub manifest declares initial map '\(mapID)' but does not define it."
        case let .missingInitialEntryPoint(mapID, entryPointID):
            return "Map '\(mapID)' does not define initial entry point '\(entryPointID)'."
        case let .duplicateMapID(mapID):
            return "Stub manifest defines duplicate map id '\(mapID)'."
        case let .invalidMapBounds(mapID, width, height):
            return "Map '\(mapID)' must have positive bounds, got \(width)x\(height)."
        case let .duplicateEntryPointID(mapID, entryPointID):
            return "Map '\(mapID)' defines duplicate entry point '\(entryPointID)'."
        case let .invalidEntryPoint(mapID, entryPointID, x, y):
            return "Map '\(mapID)' has out-of-bounds entry point '\(entryPointID)' at (\(x), \(y))."
        case let .invalidBlockedTile(mapID, x, y):
            return "Map '\(mapID)' has out-of-bounds impassable tile (\(x), \(y))."
        case let .duplicateWarpID(mapID, warpID):
            return "Map '\(mapID)' defines duplicate warp '\(warpID)'."
        case let .invalidWarpTile(mapID, warpID, x, y):
            return "Map '\(mapID)' has out-of-bounds warp '\(warpID)' at (\(x), \(y))."
        case let .invalidWarpNormalization(mapID, warpID):
            return "Map '\(mapID)' has warp '\(warpID)' whose source coordinates do not normalize to the declared local tile."
        case let .duplicatePlacementID(mapID, placementID):
            return "Map '\(mapID)' defines duplicate placement '\(placementID)'."
        case let .invalidPlacementSize(mapID, placementID, width, height):
            return "Map '\(mapID)' placement '\(placementID)' must have positive size, got \(width)x\(height)."
        case let .invalidPlacementTile(mapID, placementID, x, y):
            return "Map '\(mapID)' has out-of-bounds placement '\(placementID)' at (\(x), \(y))."
        case let .invalidPlacementNormalization(mapID, placementID):
            return "Map '\(mapID)' has placement '\(placementID)' whose source coordinates do not normalize to the declared local tile."
        }
    }
}

public struct StubContentLoader {
    public init() {}

    public func loadManifest(from stubRoot: URL) throws -> HGSSManifest {
        let manifestURL = stubRoot.appendingPathComponent("manifest.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: manifestURL.path()) else {
            throw HGSSContentError.manifestMissing(path: manifestURL.path())
        }

        let data = try Data(contentsOf: manifestURL)
        do {
            return try JSONDecoder().decode(HGSSManifest.self, from: data)
        } catch {
            throw HGSSContentError.manifestDecodeFailed(underlying: error)
        }
    }

    public func loadPlayableContent(from stubRoot: URL) throws -> NormalizedWorldContent {
        let manifest = try loadManifest(from: stubRoot)
        return try NormalizedWorldContent(manifest: manifest)
    }
}
