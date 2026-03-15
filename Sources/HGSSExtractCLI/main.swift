import Foundation
import HGSSContent
import HGSSDataModel
import Darwin

struct ExtractConfiguration {
    let input: URL
    let output: URL
    let pretRoot: URL?
    let dryRun: Bool
}

enum ExtractCLIError: Error, LocalizedError {
    case missingValue(flag: String)
    case unsupportedFlag(String)
    case missingPretFile(path: String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(flag):
            return "Missing value for \(flag)."
        case let .unsupportedFlag(flag):
            return "Unsupported flag: \(flag)."
        case let .missingPretFile(path):
            return "Required pret/pokeheartgold file not found: \(path)."
        }
    }
}

private func usage() {
    print("""
    HGSSExtractCLI

    Usage:
      swift run HGSSExtractCLI --input <path> --output <path> [--pret-root <path>] [--dry-run]

    Notes:
      - Without --pret-root, the extractor copies the checked-in normalized fixture.
      - With --pret-root, it rebuilds the New Bark manifest from local pret/pokeheartgold header, event, matrix, and collision inputs plus the local profile excerpt bounds.
    """)
}

private func parseArguments(_ args: [String]) throws -> ExtractConfiguration {
    var index = 0
    var inputPath: String?
    var outputPath: String?
    var pretRootPath: String?
    var dryRun = false

    while index < args.count {
        switch args[index] {
        case "--input":
            index += 1
            guard index < args.count else {
                throw ExtractCLIError.missingValue(flag: "--input")
            }
            inputPath = args[index]
        case "--output":
            index += 1
            guard index < args.count else {
                throw ExtractCLIError.missingValue(flag: "--output")
            }
            outputPath = args[index]
        case "--pret-root":
            index += 1
            guard index < args.count else {
                throw ExtractCLIError.missingValue(flag: "--pret-root")
            }
            pretRootPath = args[index]
        case "--dry-run":
            dryRun = true
        default:
            throw ExtractCLIError.unsupportedFlag(args[index])
        }
        index += 1
    }

    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let input = URL(fileURLWithPath: inputPath ?? "DevContent/Stub", relativeTo: cwd).standardizedFileURL
    let output = URL(fileURLWithPath: outputPath ?? "Content/Local/StubExtract", relativeTo: cwd).standardizedFileURL
    let pretRoot = pretRootPath.map { URL(fileURLWithPath: $0, relativeTo: cwd).standardizedFileURL }

    return ExtractConfiguration(input: input, output: output, pretRoot: pretRoot, dryRun: dryRun)
}

private func loadPretManifest(
    profileManifest: HGSSManifest,
    pretRoot: URL
) throws -> HGSSManifest {
    let mapID = "MAP_NEW_BARK"
    let mapHeadersURL = pretRoot.appendingPathComponent("src/data/map_headers.h", isDirectory: false)
    let zoneEventURL = pretRoot.appendingPathComponent(
        "files/fielddata/eventdata/zone_event/057_T20.json",
        isDirectory: false
    )
    let mapMatrixURL = pretRoot.appendingPathComponent(
        "files/fielddata/mapmatrix/map_matrix/map_matrix_0000_EVERYWHERE.bin",
        isDirectory: false
    )
    let collisionArchiveURL = pretRoot.appendingPathComponent("files/a/0/6/5", isDirectory: false)

    guard FileManager.default.fileExists(atPath: mapHeadersURL.path()) else {
        throw ExtractCLIError.missingPretFile(path: mapHeadersURL.path())
    }
    guard FileManager.default.fileExists(atPath: zoneEventURL.path()) else {
        throw ExtractCLIError.missingPretFile(path: zoneEventURL.path())
    }
    guard FileManager.default.fileExists(atPath: mapMatrixURL.path()) else {
        throw ExtractCLIError.missingPretFile(path: mapMatrixURL.path())
    }
    guard FileManager.default.fileExists(atPath: collisionArchiveURL.path()) else {
        throw ExtractCLIError.missingPretFile(path: collisionArchiveURL.path())
    }

    guard let profileMap = profileManifest.maps.first(where: { $0.mapID == mapID }) else {
        throw PretNormalizationError.missingProfileMap(mapID)
    }

    let mapHeadersText = try String(contentsOf: mapHeadersURL, encoding: .utf8)
    let zoneEventData = try Data(contentsOf: zoneEventURL)
    let mapMatrixData = try Data(contentsOf: mapMatrixURL)
    let collisionArchiveData = try Data(contentsOf: collisionArchiveURL)
    let extractedCollision = try PretNewBarkCollisionExtractor().extractCollisionInput(
        layout: profileMap.layout,
        mapMatrixData: mapMatrixData,
        modelArchiveData: collisionArchiveData,
        mapID: mapID
    )
    let normalizer = PretNewBarkNormalizer()
    return try normalizer.buildManifest(
        from: profileManifest,
        mapHeadersText: mapHeadersText,
        zoneEventData: zoneEventData,
        extractedCollision: extractedCollision,
        mapID: mapID
    )
}

