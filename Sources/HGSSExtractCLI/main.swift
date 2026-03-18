import AppKit
import Darwin
import Foundation
import HGSSContent
import HGSSDataModel

enum ExtractMode: String {
    case stubNewBark = "stub-new-bark"
    case openingHeartGold = "opening-heartgold"
}

struct ExtractConfiguration {
    let mode: ExtractMode
    let input: URL
    let output: URL
    let pretRoot: URL?
    let dryRun: Bool
}

enum ExtractCLIError: Error, LocalizedError {
    case missingValue(flag: String)
    case unsupportedFlag(String)
    case unsupportedMode(String)
    case missingPretRoot
    case missingPretFile(path: String)
    case missingPretRenderAsset(path: String)
    case missingTool(path: String)
    case missingScript(path: String)
    case commandFailed(command: String, status: Int32, stderr: String)
    case imageWriteFailed(path: String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(flag):
            return "Missing value for \(flag)."
        case let .unsupportedFlag(flag):
            return "Unsupported flag: \(flag)."
        case let .unsupportedMode(mode):
            return "Unsupported extractor mode: \(mode)."
        case .missingPretRoot:
            return "opening-heartgold requires a local pret/pokeheartgold clone. Set --pret-root or POKEHEARTGOLD_ROOT."
        case let .missingPretFile(path):
            return "Required pret/pokeheartgold file not found: \(path)."
        case let .missingPretRenderAsset(path):
            return "Required render asset not found in pret/pokeheartgold clone: \(path)."
        case let .missingTool(path):
            return "Required extractor tool not found: \(path)."
        case let .missingScript(path):
            return "Required helper script not found: \(path)."
        case let .commandFailed(command, status, stderr):
            return "Extractor tool failed (\(status)) for '\(command)': \(stderr)"
        case let .imageWriteFailed(path):
            return "Failed to write PNG image to \(path)."
        }
    }
}

private func usage() {
    print("""
    HGSSExtractCLI

    Usage:
      swift run HGSSExtractCLI [--mode opening-heartgold|stub-new-bark] [--input <path>] [--output <path>] [--pret-root <path>] [--dry-run]

    Notes:
      - `opening-heartgold` is the default mode and emits Content/Local/Boot/HeartGold outputs.
      - `stub-new-bark` preserves the existing normalized manifest plus render bundle flow.
      - `opening-heartgold` requires a local pret/pokeheartgold clone for non-dry-run extraction.
    """)
}

