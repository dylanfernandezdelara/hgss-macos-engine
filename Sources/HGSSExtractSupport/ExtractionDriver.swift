import Foundation
import HGSSContent
import HGSSDataModel

public struct ExtractConfiguration {
    public let input: URL
    public let output: URL
    public let pretRoot: URL?
    public let dryRun: Bool

    public init(input: URL, output: URL, pretRoot: URL?, dryRun: Bool) {
        self.input = input
        self.output = output
        self.pretRoot = pretRoot
        self.dryRun = dryRun
    }
}

public enum ExtractCLIError: Error, LocalizedError {
    case missingValue(flag: String)
    case unsupportedFlag(String)
    case missingUpstreamFile(label: String, path: String)

    public var errorDescription: String? {
        switch self {
        case let .missingValue(flag):
            return "Missing value for \(flag)."
        case let .unsupportedFlag(flag):
            return "Unsupported flag: \(flag)."
        case let .missingUpstreamFile(label, path):
            return "Required upstream source file for \(label) not found: \(path)."
        }
    }
}

public struct ExtractedManifestResult {
    public let mode: String
    public let manifest: HGSSManifest
    public let upstreamRoot: URL

    public init(mode: String, manifest: HGSSManifest, upstreamRoot: URL) {
        self.mode = mode
        self.manifest = manifest
        self.upstreamRoot = upstreamRoot
    }
}

public struct PretSourceFiles {
    public let mode: String
    public let root: URL
    public let mapHeadersURL: URL
    public let zoneEventURL: URL

    public init(mode: String, root: URL, mapHeadersURL: URL, zoneEventURL: URL) {
        self.mode = mode
        self.root = root
        self.mapHeadersURL = mapHeadersURL
        self.zoneEventURL = zoneEventURL
    }
}

public func defaultWorkingDirectory() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true).standardizedFileURL
}

public func extractManifest(
    config: ExtractConfiguration,
    workingDirectory: URL = defaultWorkingDirectory(),
    fileManager: FileManager = .default
) throws -> ExtractedManifestResult {
    let loader = StubContentLoader()
    let profileManifest = try loader.loadManifest(from: config.input)
    let sourceFiles = try resolvePretSourceFiles(
        pretRoot: config.pretRoot,
        workingDirectory: workingDirectory,
        fileManager: fileManager
    )

    let mapHeadersText = try String(contentsOf: sourceFiles.mapHeadersURL, encoding: .utf8)
    let zoneEventData = try Data(contentsOf: sourceFiles.zoneEventURL)
    let normalizer = PretNewBarkNormalizer()
    let manifest = try normalizer.buildManifest(
        from: profileManifest,
        mapHeadersText: mapHeadersText,
        zoneEventData: zoneEventData
    )

    return ExtractedManifestResult(
        mode: sourceFiles.mode,
        manifest: manifest,
        upstreamRoot: sourceFiles.root
    )
}

public func resolvePretSourceFiles(
    pretRoot: URL?,
    workingDirectory: URL = defaultWorkingDirectory(),
    fileManager: FileManager = .default
) throws -> PretSourceFiles {
    if let pretRoot {
        let root = pretRoot.standardizedFileURL
        return try PretSourceFiles(
            mode: "pret-new-bark",
            root: root,
            mapHeadersURL: requiredSourceFile(
                at: root.appendingPathComponent("src/data/map_headers.h", isDirectory: false),
                label: "pret map_headers.h",
                fileManager: fileManager
            ),
            zoneEventURL: requiredSourceFile(
                at: root.appendingPathComponent(
                    "files/fielddata/eventdata/zone_event/057_T20.json",
                    isDirectory: false
                ),
                label: "pret 057_T20.json",
                fileManager: fileManager
            )
        )
    }

    let fixtureRoot = workingDirectory
        .appendingPathComponent("Tests/Fixtures/PretNewBark", isDirectory: true)
        .standardizedFileURL

    return try PretSourceFiles(
        mode: "pret-fixture-new-bark",
        root: fixtureRoot,
        mapHeadersURL: requiredSourceFile(
            at: fixtureRoot.appendingPathComponent("map_headers_new_bark.h", isDirectory: false),
            label: "fixture map_headers_new_bark.h",
            fileManager: fileManager
        ),
        zoneEventURL: requiredSourceFile(
            at: fixtureRoot.appendingPathComponent("057_T20.json", isDirectory: false),
            label: "fixture 057_T20.json",
            fileManager: fileManager
        )
    )
}

private func requiredSourceFile(
    at url: URL,
    label: String,
    fileManager: FileManager
) throws -> URL {
    guard fileManager.fileExists(atPath: url.path()) else {
        throw ExtractCLIError.missingUpstreamFile(label: label, path: url.path())
    }
    return url
}
