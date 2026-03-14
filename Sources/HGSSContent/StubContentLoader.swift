import Foundation
import HGSSDataModel

public enum HGSSContentError: LocalizedError {
    case manifestMissing(path: String)
    case manifestDecodeFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case let .manifestMissing(path):
            return "Missing stub manifest at \(path)."
        case let .manifestDecodeFailed(underlying):
            return "Failed to decode stub manifest: \(underlying.localizedDescription)"
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
}
