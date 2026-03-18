import Foundation
import HGSSCore
import HGSSDataModel

public enum HGSSRenderError: LocalizedError {
    case bundleMissing(path: String)
    case bundleDecodeFailed(underlying: Error)
    case openingBundleMissing(path: String)
    case openingBundleDecodeFailed(underlying: Error)
    case duplicateAssetID(String)
    case unknownAssetID(String)
    case missingAssetFile(assetID: String, path: String)
    case invalidOpeningSceneOrder(expected: [String], actual: [String])
    case invalidOpeningSkipWindow(sceneID: String, skipAllowedFromFrame: Int, durationFrames: Int)
    case invalidTitleHandoffDuration

    public var errorDescription: String? {
        switch self {
        case let .bundleMissing(path):
            return "Missing render bundle at \(path)."
        case let .bundleDecodeFailed(underlying):
            return "Failed to decode render bundle: \(underlying.localizedDescription)"
        case let .openingBundleMissing(path):
            return "Missing opening bundle at \(path)."
        case let .openingBundleDecodeFailed(underlying):
            return "Failed to decode opening bundle: \(underlying.localizedDescription)"
        case let .duplicateAssetID(assetID):
            return "Render bundle contains duplicate asset id '\(assetID)'."
        case let .unknownAssetID(assetID):
            return "Render bundle does not define asset id '\(assetID)'."
        case let .missingAssetFile(assetID, path):
            return "Render bundle asset '\(assetID)' is missing file '\(path)'."
        case let .invalidOpeningSceneOrder(expected, actual):
            let expectedOrder = expected.joined(separator: ", ")
            let actualOrder = actual.joined(separator: ", ")
            return "Opening bundle scene order mismatch. Expected \(expectedOrder), got \(actualOrder)."
        case let .invalidOpeningSkipWindow(sceneID, skipAllowedFromFrame, durationFrames):
            return "Opening scene '\(sceneID)' has invalid skip frame \(skipAllowedFromFrame) for duration \(durationFrames)."
        case .invalidTitleHandoffDuration:
            return "Opening bundle title handoff must be a one-frame terminal scene."
        }
    }

}

public struct LoadedRenderBundle: Equatable, Sendable {
    public let rootURL: URL
    public let bundle: HGSSRenderBundle

    private let assetPaths: [String: String]

    init(rootURL: URL, bundle: HGSSRenderBundle, assetPaths: [String: String]) {
        self.rootURL = rootURL
        self.bundle = bundle
        self.assetPaths = assetPaths
    }

    public func assetURL(id: String) throws -> URL {
        guard let relativePath = assetPaths[id] else {
            throw HGSSRenderError.unknownAssetID(id)
        }
        return rootURL.appendingPathComponent(relativePath, isDirectory: false)
    }
}

public struct RenderBundleLoader {
    public init() {}

    public func load(from rootURL: URL) throws -> LoadedRenderBundle {
        let bundleURL = rootURL.appendingPathComponent("render_bundle.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: bundleURL.path()) else {
            throw HGSSRenderError.bundleMissing(path: bundleURL.path())
        }

        let data = try Data(contentsOf: bundleURL)
        let bundle: HGSSRenderBundle
        do {
            bundle = try JSONDecoder().decode(HGSSRenderBundle.self, from: data)
        } catch {
            throw HGSSRenderError.bundleDecodeFailed(underlying: error)
        }

        var assetPaths: [String: String] = [:]
        for asset in bundle.assets {
            guard assetPaths[asset.id] == nil else {
                throw HGSSRenderError.duplicateAssetID(asset.id)
            }
            assetPaths[asset.id] = asset.relativePath
        }

        for referencedAssetID in referencedAssetIDs(in: bundle) {
            guard let relativePath = assetPaths[referencedAssetID] else {
                throw HGSSRenderError.unknownAssetID(referencedAssetID)
            }
            let assetURL = rootURL.appendingPathComponent(relativePath, isDirectory: false)
            guard FileManager.default.fileExists(atPath: assetURL.path()) else {
                throw HGSSRenderError.missingAssetFile(assetID: referencedAssetID, path: assetURL.path())
            }
        }

        return LoadedRenderBundle(rootURL: rootURL, bundle: bundle, assetPaths: assetPaths)
    }

    private func referencedAssetIDs(in bundle: HGSSRenderBundle) -> [String] {
        [
            bundle.topScreen.frameAssetID,
            bundle.bottomScreen.frameAssetID,
            bundle.playerSpriteSheet.assetID
        ]
    }
}

public struct HGSSRenderDisplayPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(tile: TilePosition) {
        self.init(x: Double(tile.x), y: Double(tile.y))
    }
}

public struct HGSSDualScreenPresentation: Equatable, Sendable {
    public let snapshot: CoreSnapshot
    public let cameraOrigin: HGSSRenderDisplayPoint
    public let showDeveloperOverlay: Bool

    public init(
        snapshot: CoreSnapshot,
        cameraOrigin: HGSSRenderDisplayPoint,
        showDeveloperOverlay: Bool
    ) {
        self.snapshot = snapshot
        self.cameraOrigin = cameraOrigin
        self.showDeveloperOverlay = showDeveloperOverlay
    }
}

public enum HGSSDualScreenLayout {
    public static func integerScale(
        containerWidth: Double,
        containerHeight: Double,
        nativeWidth: Int,
        topHeight: Int,
        bottomHeight: Int,
        screenGap: Double
    ) -> Int {
        let totalHeight = Double(topHeight + bottomHeight) + screenGap
        let widthScale = Int(floor(containerWidth / Double(nativeWidth)))
        let heightScale = Int(floor(containerHeight / totalHeight))
        return max(1, min(widthScale, heightScale))
    }
}

public enum HGSSRenderCamera {
    public static func clampedOrigin(
        for focus: HGSSRenderDisplayPoint,
        snapshot: CoreSnapshot,
        camera: HGSSRenderBundle.Camera
    ) -> HGSSRenderDisplayPoint {
        let viewportWidth = Double(camera.viewportTilesWide)
        let viewportHeight = Double(camera.viewportTilesHigh)
        let maxX = max(0.0, Double(snapshot.mapWidth) - viewportWidth)
        let maxY = max(0.0, Double(snapshot.mapHeight) - viewportHeight)
        let centeredX = focus.x - ((viewportWidth - 1.0) / 2.0)
        let centeredY = focus.y - ((viewportHeight - 1.0) / 2.0)

        return HGSSRenderDisplayPoint(
            x: min(max(centeredX, 0.0), maxX),
            y: min(max(centeredY, 0.0), maxY)
        )
    }
}