private func parseArguments(_ args: [String]) throws -> ExtractConfiguration {
    var index = 0
    var mode: ExtractMode = .openingHeartGold
    var inputPath: String?
    var outputPath: String?
    var pretRootPath: String?
    var dryRun = false

    while index < args.count {
        switch args[index] {
        case "--mode":
            index += 1
            guard index < args.count else {
                throw ExtractCLIError.missingValue(flag: "--mode")
            }
            guard let parsedMode = ExtractMode(rawValue: args[index]) else {
                throw ExtractCLIError.unsupportedMode(args[index])
            }
            mode = parsedMode
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
    let defaultOutputPath: String
    switch mode {
    case .stubNewBark:
        defaultOutputPath = "Content/Local/StubExtract"
    case .openingHeartGold:
        defaultOutputPath = "Content/Local/Boot/HeartGold"
    }
    let output = URL(fileURLWithPath: outputPath ?? defaultOutputPath, relativeTo: cwd).standardizedFileURL
    let pretRoot = pretRootPath
        .map { URL(fileURLWithPath: $0, relativeTo: cwd).standardizedFileURL }
        ?? ProcessInfo.processInfo.environment["POKEHEARTGOLD_ROOT"].map {
            URL(fileURLWithPath: $0, relativeTo: cwd).standardizedFileURL
        }

    return ExtractConfiguration(mode: mode, input: input, output: output, pretRoot: pretRoot, dryRun: dryRun)
}

private func loadPretManifest(
    profileManifest: HGSSManifest,
    pretRoot: URL
) throws -> HGSSManifest {
    let mapHeadersURL = pretRoot.appendingPathComponent("src/data/map_headers.h", isDirectory: false)
    let zoneEventURL = pretRoot.appendingPathComponent(
        "files/fielddata/eventdata/zone_event/057_T20.json",
        isDirectory: false
    )

    guard FileManager.default.fileExists(atPath: mapHeadersURL.path()) else {
        throw ExtractCLIError.missingPretFile(path: mapHeadersURL.path())
    }
    guard FileManager.default.fileExists(atPath: zoneEventURL.path()) else {
        throw ExtractCLIError.missingPretFile(path: zoneEventURL.path())
    }

    let mapHeadersText = try String(contentsOf: mapHeadersURL, encoding: .utf8)
    let zoneEventData = try Data(contentsOf: zoneEventURL)
    let normalizer = PretNewBarkNormalizer()
    return try normalizer.buildManifest(
        from: profileManifest,
        mapHeadersText: mapHeadersText,
        zoneEventData: zoneEventData
    )
}

private func writeManifest(_ manifest: HGSSManifest, to output: URL) throws {
    let manifestURL = output.appendingPathComponent("manifest.json", isDirectory: false)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(manifest)
    try data.write(to: manifestURL)
}

private func writeRenderBundle(_ bundle: HGSSRenderBundle, to output: URL) throws {
    let bundleURL = output.appendingPathComponent("render_bundle.json", isDirectory: false)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(bundle)
    try data.write(to: bundleURL)
}

private func buildRenderBundle(
    manifest: HGSSManifest,
    output: URL,
    pretRoot: URL?,
    dryRun: Bool
) throws -> HGSSRenderBundle {
    let assetsDirectory = output.appendingPathComponent("assets", isDirectory: true)
    if !dryRun {
        try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
    }

    let topBootFrame = try createTopBootFrameAsset(
        destinationDirectory: assetsDirectory,
        pretRoot: pretRoot,
        dryRun: dryRun
    )
    let bottomIdle = try createBottomIdleOverworldAsset(
        destinationDirectory: assetsDirectory,
        pretRoot: pretRoot,
        dryRun: dryRun
    )
    let ethanSpriteSheet = try createEthanSpriteSheetAsset(
        destinationDirectory: assetsDirectory,
        dryRun: dryRun
    )

    return HGSSRenderBundle(
        schemaVersion: 2,
        title: manifest.title,
        build: manifest.build,
        initialMapID: manifest.initialMapID,
        initialEntryPointID: manifest.initialEntryPointID,
        bootVariant: .init(
            protagonistID: "ETHAN",
            timeOfDay: "day",
            weather: 0,
            mapID: "MAP_NEW_BARK",
            entryPointID: "ENTRY_BOOT_DEFAULT"
        ),
        assets: [topBootFrame, bottomIdle, ethanSpriteSheet],
        topScreen: .init(
            nativeScreen: .init(width: 256, height: 192),
            frameAssetID: topBootFrame.id,
            camera: .init(
                viewportTilesWide: 8,
                viewportTilesHigh: 6,
                tileSize: 32,
                stepDurationMilliseconds: 180
            )
        ),
        bottomScreen: .init(
            nativeScreen: .init(width: 256, height: 192),
            frameAssetID: bottomIdle.id
        ),
        playerSpriteSheet: .init(
            assetID: ethanSpriteSheet.id,
            frameWidth: 32,
            frameHeight: 32,
            columns: 4,
            rows: 4,
            defaultFacing: "down"
        ),
        developerOverlay: .init(
            palette: .init(
                blockedFillHex: "#2A3841",
                blockedStrokeHex: "#E6F1F3",
                warpFillHex: "#1E7EA9",
                warpStrokeHex: "#E3F7FF",
                placementFillHex: "#B77A24",
                placementStrokeHex: "#FFF3D8",
                entryPointFillHex: "#B34D38",
                entryPointStrokeHex: "#FFE7E1",
                gridHex: "#D3DEE0"
            )
        )
    )
}

private func createTopBootFrameAsset(
    destinationDirectory: URL,
    pretRoot: URL?,
    dryRun: Bool
) throws -> HGSSRenderBundle.Asset {
    let destination = destinationDirectory.appendingPathComponent("top_boot_frame.png", isDirectory: false)

    if !dryRun {
        if let pretRoot {
            try renderNewBarkTopBootFrame(to: destination, pretRoot: pretRoot)
        } else {
            try renderFallbackTopBootFrame(to: destination)
        }
    }

    return HGSSRenderBundle.Asset(
        id: "top_boot_frame",
        relativePath: "assets/top_boot_frame.png",
        pixelWidth: 256,
        pixelHeight: 192,
        provenance: pretRoot != nil ? "pret-derived New Bark boot-frame stand-in using exported field textures" : "fallback local render asset"
    )
}

private func createBottomIdleOverworldAsset(
    destinationDirectory: URL,
    pretRoot: URL?,
    dryRun: Bool
) throws -> HGSSRenderBundle.Asset {
    let destination = destinationDirectory.appendingPathComponent("bottom_idle_overworld.png", isDirectory: false)

    if !dryRun {
        if let pretRoot {
            try renderBottomIdleOverworld(to: destination, pretRoot: pretRoot)
        } else {
            try renderFallbackBottomScreen(to: destination)
        }
    }

    return HGSSRenderBundle.Asset(
        id: "bottom_idle_overworld",
        relativePath: "assets/bottom_idle_overworld.png",
        pixelWidth: 256,
        pixelHeight: 192,
        provenance: pretRoot != nil ? "pret-derived lower-screen stand-in from pgphone_gra_00000041.png" : "fallback local render asset"
    )
}

private func createEthanSpriteSheetAsset(
    destinationDirectory: URL,
    dryRun: Bool
) throws -> HGSSRenderBundle.Asset {
    let destination = destinationDirectory.appendingPathComponent("ethan_overworld.png", isDirectory: false)

    if !dryRun {
        try renderTransparentSpriteSheet(to: destination, width: 128, height: 128)
    }

    return HGSSRenderBundle.Asset(
        id: "ethan_overworld",
        relativePath: "assets/ethan_overworld.png",
        pixelWidth: 128,
        pixelHeight: 128,
        provenance: "reserved sprite-sheet slot for Ethan overworld extraction"
    )
}

private func renderNewBarkTopBootFrame(to destination: URL, pretRoot: URL) throws {
    let areaWindowURL = pretRoot.appendingPathComponent("files/data/gs_areawindow/areawindow_0.png", isDirectory: false)
    guard FileManager.default.fileExists(atPath: areaWindowURL.path()) else {
        throw ExtractCLIError.missingPretRenderAsset(path: areaWindowURL.path())
    }

    let exportedTextures = try exportNewBarkFieldTextures(pretRoot: pretRoot)
    let areaWindow = try loadImage(at: areaWindowURL)
    let labTexture = exportedTextures["wk_labo_a"]
    let houseTexture = exportedTextures["wk_hh_a"]
    let shrubTexture = exportedTextures["wk_sp1_a"] ?? exportedTextures["wk_labo_b"] ?? exportedTextures["wk_hh_b"]

    try renderPNG(width: 256, height: 192, to: destination) { context in
        NSColor(calibratedRed: 0.52, green: 0.73, blue: 0.46, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 256, height: 192)).fill()

        if let shrubTexture {
            tileImage(shrubTexture, in: NSRect(x: 0, y: 24, width: 256, height: 168))
        }

        NSColor(calibratedRed: 0.80, green: 0.70, blue: 0.48, alpha: 0.88).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 118, width: 256, height: 30)).fill()
        NSBezierPath(rect: NSRect(x: 102, y: 24, width: 28, height: 168)).fill()

        if let houseTexture {
            drawImage(houseTexture, in: NSRect(x: 10, y: 82, width: 92, height: 92))
            drawImage(houseTexture, in: NSRect(x: 154, y: 94, width: 84, height: 84))
        }
        if let labTexture {
            drawImage(labTexture, in: NSRect(x: 142, y: 24, width: 104, height: 104))
        }

        drawImage(areaWindow, in: NSRect(x: 0, y: 0, width: 256, height: 24))
    }
}

