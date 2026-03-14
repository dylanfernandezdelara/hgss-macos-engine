import Foundation
import HGSSContent
import Darwin

struct ExtractConfiguration {
    let input: URL
    let output: URL
    let dryRun: Bool
}

enum ExtractCLIError: Error, LocalizedError {
    case missingValue(flag: String)
    case unsupportedFlag(String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(flag):
            return "Missing value for \(flag)."
        case let .unsupportedFlag(flag):
            return "Unsupported flag: \(flag)."
        }
    }
}

private func usage() {
    print("""
    HGSSExtractCLI (stub)

    Usage:
      swift run HGSSExtractCLI --input <path> --output <path> [--dry-run]
    """)
}

private func parseArguments(_ args: [String]) throws -> ExtractConfiguration {
    var index = 0
    var inputPath: String?
    var outputPath: String?
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

    return ExtractConfiguration(input: input, output: output, dryRun: dryRun)
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
            let manifest = try loader.loadManifest(from: config.input)

            if !config.dryRun {
                try FileManager.default.createDirectory(at: config.output, withIntermediateDirectories: true)
                let reportURL = config.output.appendingPathComponent("extract_report.txt", isDirectory: false)
                let report = "Stub extractor copied manifest metadata for \(manifest.title) (build \(manifest.build)).\n"
                try report.write(to: reportURL, atomically: true, encoding: .utf8)
            }

            print("Extractor stub complete.")
            print("Input: \(config.input.path())")
            print("Output: \(config.output.path())")
            print("Dry run: \(config.dryRun ? "yes" : "no")")
        } catch {
            fputs("HGSSExtractCLI error: \(error.localizedDescription)\n", stderr)
            usage()
            exit(1)
        }
    }
}
