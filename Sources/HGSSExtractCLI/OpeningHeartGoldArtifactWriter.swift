import Foundation
import HGSSDataModel

struct OpeningProvenanceDocument: Codable, Equatable {
    struct AssetSource: Codable, Equatable {
        let assetID: String
        let upstreamFiles: [String]
    }

    let mode: String
    let canonicalVariant: String
    let pretRoot: String
    let sourceFiles: [String]
    let assetSources: [AssetSource]
    let audioArchive: String
}

struct OpeningExtractReport: Codable, Equatable {
    let mode: String
    let canonicalVariant: String
    let sceneCount: Int
    let assetCount: Int
    let audioCueCount: Int
    let referenceTraceCount: Int
    let outputRoot: String
    let pretRoot: String
}

struct OpeningReferenceDocument: Codable, Equatable {
    struct SceneReference: Codable, Equatable {
        let sceneID: String
        let durationFrames: Int
        let skipAllowedFromFrame: Int?
        let transitionCueIDs: [String]
        let audioCueIDs: [String]
    }

    struct AudioTrace: Codable, Equatable {
        let cueName: String
        let sceneID: String
        let wavRelativePath: String
        let traceRelativePath: String
        let provenance: [String]
    }

    let schemaVersion: Int
    let mode: String
    let canonicalVariant: String
    let sourceFiles: [String]
    let scenes: [SceneReference]
    let audioTraces: [AudioTrace]
}

enum OpeningHeartGoldArtifactError: LocalizedError, Equatable {
    case invalidSceneOrder(expected: [String], actual: [String])
    case missingReferencedAsset(assetID: String, sceneID: String)
    case duplicateAssetID(String)
    case missingAssetFile(assetID: String, path: String)
    case missingReferenceFile(path: String)
    case forbiddenPlaceholder(term: String, field: String)

    var errorDescription: String? {
        switch self {
        case let .invalidSceneOrder(expected, actual):
            return "Opening bundle scene order mismatch. Expected \(expected.joined(separator: ", ")), got \(actual.joined(separator: ", "))."
        case let .missingReferencedAsset(assetID, sceneID):
            return "Opening scene '\(sceneID)' references missing asset '\(assetID)'."
        case let .duplicateAssetID(assetID):
            return "Opening bundle contains duplicate asset id '\(assetID)'."
        case let .missingAssetFile(assetID, path):
            return "Opening asset '\(assetID)' is missing emitted file '\(path)'."
        case let .missingReferenceFile(path):
            return "Opening reference artifact is missing emitted file '\(path)'."
        case let .forbiddenPlaceholder(term, field):
            return "Opening provenance field '\(field)' contains forbidden placeholder term '\(term)'."
        }
    }
}

struct OpeningHeartGoldArtifactWriter {
    static let forbiddenPlaceholderTerms = ["stand-in", "synthetic", "reserved", "pgphone"]

    func write(
        bundle: HGSSOpeningBundle,
        provenance: OpeningProvenanceDocument,
        reference: OpeningReferenceDocument,
        report: OpeningExtractReport,
        outputRoot: URL
    ) throws {
        try validate(bundle: bundle, provenance: provenance, reference: reference, outputRoot: outputRoot)
        try writeJSON(bundle, to: outputRoot.appendingPathComponent("opening_bundle.json", isDirectory: false))
        try writeJSON(provenance, to: outputRoot.appendingPathComponent("opening_provenance.json", isDirectory: false))
        try writeJSON(reference, to: outputRoot.appendingPathComponent("opening_reference.json", isDirectory: false))
        try writeJSON(report, to: outputRoot.appendingPathComponent("opening_extract_report.json", isDirectory: false))
    }