private func renderBottomIdleOverworld(to destination: URL, pretRoot: URL) throws {
    let sourceURL = pretRoot.appendingPathComponent(
        "files/application/pokegear/phone/pgphone_gra/pgphone_gra_00000041.png",
        isDirectory: false
    )
    guard FileManager.default.fileExists(atPath: sourceURL.path()) else {
        throw ExtractCLIError.missingPretRenderAsset(path: sourceURL.path())
    }

    let image = try loadImage(at: sourceURL)
    try renderPNG(width: 256, height: 192, to: destination) { _ in
        drawImage(image, in: NSRect(x: 0, y: 0, width: 256, height: 192))
    }
}

private func renderFallbackTopBootFrame(to destination: URL) throws {
    try renderPNG(width: 256, height: 192, to: destination) { _ in
        NSColor(calibratedRed: 0.25, green: 0.37, blue: 0.22, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 256, height: 192)).fill()
    }
}

private func renderFallbackBottomScreen(to destination: URL) throws {
    try renderPNG(width: 256, height: 192, to: destination) { _ in
        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 256, height: 192)).fill()
    }
}

private func renderTransparentSpriteSheet(to destination: URL, width: Int, height: Int) throws {
    try renderPNG(width: width, height: height, to: destination) { _ in
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
    }
}

