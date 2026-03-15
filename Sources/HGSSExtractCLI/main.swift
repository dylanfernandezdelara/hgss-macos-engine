import Foundation
import HGSSDataModel
import HGSSExtractSupport
import Darwin

private func usage() {
    print("""
    HGSSExtractCLI

    Usage:
      swift run HGSSExtractCLI --input <path> --output <path> [--pret-root <path>] [--dry-run]

    Notes:
      - The extractor always rebuilds the New Bark manifest through the pret normalizer.
      - Without --pret-root, it uses committed pret-style fixture inputs under Tests/Fixtures/PretNewBark.
      - With --pret-root, it uses local pret/pokeheartgold files plus the local profile manifest.
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
    upstreamRoot: URL
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
    Initial warps: \(initialMap?.warps.count ?? 0)
    Initial placements: \(initialMap?.placements.count ?? 0)
    Upstream root: \(upstreamRoot.path())
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
            let result = try extractManifest(config: config, workingDirectory: defaultWorkingDirectory())

            if !config.dryRun {
                try FileManager.default.createDirectory(at: config.output, withIntermediateDirectories: true)
                try writeManifest(result.manifest, to: config.output)
                try writeReport(
                    mode: result.mode,
                    manifest: result.manifest,
                    output: config.output,
                    upstreamRoot: result.upstreamRoot
                )
            }

            let initialMap = result.manifest.maps.first(where: { $0.mapID == result.manifest.initialMapID })

            print("Extractor complete.")
            print("Mode: \(result.mode)")
            print("Input profile: \(config.input.path())")
            print("Output: \(config.output.path())")
            print("Dry run: \(config.dryRun ? "yes" : "no")")
            print("Initial map: \(result.manifest.initialMapID)")
            print("Initial warps: \(initialMap?.warps.count ?? 0)")
            print("Initial placements: \(initialMap?.placements.count ?? 0)")
            print("Upstream root: \(result.upstreamRoot.path())")
        } catch {
            fputs("HGSSExtractCLI error: \(error.localizedDescription)\n", stderr)
            usage()
            exit(1)
        }
    }
}