private func writeManifest(_ manifest: HGSSManifest, to output: URL) throws {
    let manifestURL = output.appendingPathComponent("manifest.json", isDirectory: false)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)
    try data.write(to: manifestURL)
}

private func writeReport(
    mode: String,
    manifest: HGSSManifest,
    output: URL,
    pretRoot: URL?
) throws {
    let reportURL = output.appendingPathComponent("extract_report.txt", isDirectory: false)
    let mapCount = manifest.maps.count
    let initialMap = manifest.maps.first(where: { $0.mapID == manifest.initialMapID })
    let summary = """
    Extraction mode: \(mode)
    Manifest title: \(manifest.title)
    Build: \(manifest.build)
    Maps: \(mapCount)
    Initial map: \(manifest.initialMapID)
    Initial entry point: \(manifest.initialEntryPointID)
    Initial blocked tiles: \(initialMap?.collision.impassableTiles.count ?? 0)
    Initial warps: \(initialMap?.warps.count ?? 0)
    Initial placements: \(initialMap?.placements.count ?? 0)
    Pret root: \(pretRoot?.path() ?? "not provided")
    """
    try summary.appending("\n").write(to: reportURL, atomically: true, encoding: .utf8)
}

@main
struct HGSSExtractCLI {
    static func main() {
        let rawArgs = Array(CommandLine.arguments.dropFirst())
        if rawArgs.contains("--help") || rawArgs.contains("-h") {
            usage()
            return
        }

        do {
            let config = try parseArguments(rawArgs)
            let loader = StubContentLoader()
            let profileManifest = try loader.loadManifest(from: config.input)

            let mode: String
            let extractedManifest: HGSSManifest
            if let pretRoot = config.pretRoot {
                mode = "pret-new-bark"
                extractedManifest = try loadPretManifest(profileManifest: profileManifest, pretRoot: pretRoot)
            } else {
                mode = "profile-copy"
                extractedManifest = profileManifest
            }

            if !config.dryRun {
                try FileManager.default.createDirectory(at: config.output, withIntermediateDirectories: true)
                try writeManifest(extractedManifest, to: config.output)
                try writeReport(mode: mode, manifest: extractedManifest, output: config.output, pretRoot: config.pretRoot)
            }

            let initialMap = extractedManifest.maps.first(where: { $0.mapID == extractedManifest.initialMapID })

            print("Extractor complete.")
            print("Mode: \(mode)")
            print("Input profile: \(config.input.path())")
            print("Output: \(config.output.path())")
            print("Dry run: \(config.dryRun ? "yes" : "no")")
            print("Initial map: \(extractedManifest.initialMapID)")
            print("Initial warps: \(initialMap?.warps.count ?? 0)")
            print("Initial placements: \(initialMap?.placements.count ?? 0)")
            if let pretRoot = config.pretRoot {
                print("Pret root: \(pretRoot.path())")
            }
        } catch {
            fputs("HGSSExtractCLI error: \(error.localizedDescription)\n", stderr)
            usage()
            exit(1)
        }
    }
}