private func exportNewBarkFieldTextures(pretRoot: URL) throws -> [String: NSImage] {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("hgss-new-bark-field-\(UUID().uuidString)", isDirectory: true)
    let unpackDirectory = temporaryRoot.appendingPathComponent("bm_field", isDirectory: true)
    let exportDirectory = temporaryRoot.appendingPathComponent("apicula", isDirectory: true)
    try FileManager.default.createDirectory(at: unpackDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

    let knarcPath = pretRoot.appendingPathComponent("tools/knarc/knarc", isDirectory: false)
    guard FileManager.default.fileExists(atPath: knarcPath.path()) else {
        throw ExtractCLIError.missingTool(path: knarcPath.path())
    }

    let apiculaPath = try resolveApiculaBinary()
    let bmFieldPath = pretRoot.appendingPathComponent("files/fielddata/build_model/bm_field.narc", isDirectory: false)
    guard FileManager.default.fileExists(atPath: bmFieldPath.path()) else {
        throw ExtractCLIError.missingPretFile(path: bmFieldPath.path())
    }

    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    try runProcess(
        executable: knarcPath,
        arguments: ["-d", unpackDirectory.path(), "-u", bmFieldPath.path()],
        commandLabel: "knarc"
    )

    let sourceFiles = [
        unpackDirectory.appendingPathComponent("bm_field_00000020.bin", isDirectory: false),
        unpackDirectory.appendingPathComponent("bm_field_00000021.bin", isDirectory: false),
        unpackDirectory.appendingPathComponent("bm_field_00000027.bin", isDirectory: false)
    ]
    for path in sourceFiles where !FileManager.default.fileExists(atPath: path.path()) {
        throw ExtractCLIError.missingPretRenderAsset(path: path.path())
    }

    try runProcess(
        executable: apiculaPath,
        arguments: [
            "convert",
            sourceFiles[0].path(),
            sourceFiles[1].path(),
            sourceFiles[2].path(),
            "-o",
            exportDirectory.path(),
            "--overwrite"
        ],
        commandLabel: "apicula convert"
    )

    let textureNames = ["wk_hh_a", "wk_hh_b", "wk_labo_a", "wk_labo_b", "wk_sp1_a"]
    var textures: [String: NSImage] = [:]
    for name in textureNames {
        let path = exportDirectory.appendingPathComponent("\(name).png", isDirectory: false)
        if FileManager.default.fileExists(atPath: path.path()) {
            textures[name] = try loadImage(at: path)
        }
    }
    return textures
}

func resolveApiculaBinary() throws -> URL {
    let environment = ProcessInfo.processInfo.environment
    if let override = environment["APICULA_BIN"], !override.isEmpty {
        let path = URL(fileURLWithPath: override, isDirectory: false)
        guard FileManager.default.fileExists(atPath: path.path()) else {
            throw ExtractCLIError.missingTool(path: path.path())
        }
        return path
    }

    let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let defaultPath = repoRoot.appendingPathComponent("External/apicula/target/release/apicula", isDirectory: false)
    guard FileManager.default.fileExists(atPath: defaultPath.path()) else {
        throw ExtractCLIError.missingTool(path: defaultPath.path())
    }
    return defaultPath
}

func runProcess(
    executable: URL,
    arguments: [String],
    commandLabel: String
) throws {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let stdoutBuffer = NSMutableData()
    let stderrBuffer = NSMutableData()
    let bufferLock = NSLock()

    func installDrain(for handle: FileHandle, buffer: NSMutableData) {
        handle.readabilityHandler = { readableHandle in
            let data = readableHandle.availableData
            guard !data.isEmpty else {
                readableHandle.readabilityHandler = nil
                return
            }
            bufferLock.lock()
            buffer.append(data)
            bufferLock.unlock()
        }
    }

    installDrain(for: stdoutPipe.fileHandleForReading, buffer: stdoutBuffer)
    installDrain(for: stderrPipe.fileHandleForReading, buffer: stderrBuffer)

    try process.run()
    process.waitUntilExit()
    stdoutPipe.fileHandleForReading.readabilityHandler = nil
    stderrPipe.fileHandleForReading.readabilityHandler = nil

    let stdoutTail = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    if !stdoutTail.isEmpty {
        bufferLock.lock()
        stdoutBuffer.append(stdoutTail)
        bufferLock.unlock()
    }

    let stderrTail = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    if !stderrTail.isEmpty {
        bufferLock.lock()
        stderrBuffer.append(stderrTail)
        bufferLock.unlock()
    }

    guard process.terminationStatus == 0 else {
        let stderr = String(data: stderrBuffer as Data, encoding: .utf8) ?? ""
        throw ExtractCLIError.commandFailed(
            command: ([executable.lastPathComponent] + arguments).joined(separator: " "),
            status: process.terminationStatus,
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

func loadImage(at url: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        throw ExtractCLIError.missingPretRenderAsset(path: url.path())
    }
    return image
}

private func renderPNG(
    width: Int,
    height: Int,
    to destination: URL,
    drawing: (_ context: NSGraphicsContext) throws -> Void
) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw ExtractCLIError.imageWriteFailed(path: destination.path())
    }

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw ExtractCLIError.imageWriteFailed(path: destination.path())
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .none
    context.cgContext.translateBy(x: 0, y: CGFloat(height))
    context.cgContext.scaleBy(x: 1, y: -1)
    defer { NSGraphicsContext.restoreGraphicsState() }

    try drawing(context)

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw ExtractCLIError.imageWriteFailed(path: destination.path())
    }

    try png.write(to: destination)
}

