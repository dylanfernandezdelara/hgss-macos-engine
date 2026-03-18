import Foundation
import HGSSDataModel

public struct LoadedOpeningBundle: Equatable, Sendable {
    public let rootURL: URL
    public let bundle: HGSSOpeningBundle

    private let assetPaths: [String: String]

    init(rootURL: URL, bundle: HGSSOpeningBundle, assetPaths: [String: String]) {
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

    public func scene(id: HGSSOpeningBundle.SceneID) -> HGSSOpeningBundle.Scene? {
        bundle.scenes.first(where: { $0.id == id })
    }
}

public struct OpeningBundleLoader {
    public init() {}

    public func load(from rootURL: URL) throws -> LoadedOpeningBundle {
        let bundleURL = rootURL.appendingPathComponent("opening_bundle.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: bundleURL.path()) else {
            throw HGSSRenderError.openingBundleMissing(path: bundleURL.path())
        }

        let data = try Data(contentsOf: bundleURL)
        let bundle: HGSSOpeningBundle
        do {
            bundle = try JSONDecoder().decode(HGSSOpeningBundle.self, from: data)
        } catch {
            throw HGSSRenderError.openingBundleDecodeFailed(underlying: error)
        }

        try validateSceneOrder(bundle.scenes)

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

        return LoadedOpeningBundle(rootURL: rootURL, bundle: bundle, assetPaths: assetPaths)
    }

    private func validateSceneOrder(_ scenes: [HGSSOpeningBundle.Scene]) throws {
        let expected = HGSSOpeningBundle.SceneID.allCases
        let actual = scenes.map(\.id)
        guard actual == expected else {
            throw HGSSRenderError.invalidOpeningSceneOrder(
                expected: expected.map(\.rawValue),
                actual: actual.map(\.rawValue)
            )
        }

        guard let titleHandoff = scenes.last, titleHandoff.id == .titleHandoff, titleHandoff.durationFrames == 1 else {
            throw HGSSRenderError.invalidTitleHandoffDuration
        }

        for scene in scenes {
            if let skipAllowedFromFrame = scene.skipAllowedFromFrame,
               skipAllowedFromFrame < 0 || skipAllowedFromFrame >= scene.durationFrames
            {
                throw HGSSRenderError.invalidOpeningSkipWindow(
                    sceneID: scene.id.rawValue,
                    skipAllowedFromFrame: skipAllowedFromFrame,
                    durationFrames: scene.durationFrames
                )
            }
        }
    }

    private func referencedAssetIDs(in bundle: HGSSOpeningBundle) -> [String] {
        var referenced: [String] = []
        for scene in bundle.scenes {
            referenced.append(contentsOf: scene.topLayers.map(\.assetID))
            referenced.append(contentsOf: scene.bottomLayers.map(\.assetID))
            referenced.append(contentsOf: scene.spriteAnimations.flatMap(\.frameAssetIDs))
            referenced.append(contentsOf: scene.modelAnimations.map(\.assetID))
            referenced.append(contentsOf: scene.audioCues.compactMap(\.playableAssetID))
        }
        return referenced
    }
}