    func validate(
        bundle: HGSSOpeningBundle,
        provenance: OpeningProvenanceDocument,
        reference: OpeningReferenceDocument,
        outputRoot: URL
    ) throws {
        let actualSceneOrder = bundle.scenes.map(\.id.rawValue)
        let expectedSceneOrder = HGSSOpeningBundle.SceneID.allCases.map(\.rawValue)
        guard actualSceneOrder == expectedSceneOrder else {
            throw OpeningHeartGoldArtifactError.invalidSceneOrder(
                expected: expectedSceneOrder,
                actual: actualSceneOrder
            )
        }

        var assetsByID: [String: HGSSOpeningBundle.Asset] = [:]
        for asset in bundle.assets {
            guard assetsByID[asset.id] == nil else {
                throw OpeningHeartGoldArtifactError.duplicateAssetID(asset.id)
            }
            assetsByID[asset.id] = asset

            let assetURL = outputRoot.appendingPathComponent(asset.relativePath, isDirectory: false)
            guard FileManager.default.fileExists(atPath: assetURL.path()) else {
                throw OpeningHeartGoldArtifactError.missingAssetFile(assetID: asset.id, path: assetURL.path())
            }
        }

        for scene in bundle.scenes {
            for assetID in referencedAssetIDs(in: scene) where assetsByID[assetID] == nil {
                throw OpeningHeartGoldArtifactError.missingReferencedAsset(
                    assetID: assetID,
                    sceneID: scene.id.rawValue
                )
            }
        }

        for audioTrace in reference.audioTraces {
            let traceURL = outputRoot.appendingPathComponent(audioTrace.traceRelativePath, isDirectory: false)
            guard FileManager.default.fileExists(atPath: traceURL.path()) else {
                throw OpeningHeartGoldArtifactError.missingReferenceFile(path: traceURL.path())
            }
            let wavURL = outputRoot.appendingPathComponent(audioTrace.wavRelativePath, isDirectory: false)
            guard FileManager.default.fileExists(atPath: wavURL.path()) else {
                throw OpeningHeartGoldArtifactError.missingReferenceFile(path: wavURL.path())
            }
        }

        try validatePlaceholderFree(bundle: bundle, provenance: provenance, reference: reference)
    }

    private func referencedAssetIDs(in scene: HGSSOpeningBundle.Scene) -> [String] {
        scene.topLayers.map(\.assetID) +
        scene.bottomLayers.map(\.assetID) +
        scene.spriteAnimations.flatMap(\.frameAssetIDs) +
        scene.modelAnimations.map(\.assetID) +
        scene.audioCues.compactMap(\.playableAssetID)
    }

    private func validatePlaceholderFree(
        bundle: HGSSOpeningBundle,
        provenance: OpeningProvenanceDocument,
        reference: OpeningReferenceDocument
    ) throws {
        let bundleAssetFields = bundle.assets.map {
            ("bundle.assets[\($0.id)].provenance", $0.provenance)
        }
        let audioCueFields = bundle.scenes.flatMap { scene in
            scene.audioCues.map {
                ("bundle.scenes[\(scene.id.rawValue)].audioCues[\($0.id)].provenance", $0.provenance)
            }
        }
        let sourceFileFields = provenance.sourceFiles.enumerated().map {
            ("opening_provenance.sourceFiles[\($0.offset)]", $0.element)
        }
        let assetSourceFields = provenance.assetSources.flatMap { assetSource in
            assetSource.upstreamFiles.enumerated().map {
                ("opening_provenance.assetSources[\(assetSource.assetID)].upstreamFiles[\($0.offset)]", $0.element)
            }
        }
        let referenceSourceFields = reference.sourceFiles.enumerated().map {
            ("opening_reference.sourceFiles[\($0.offset)]", $0.element)
        }
        let referenceTraceFields = reference.audioTraces.flatMap { trace in
            trace.provenance.enumerated().map {
                ("opening_reference.audioTraces[\(trace.cueName)].provenance[\($0.offset)]", $0.element)
            }
        }
        let textualFields =
            bundleAssetFields +
            audioCueFields +
            sourceFileFields +
            assetSourceFields +
            referenceSourceFields +
            referenceTraceFields +
            [("opening_provenance.audioArchive", provenance.audioArchive)]

        for (field, value) in textualFields {
            let lowercasedValue = value.lowercased()
            for term in Self.forbiddenPlaceholderTerms where lowercasedValue.contains(term) {
                throw OpeningHeartGoldArtifactError.forbiddenPlaceholder(term: term, field: field)
            }
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
    }
}