private func tileImage(_ image: NSImage, in rect: NSRect) {
    let tileWidth = max(1, Int(image.size.width))
    let tileHeight = max(1, Int(image.size.height))
    var y = Int(rect.minY)
    while y < Int(rect.maxY) {
        var x = Int(rect.minX)
        while x < Int(rect.maxX) {
            let remainingWidth = min(tileWidth, Int(rect.maxX) - x)
            let remainingHeight = min(tileHeight, Int(rect.maxY) - y)
            drawImage(
                image,
                in: NSRect(x: x, y: y, width: remainingWidth, height: remainingHeight)
            )
            x += tileWidth
        }
        y += tileHeight
    }
}

private func drawImage(_ image: NSImage, in rect: NSRect) {
    image.draw(
        in: rect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.none]
    )
}

private func writeReport(
    mode: String,
    manifest: HGSSManifest,
    renderBundle: HGSSRenderBundle,
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
    Initial warps: \(initialMap?.warps.count ?? 0)
    Initial placements: \(initialMap?.placements.count ?? 0)
    Render bundle schema: \(renderBundle.schemaVersion)
    Render assets: \(renderBundle.assets.count)
    Pret root: \(pretRoot?.path() ?? "not provided")
    """
    try summary.appending("\n").write(to: reportURL, atomically: true, encoding: .utf8)
}

private func runStubNewBarkExtraction(config: ExtractConfiguration) throws {
    let loader = StubContentLoader()
    let profileManifest = try loader.loadManifest(from: config.input)

    let modeLabel: String
    let extractedManifest: HGSSManifest
    if let pretRoot = config.pretRoot {
        modeLabel = "pret-new-bark"
        extractedManifest = try loadPretManifest(profileManifest: profileManifest, pretRoot: pretRoot)
    } else {
        modeLabel = "profile-copy"
        extractedManifest = profileManifest
    }

    let renderBundle = try buildRenderBundle(
        manifest: extractedManifest,
        output: config.output,
        pretRoot: config.pretRoot,
        dryRun: config.dryRun
    )

    if !config.dryRun {
        try FileManager.default.createDirectory(at: config.output, withIntermediateDirectories: true)
        try writeManifest(extractedManifest, to: config.output)
        try writeRenderBundle(renderBundle, to: config.output)
        try writeReport(
            mode: modeLabel,
            manifest: extractedManifest,
            renderBundle: renderBundle,
            output: config.output,
            pretRoot: config.pretRoot
        )
    }

    let initialMap = extractedManifest.maps.first(where: { $0.mapID == extractedManifest.initialMapID })

    print("Extractor complete.")
    print("Mode: \(modeLabel)")
    print("Input profile: \(config.input.path())")
    print("Output: \(config.output.path())")
    print("Dry run: \(config.dryRun ? "yes" : "no")")
    print("Initial map: \(extractedManifest.initialMapID)")
    print("Initial warps: \(initialMap?.warps.count ?? 0)")
    print("Initial placements: \(initialMap?.placements.count ?? 0)")
    print("Render assets: \(renderBundle.assets.count)")
    if let pretRoot = config.pretRoot {
        print("Pret root: \(pretRoot.path())")
    }
}

let rawArgs = Array(CommandLine.arguments.dropFirst())
if rawArgs.contains("--help") || rawArgs.contains("-h") {
    usage()
} else {
    do {
        let config = try parseArguments(rawArgs)
        switch config.mode {
        case .stubNewBark:
            try runStubNewBarkExtraction(config: config)
        case .openingHeartGold:
            try OpeningHeartGoldExtractor().run(config: config)
        }
    } catch {
        fputs("HGSSExtractCLI error: \(error.localizedDescription)\n", stderr)
        usage()
        exit(1)
    }
}
