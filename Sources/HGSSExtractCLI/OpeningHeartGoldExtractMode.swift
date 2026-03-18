import AppKit
import Foundation
import HGSSDataModel
import SceneKit

private struct HelperSpriteManifest: Decodable {
    struct Sequence: Decodable {
        struct Frame: Decodable {
            let canvasHeight: Int
            let canvasWidth: Int
            let cellIndex: Int
            let duration: Int
            let frameHeight: Int
            let frameWidth: Int
            let originX: Int
            let originY: Int
            let path: String
        }

        let canvasHeight: Int
        let canvasWidth: Int
        let expandedFrames: [String]
        let frames: [Frame]
        let index: Int
        let originX: Int
        let originY: Int
    }

    let sequences: [Sequence]
}

private struct SpriteSequenceResult {
    let assets: [HGSSOpeningBundle.Asset]
    let frameAssetIDs: [String]
    let canvasWidth: Int
    let canvasHeight: Int
    let originX: Int
    let originY: Int
    let upstreamFiles: [String]
}

private struct BakedFrameSequenceResult {
    let assets: [HGSSOpeningBundle.Asset]
    let frameAssetIDs: [String]
    let upstreamFiles: [String]
}

private struct BakedModelScreenResult {
    let assets: [HGSSOpeningBundle.Asset]
    let frameAssetIDs: [String]
    let startFrame: Int
    let endFrame: Int
    let zIndex: Int
    let upstreamFiles: [String]
}

private struct RenderedAudioCueResult {
    let asset: HGSSOpeningBundle.Asset
    let upstreamFiles: [String]
    let wavRelativePath: String
    let traceRelativePath: String
    let cueName: String
    let sceneID: String
    let provenance: String
}

private struct Scene4ParticleManifest: Decodable {
    struct Resource: Decodable {
        struct Base: Decodable {
            let startOffsetFrames: Int
            let emitterLifeFrames: Int
            let particleLifeFrames: Int
        }

        struct Child: Decodable {
            let lifeFrames: Int
        }

        let id: Int
        let base: Base
        let child: Child?
    }

    let resources: [Resource]
}

private struct Scene4BakedParticleManifest: Decodable {
    struct Phase: Decodable {
        let id: String
        let durationFrames: Int
        let framePaths: [String]
        let resourceIDs: [Int]
    }

    let phases: [Phase]
    let seed: Int
    let surfaceHeight: Int
    let surfaceWidth: Int
}

private struct Scene4Timing {
    let fadeInDurationFrames: Int
    let slideDurationFrames: Int
    let fadeToBlackDurationFrames: Int
    let grassParticleDurationFrames: Int
    let fireParticleDurationFrames: Int
    let waterParticleDurationFrames: Int
    let slideInStartFrame: Int
    let slideOutStartFrame: Int
    let playersEndFrame: Int
    let chikoritaStartFrame: Int
    let chikoritaEndFrame: Int
    let cyndaquilStartFrame: Int
    let cyndaquilEndFrame: Int
    let totodileStartFrame: Int
    let totodileEndFrame: Int
    let fadeToBlackStartFrame: Int
    let sparklesStartFrame: Int
    let sparklesEndFrame: Int
    let totalDurationFrames: Int

    var grassParticleStartFrame: Int {
        chikoritaStartFrame + 1
    }

    var grassParticleEndFrame: Int {
        grassParticleStartFrame + grassParticleDurationFrames - 1
    }

    var fireParticleStartFrame: Int {
        cyndaquilStartFrame + 1
    }

    var fireParticleEndFrame: Int {
        fireParticleStartFrame + fireParticleDurationFrames - 1
    }

    var waterParticleStartFrame: Int {
        totodileStartFrame + 1
    }

    var waterParticleEndFrame: Int {
        waterParticleStartFrame + waterParticleDurationFrames - 1
    }
}

private struct ParsedWindowPan {
    let durationFrames: Int
    let startX1: Int
    let startY1: Int
    let startX2: Int
    let startY2: Int
    let endX1: Int
    let endY1: Int
    let endX2: Int
    let endY2: Int

    var fromRect: HGSSOpeningBundle.ScreenRect {
        .init(
            x: Double(startX1),
            y: Double(startY1),
            width: Double(startX2 - startX1),
            height: Double(startY2 - startY1)
        )
    }

    var toRect: HGSSOpeningBundle.ScreenRect {
        .init(
            x: Double(endX1),
            y: Double(endY1),
            width: Double(endX2 - endX1),
            height: Double(endY2 - endY1)
        )
    }
}

private struct Scene3SourceConfig {
    let circleWipeDurationFrames: Int
    let showNewBarkHoldThreshold: Int
    let showGoldenrodHoldThreshold: Int
    let waitEcruteakThreshold: Int
    let rivalPanelDelays: [Int]
    let removePanelBordersDelay: Int
    let cinematicAspectDelay: Int
    let rivalWholeRevealDelay: Int
    let rivalWholeRevealWindow: ParsedWindowPan
    let enteiRevealWindow: ParsedWindowPan
    let enteiRevealScrollDuration: Int
    let raikouRevealWindow: ParsedWindowPan
    let raikouRevealScrollDuration: Int
    let narrowWindowDelay: Int
    let narrowWindow: ParsedWindowPan
    let eusineAppearDelay: Int
    let unownSlideDelay: Int
    let enteiExitWindow: ParsedWindowPan
    let enteiExitScrollDuration: Int
    let raikouExitDelay: Int
    let raikouExitWindow: ParsedWindowPan
    let raikouExitScrollDuration: Int
    let suicuneExitDelay: Int
    let suicuneExitWindow: ParsedWindowPan
    let suicuneExitScrollDuration: Int
    let rocketExpandWindow: ParsedWindowPan
    let rocketExpandDurationFrames: Int
    let rocketScrollOffsetsY: [Int]
    let rocketScrollDurationFrames: Int
}

private struct Scene3Timing {
    let durationFrames: Int
    let goldenrodStartFrame: Int
    let ecruteakStartFrame: Int
    let ecruteakHideStartFrame: Int
    let rivalRevealStartFrame: Int
    let rivalPanelsStartFrame: Int
    let rivalPanelSwapFrames: [Int]
    let removePanelBordersStartFrame: Int
    let rivalWholeRevealStartFrame: Int
    let enteiRevealStartFrame: Int
    let raikouRevealStartFrame: Int
    let narrowWindowStartFrame: Int
    let spritesVisibleStartFrame: Int
    let eusineStartFrame: Int
    let unown0StartFrame: Int
    let unown1StartFrame: Int
    let rocketLayersStartFrame: Int
    let unown2StartFrame: Int
    let rocketExpandStartFrame: Int
}

private struct Scene4SourceConfig {
    let fadeInDurationFrames: Int
    let initialTopLayerX: Int
    let initialBottomLayerX: Int
    let slideInWindowTop: ParsedWindowPan
    let slideInWindowBottom: ParsedWindowPan
    let slideInScrollTopX: Int
    let slideInScrollBottomX: Int
    let holdPlayersThreshold: Int
    let slideOutWindowTop: ParsedWindowPan
    let slideOutWindowBottom: ParsedWindowPan
    let slideOutScrollTopX: Int
    let slideOutScrollBottomX: Int
    let fadeToBlackDurationFrames: Int
}

private struct ParsedScrollCall {
    let xChange: Int
    let yChange: Int
    let durationFrames: Int
}

private struct TitleHandoffSourceConfig {
    let translation: HGSSOpeningBundle.Vector3
    let cameraPosition: HGSSOpeningBundle.Vector3
    let cameraTarget: HGSSOpeningBundle.Vector3
    let fieldOfViewDegrees: Double
    let farClipDistance: Double
    let lights: [HGSSOpeningBundle.ModelAnimationRef.LightState]
}

private enum OpeningHeartGoldExtractModeError: Error, LocalizedError {
    case invalidScene4BakedParticleDuration(phaseID: String, expected: Int, actual: Int)
    case missingScene4BakedParticlePhase(String)
    case missingScene4ParticleResource(Int)
    case missingScene4SparklesSequence
    case sourcePatternNotFound(file: String, pattern: String)
    case invalidSourceNumbers(file: String, pattern: String)

    var errorDescription: String? {
        switch self {
        case let .invalidScene4BakedParticleDuration(phaseID, expected, actual):
            return "Scene 4 baked particle phase \(phaseID) emitted \(actual) frames; expected \(expected)."
        case let .missingScene4BakedParticlePhase(phaseID):
            return "Scene 4 baked particle manifest is missing required phase \(phaseID)."
        case let .missingScene4ParticleResource(resourceID):
            return "Scene 4 particle manifest is missing required resource \(resourceID)."
        case .missingScene4SparklesSequence:
            return "Scene 4 sparkles sequence did not decode any frames."
        case let .sourcePatternNotFound(file, pattern):
            return "Could not derive opening metadata from \(file) using pattern \(pattern)."
        case let .invalidSourceNumbers(file, pattern):
            return "Found malformed opening metadata in \(file) for pattern \(pattern)."
        }
    }
}

struct OpeningHeartGoldExtractor {
    func run(config: ExtractConfiguration) throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let helperScript = repoRoot.appendingPathComponent("scripts/opening_asset_helper.py", isDirectory: false)
        let ensureToolsScript = repoRoot.appendingPathComponent("scripts/ensure_python_tools.sh", isDirectory: false)

        guard FileManager.default.fileExists(atPath: helperScript.path()) else {
            throw ExtractCLIError.missingScript(path: helperScript.path())
        }
        guard FileManager.default.fileExists(atPath: ensureToolsScript.path()) else {
            throw ExtractCLIError.missingScript(path: ensureToolsScript.path())
        }

        if config.dryRun {
            print("Extractor complete.")
            print("Mode: \(config.mode.rawValue)")
            print("Output: \(config.output.path())")
            print("Dry run: yes")
            print("Pret root: \(config.pretRoot?.path() ?? "not provided")")
            return
        }

        guard let pretRoot = config.pretRoot else {
            throw ExtractCLIError.missingPretRoot
        }

        try validateOpeningInputs(pretRoot: pretRoot)
        let parseSupportRoot = PokeheartgoldOpeningSourceValidator.defaultSupportRoot(repoRoot: repoRoot)
        _ = try PokeheartgoldOpeningSourceValidator().validate(
            pretRoot: pretRoot,
            supportRoot: parseSupportRoot
        )
        let scene3SourceURL = pretRoot.appendingPathComponent("src/intro_movie_scene_3.c", isDirectory: false)
        let scene4SourceURL = pretRoot.appendingPathComponent("src/intro_movie_scene_4.c", isDirectory: false)
        let titleScreenSourceURL = pretRoot.appendingPathComponent("src/title_screen.c", isDirectory: false)
        let scene3Source = try parseScene3Source(from: scene3SourceURL)
        let scene4Source = try parseScene4Source(from: scene4SourceURL)
        let titleHandoffSource = try parseTitleHandoffSource(from: titleScreenSourceURL)
        try runProcess(
            executable: ensureToolsScript,
            arguments: [],
            commandLabel: "ensure_python_tools.sh"
        )

        let pythonTool = repoRoot
            .appendingPathComponent("Content/Local/Tooling/ndspy-venv/bin/python", isDirectory: false)
        guard FileManager.default.fileExists(atPath: pythonTool.path()) else {
            throw ExtractCLIError.missingTool(path: pythonTool.path())
        }

        let apicula = try resolveApiculaBinary()

        let outputRoot = config.output
        if FileManager.default.fileExists(atPath: outputRoot.path()) {
            try FileManager.default.removeItem(at: outputRoot)
        }
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        let assetsRoot = outputRoot.appendingPathComponent("assets", isDirectory: true)
        let audioRoot = outputRoot.appendingPathComponent("audio", isDirectory: true)
        let intermediateRoot = outputRoot.appendingPathComponent("intermediate", isDirectory: true)
        let nitro2DRoot = intermediateRoot.appendingPathComponent("nitro2d", isDirectory: true)
        let model3DRoot = intermediateRoot.appendingPathComponent("model3d", isDirectory: true)
        let intermediateAudioRoot = intermediateRoot.appendingPathComponent("audio", isDirectory: true)
        let intermediateParticleRoot = intermediateRoot.appendingPathComponent("particle", isDirectory: true)
        for directory in [assetsRoot, audioRoot, nitro2DRoot, model3DRoot, intermediateAudioRoot, intermediateParticleRoot] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let openingDir = pretRoot.appendingPathComponent("files/demo/opening/gs_opening", isDirectory: true)
        let titleDir = pretRoot.appendingPathComponent("files/demo/title/titledemo", isDirectory: true)
        let soundArchive = pretRoot.appendingPathComponent("files/data/sound/gs_sound_data.sdat", isDirectory: false)
        let particleArchive = pretRoot.appendingPathComponent("files/a/0/5/9", isDirectory: false)

        try runPythonHelper(
            pythonTool: pythonTool,
            helperScript: helperScript,
            arguments: [
                "scene4-particles",
                "--narc", particleArchive.path(),
                "--member", "4",
                "--output-dir", intermediateParticleRoot.appendingPathComponent("scene4", isDirectory: true).path()
            ]
        )

        var assets: [HGSSOpeningBundle.Asset] = []
        var provenanceSources: [OpeningProvenanceDocument.AssetSource] = []
        var referenceAudioTraces: [OpeningReferenceDocument.AudioTrace] = []

        func registerAsset(_ asset: HGSSOpeningBundle.Asset, upstreamFiles: [String]) {
            assets.append(asset)
            provenanceSources.append(.init(assetID: asset.id, upstreamFiles: upstreamFiles))
        }

        let scene1AssetDirectory = assetsRoot.appendingPathComponent("scene1", isDirectory: true)
        let scene2AssetDirectory = assetsRoot.appendingPathComponent("scene2", isDirectory: true)
        let scene3AssetDirectory = assetsRoot.appendingPathComponent("scene3", isDirectory: true)
        let scene4AssetDirectory = assetsRoot.appendingPathComponent("scene4", isDirectory: true)
        let scene5AssetDirectory = assetsRoot.appendingPathComponent("scene5", isDirectory: true)
        let titleAssetDirectory = assetsRoot.appendingPathComponent("title_handoff", isDirectory: true)
        for directory in [
            scene1AssetDirectory,
            scene2AssetDirectory,
            scene3AssetDirectory,
            scene4AssetDirectory,
            scene5AssetDirectory,
            titleAssetDirectory,
        ] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let scene1Sub0 = try decodeTilemap(
            assetID: "scene1_bottom_sub0",
            outputName: "scene1_bottom_sub0.png",
            sceneDirectory: scene1AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene1", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000004.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000014.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000000.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_1.c"
        )
        registerAsset(scene1Sub0.asset, upstreamFiles: scene1Sub0.upstreamFiles)

        let scene1Sub1 = try decodeTilemap(
            assetID: "scene1_bottom_sub1",
            outputName: "scene1_bottom_sub1.png",
            sceneDirectory: scene1AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene1", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000004.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000012.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000000.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_1.c"
        )
        registerAsset(scene1Sub1.asset, upstreamFiles: scene1Sub1.upstreamFiles)

        let scene1Main0 = try decodeTilemap(
            assetID: "scene1_top_main0",
            outputName: "scene1_top_main0.png",
            sceneDirectory: scene1AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene1", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000005.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000013.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000001.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_1.c"
        )
        registerAsset(scene1Main0.asset, upstreamFiles: scene1Main0.upstreamFiles)

        let scene1Main1 = try decodeTilemap(
            assetID: "scene1_top_main1",
            outputName: "scene1_top_main1.png",
            sceneDirectory: scene1AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene1", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000007.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000016.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000001.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_1.c"
        )
        registerAsset(scene1Main1.asset, upstreamFiles: scene1Main1.upstreamFiles)

        let scene1Main2 = try decodeTilemap(
            assetID: "scene1_top_main2",
            outputName: "scene1_top_main2.png",
            sceneDirectory: scene1AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene1", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000007.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000017.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000001.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_1.c"
        )
        registerAsset(scene1Main2.asset, upstreamFiles: scene1Main2.upstreamFiles)

        let scene1Main3 = try decodeTilemap(
            assetID: "scene1_top_main3",
            outputName: "scene1_top_main3.png",
            sceneDirectory: scene1AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene1", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000007.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000018.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000001.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_1.c"
        )
        registerAsset(scene1Main3.asset, upstreamFiles: scene1Main3.upstreamFiles)

        let scene1CelestialSprites = try extractSpriteSequences(
            sequenceIndices: [0, 1],
            assetIDPrefix: "scene1_celestial",
            sceneDirectory: scene1AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene1/celestial", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000024.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000023.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000026.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000025.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_1.c"
        )
        for result in scene1CelestialSprites.values {
            result.assets.forEach { registerAsset($0, upstreamFiles: result.upstreamFiles) }
        }
        let scene1Sun = scene1CelestialSprites[0]
        guard let scene1Bird = scene1CelestialSprites[1] else {
            throw ExtractCLIError.missingPretRenderAsset(path: openingDir.appendingPathComponent("gs_opening_00000025.NANR", isDirectory: false).path())
        }

        let scene2Bottom = try decodeTilemap(
            assetID: "scene2_bottom_sub0",
            outputName: "scene2_bottom_sub0.png",
            sceneDirectory: scene2AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene2", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000034.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000036.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000031.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_2.c"
        )
        registerAsset(scene2Bottom.asset, upstreamFiles: scene2Bottom.upstreamFiles)

        let scene2TopMain0 = try decodeTilemap(
            assetID: "scene2_top_main0",
            outputName: "scene2_top_main0.png",
            sceneDirectory: scene2AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene2", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000033.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000038.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000032.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_2.c"
        )
        registerAsset(scene2TopMain0.asset, upstreamFiles: scene2TopMain0.upstreamFiles)

        let scene2TopMain1 = try decodeTilemap(
            assetID: "scene2_top_main1",
            outputName: "scene2_top_main1.png",
            sceneDirectory: scene2AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene2", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000033.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000037.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000032.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_2.c"
        )
        registerAsset(scene2TopMain1.asset, upstreamFiles: scene2TopMain1.upstreamFiles)

        let scene2TopMain2 = try decodeTilemap(
            assetID: "scene2_top_main2",
            outputName: "scene2_top_main2.png",
            sceneDirectory: scene2AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene2", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000033.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000035.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000032.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_2.c"
        )
        registerAsset(scene2TopMain2.asset, upstreamFiles: scene2TopMain2.upstreamFiles)

        let scene2FlowerSprites = try extractSpriteSequences(
            sequenceIndices: [0, 1, 2, 3],
            assetIDPrefix: "scene2_flower",
            sceneDirectory: scene2AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene2/flowers", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000078.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000077.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000080.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000079.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_2.c"
        )
        for result in scene2FlowerSprites.values {
            result.assets.forEach { registerAsset($0, upstreamFiles: result.upstreamFiles) }
        }

        let scene2PlayerSprites = try extractSpriteSequences(
            sequenceIndices: [0, 1, 2, 3, 4, 5],
            assetIDPrefix: "scene2_player",
            sceneDirectory: scene2AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene2/players", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000074.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000073.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000076.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000075.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_2.c"
        )
        for result in scene2PlayerSprites.values {
            result.assets.forEach { registerAsset($0, upstreamFiles: result.upstreamFiles) }
        }

        let scene3RivalPanel0 = try decodeTilemap(
            assetID: "scene3_bottom_rival_panel_0",
            outputName: "scene3_bottom_rival_panel_0.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000042.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3RivalPanel0.asset, upstreamFiles: scene3RivalPanel0.upstreamFiles)

        let scene3RivalPanel1 = try decodeTilemap(
            assetID: "scene3_bottom_rival_panel_1",
            outputName: "scene3_bottom_rival_panel_1.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000043.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3RivalPanel1.asset, upstreamFiles: scene3RivalPanel1.upstreamFiles)

        let scene3RivalPanel2 = try decodeTilemap(
            assetID: "scene3_bottom_rival_panel_2",
            outputName: "scene3_bottom_rival_panel_2.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000044.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3RivalPanel2.asset, upstreamFiles: scene3RivalPanel2.upstreamFiles)

        let scene3RivalPanel3 = try decodeTilemap(
            assetID: "scene3_bottom_rival_panel_3",
            outputName: "scene3_bottom_rival_panel_3.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000045.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3RivalPanel3.asset, upstreamFiles: scene3RivalPanel3.upstreamFiles)

        let scene3RivalBorder = try decodeTilemap(
            assetID: "scene3_bottom_rival_border",
            outputName: "scene3_bottom_rival_border.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000046.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3RivalBorder.asset, upstreamFiles: scene3RivalBorder.upstreamFiles)

        let scene3RivalWhole = try decodeTilemap(
            assetID: "scene3_bottom_rival_whole",
            outputName: "scene3_bottom_rival_whole.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000047.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3RivalWhole.asset, upstreamFiles: scene3RivalWhole.upstreamFiles)

        let scene3Entei = try decodeTilemap(
            assetID: "scene3_bottom_entei",
            outputName: "scene3_bottom_entei.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000048.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3Entei.asset, upstreamFiles: scene3Entei.upstreamFiles)

        let scene3Raikou = try decodeTilemap(
            assetID: "scene3_bottom_raikou",
            outputName: "scene3_bottom_raikou.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000040.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000049.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3Raikou.asset, upstreamFiles: scene3Raikou.upstreamFiles)

        let scene3Beast0 = try decodeTilemap(
            assetID: "scene3_bottom_rocket_0",
            outputName: "scene3_bottom_rocket_0.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000041.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000050.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3Beast0.asset, upstreamFiles: scene3Beast0.upstreamFiles)

        let scene3Beast1 = try decodeTilemap(
            assetID: "scene3_bottom_rocket_1",
            outputName: "scene3_bottom_rocket_1.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000041.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000051.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3Beast1.asset, upstreamFiles: scene3Beast1.upstreamFiles)

        let scene3Beast2 = try decodeTilemap(
            assetID: "scene3_bottom_rocket_2",
            outputName: "scene3_bottom_rocket_2.png",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000041.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000052.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3Beast2.asset, upstreamFiles: scene3Beast2.upstreamFiles)

        let scene3NewBarkModel = try convertModel(
            assetID: "scene3_top_newbark_model",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: model3DRoot.appendingPathComponent("scene3/newbark", isDirectory: true),
            apicula: apicula,
            inputs: [
                openingDir.appendingPathComponent("gs_opening_00000103.NSBMD", isDirectory: false),
                openingDir.appendingPathComponent("gs_opening_00000104.NSBCA", isDirectory: false),
                openingDir.appendingPathComponent("gs_opening_00000105.NSBTA", isDirectory: false),
            ],
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3NewBarkModel.asset, upstreamFiles: scene3NewBarkModel.upstreamFiles)

        let scene3GoldenrodModel = try convertModel(
            assetID: "scene3_top_goldenrod_model",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: model3DRoot.appendingPathComponent("scene3/goldenrod", isDirectory: true),
            apicula: apicula,
            inputs: [
                openingDir.appendingPathComponent("gs_opening_00000100.NSBMD", isDirectory: false),
                openingDir.appendingPathComponent("gs_opening_00000101.NSBCA", isDirectory: false),
                openingDir.appendingPathComponent("gs_opening_00000102.NSBTA", isDirectory: false),
            ],
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3GoldenrodModel.asset, upstreamFiles: scene3GoldenrodModel.upstreamFiles)

        let scene3EcruteakModel = try convertModel(
            assetID: "scene3_top_ecruteak_model",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: model3DRoot.appendingPathComponent("scene3/ecruteak", isDirectory: true),
            apicula: apicula,
            inputs: [
                openingDir.appendingPathComponent("gs_opening_00000097.NSBMD", isDirectory: false),
                openingDir.appendingPathComponent("gs_opening_00000098.NSBCA", isDirectory: false),
                openingDir.appendingPathComponent("gs_opening_00000099.NSBTA", isDirectory: false),
            ],
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        registerAsset(scene3EcruteakModel.asset, upstreamFiles: scene3EcruteakModel.upstreamFiles)

        let scene3Silver = try extractSpriteSequence(
            sequenceIndex: 0,
            assetIDPrefix: "scene3_silver",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3/silver", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000066.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000065.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000068.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000067.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        scene3Silver.assets.forEach { registerAsset($0, upstreamFiles: scene3Silver.upstreamFiles) }

        let scene3EusineAndUnown = try extractSpriteSequences(
            sequenceIndices: [0, 1, 2, 3],
            assetIDPrefix: "scene3_supporting",
            sceneDirectory: scene3AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene3/supporting", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000070.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000069.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000072.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000071.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_3.c"
        )
        for result in scene3EusineAndUnown.values {
            result.assets.forEach { registerAsset($0, upstreamFiles: result.upstreamFiles) }
        }

        let scene4TopMain1 = try decodeTilemap(
            assetID: "scene4_top_main1",
            outputName: "scene4_top_main1.png",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000054.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000058.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000053.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        registerAsset(scene4TopMain1.asset, upstreamFiles: scene4TopMain1.upstreamFiles)

        let scene4TopMain2 = try decodeTilemap(
            assetID: "scene4_top_main2",
            outputName: "scene4_top_main2.png",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000054.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000055.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000053.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        registerAsset(scene4TopMain2.asset, upstreamFiles: scene4TopMain2.upstreamFiles)

        let scene4TopMain3 = try decodeTilemap(
            assetID: "scene4_top_main3",
            outputName: "scene4_top_main3.png",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000054.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000056.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000053.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        registerAsset(scene4TopMain3.asset, upstreamFiles: scene4TopMain3.upstreamFiles)

        let scene4BottomSub1 = try decodeTilemap(
            assetID: "scene4_bottom_sub1",
            outputName: "scene4_bottom_sub1.png",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000054.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000057.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000053.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        registerAsset(scene4BottomSub1.asset, upstreamFiles: scene4BottomSub1.upstreamFiles)

        let scene4BottomSub2 = try decodeTilemap(
            assetID: "scene4_bottom_sub2",
            outputName: "scene4_bottom_sub2.png",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000054.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000055.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000053.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        registerAsset(scene4BottomSub2.asset, upstreamFiles: scene4BottomSub2.upstreamFiles)

        let scene4BottomSub3 = try decodeTilemap(
            assetID: "scene4_bottom_sub3",
            outputName: "scene4_bottom_sub3.png",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000054.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000056.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000053.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        registerAsset(scene4BottomSub3.asset, upstreamFiles: scene4BottomSub3.upstreamFiles)

        let scene4Hands = try extractSpriteSequences(
            sequenceIndices: [0, 1, 2],
            assetIDPrefix: "scene4_hand",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4/hand", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000082.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000081.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000084.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000083.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        for result in scene4Hands.values {
            result.assets.forEach { registerAsset($0, upstreamFiles: result.upstreamFiles) }
        }

        let scene4ParticleRoot = intermediateParticleRoot.appendingPathComponent("scene4", isDirectory: true)
        let scene4ParticleManifestURL = scene4ParticleRoot.appendingPathComponent("scene4_particles.json", isDirectory: false)
        let scene4ParticleManifest = try loadJSON(Scene4ParticleManifest.self, from: scene4ParticleManifestURL)
        let scene4BakedParticleRoot = scene4ParticleRoot.appendingPathComponent("baked", isDirectory: true)
        try runPythonHelper(
            pythonTool: pythonTool,
            helperScript: helperScript,
            arguments: [
                "bake-scene4-particles",
                "--manifest", scene4ParticleManifestURL.path(),
                "--output-dir", scene4BakedParticleRoot.path(),
                "--seed", "1",
            ]
        )
        let scene4BakedParticleManifest = try loadJSON(
            Scene4BakedParticleManifest.self,
            from: scene4BakedParticleRoot.appendingPathComponent("scene4_particle_frames.json", isDirectory: false)
        )

        let scene4Chikorita = try extractSpriteSequence(
            sequenceIndex: 0,
            assetIDPrefix: "scene4_chikorita",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4/chikorita", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000086.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000085.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000088.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000087.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        scene4Chikorita.assets.forEach { registerAsset($0, upstreamFiles: scene4Chikorita.upstreamFiles) }

        let scene4Cyndaquil = try extractSpriteSequence(
            sequenceIndex: 0,
            assetIDPrefix: "scene4_cyndaquil",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4/cyndaquil", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000094.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000093.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000096.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000095.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        scene4Cyndaquil.assets.forEach { registerAsset($0, upstreamFiles: scene4Cyndaquil.upstreamFiles) }

        let scene4Totodile = try extractSpriteSequence(
            sequenceIndex: 0,
            assetIDPrefix: "scene4_totodile",
            sceneDirectory: scene4AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene4/totodile", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000090.NCGR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000089.NCLR", isDirectory: false),
            ncer: openingDir.appendingPathComponent("gs_opening_00000092.NCER", isDirectory: false),
            nanr: openingDir.appendingPathComponent("gs_opening_00000091.NANR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        scene4Totodile.assets.forEach { registerAsset($0, upstreamFiles: scene4Totodile.upstreamFiles) }

        let scene4Timing = try makeScene4Timing(
            source: scene4Source,
            particleManifest: scene4ParticleManifest,
            sparkleFrameCount: scene4Hands[2]?.frameAssetIDs.count ?? 0
        )
        let scene3Timing = makeScene3Timing(source: scene3Source)
        let scene4GrassParticles = try copyBakedScene4ParticlePhase(
            phaseID: "grass",
            manifest: scene4BakedParticleManifest,
            manifestRoot: scene4BakedParticleRoot,
            sceneDirectory: scene4AssetDirectory,
            assetIDPrefix: "scene4_grass_particles",
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        guard scene4GrassParticles.frameAssetIDs.count == scene4Timing.grassParticleDurationFrames else {
            throw OpeningHeartGoldExtractModeError.invalidScene4BakedParticleDuration(
                phaseID: "grass",
                expected: scene4Timing.grassParticleDurationFrames,
                actual: scene4GrassParticles.frameAssetIDs.count
            )
        }
        scene4GrassParticles.assets.forEach { registerAsset($0, upstreamFiles: scene4GrassParticles.upstreamFiles) }
        let scene4FireParticles = try copyBakedScene4ParticlePhase(
            phaseID: "fire",
            manifest: scene4BakedParticleManifest,
            manifestRoot: scene4BakedParticleRoot,
            sceneDirectory: scene4AssetDirectory,
            assetIDPrefix: "scene4_fire_particles",
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        guard scene4FireParticles.frameAssetIDs.count == scene4Timing.fireParticleDurationFrames else {
            throw OpeningHeartGoldExtractModeError.invalidScene4BakedParticleDuration(
                phaseID: "fire",
                expected: scene4Timing.fireParticleDurationFrames,
                actual: scene4FireParticles.frameAssetIDs.count
            )
        }
        scene4FireParticles.assets.forEach { registerAsset($0, upstreamFiles: scene4FireParticles.upstreamFiles) }
        let scene4WaterParticles = try copyBakedScene4ParticlePhase(
            phaseID: "water",
            manifest: scene4BakedParticleManifest,
            manifestRoot: scene4BakedParticleRoot,
            sceneDirectory: scene4AssetDirectory,
            assetIDPrefix: "scene4_water_particles",
            provenance: "External/pokeheartgold/src/intro_movie_scene_4.c"
        )
        guard scene4WaterParticles.frameAssetIDs.count == scene4Timing.waterParticleDurationFrames else {
            throw OpeningHeartGoldExtractModeError.invalidScene4BakedParticleDuration(
                phaseID: "water",
                expected: scene4Timing.waterParticleDurationFrames,
                actual: scene4WaterParticles.frameAssetIDs.count
            )
        }
        scene4WaterParticles.assets.forEach { registerAsset($0, upstreamFiles: scene4WaterParticles.upstreamFiles) }

        let scene5BottomSub1 = try decodeTilemap(
            assetID: "scene5_bottom_sub1",
            outputName: "scene5_bottom_sub1.png",
            sceneDirectory: scene5AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene5", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000059.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000063.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_5.c"
        )
        registerAsset(scene5BottomSub1.asset, upstreamFiles: scene5BottomSub1.upstreamFiles)

        let scene5BottomSub2 = try decodeTilemap(
            assetID: "scene5_bottom_sub2",
            outputName: "scene5_bottom_sub2.png",
            sceneDirectory: scene5AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene5", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000059.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000061.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000039.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_5.c"
        )
        registerAsset(scene5BottomSub2.asset, upstreamFiles: scene5BottomSub2.upstreamFiles)

        let scene5TopMain1 = try decodeTilemap(
            assetID: "scene5_top_main1",
            outputName: "scene5_top_main1.png",
            sceneDirectory: scene5AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene5", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000060.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000062.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000031.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_5.c"
        )
        registerAsset(scene5TopMain1.asset, upstreamFiles: scene5TopMain1.upstreamFiles)

        let scene5TopMain2 = try decodeTilemap(
            assetID: "scene5_top_main2",
            outputName: "scene5_top_main2.png",
            sceneDirectory: scene5AssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("scene5", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: openingDir.appendingPathComponent("gs_opening_00000060.NCGR", isDirectory: false),
            nscr: openingDir.appendingPathComponent("gs_opening_00000064.NSCR", isDirectory: false),
            nclr: openingDir.appendingPathComponent("gs_opening_00000031.NCLR", isDirectory: false),
            provenance: "External/pokeheartgold/src/intro_movie_scene_5.c"
        )
        registerAsset(scene5TopMain2.asset, upstreamFiles: scene5TopMain2.upstreamFiles)

        let titleTop = try composePNGTilemap(
            assetID: "title_handoff_top",
            outputName: "title_top.png",
            sceneDirectory: titleAssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("title_handoff", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            pngSheet: titleDir.appendingPathComponent("titledemo_00000034.png", isDirectory: false),
            nscr: titleDir.appendingPathComponent("titledemo_00000035.NSCR", isDirectory: false),
            provenance: "External/pokeheartgold/src/title_screen.c"
        )
        registerAsset(titleTop.asset, upstreamFiles: titleTop.upstreamFiles)

        let titleGameFreakStrip = try composePNGTilemap(
            assetID: "title_handoff_gamefreak_strip",
            outputName: "title_gamefreak_strip.png",
            sceneDirectory: titleAssetDirectory,
            intermediateDirectory: nitro2DRoot.appendingPathComponent("title_handoff", isDirectory: true),
            helperScript: helperScript,
            pythonTool: pythonTool,
            pngSheet: titleDir.appendingPathComponent("titledemo_00000015.png", isDirectory: false),
            nscr: titleDir.appendingPathComponent("titledemo_00000017.NSCR", isDirectory: false),
            transparentTopLeft: true,
            provenance: "External/pokeheartgold/src/title_screen.c"
        )
        registerAsset(titleGameFreakStrip.asset, upstreamFiles: titleGameFreakStrip.upstreamFiles)

        let titleHoOhModel = try convertModel(
            assetID: "title_handoff_hooh_model",
            sceneDirectory: titleAssetDirectory,
            intermediateDirectory: model3DRoot.appendingPathComponent("title/hooh", isDirectory: true),
            apicula: apicula,
            inputs: [
                titleDir.appendingPathComponent("titledemo_00000025.NSBMD", isDirectory: false),
                titleDir.appendingPathComponent("titledemo_00000026.NSBCA", isDirectory: false),
                titleDir.appendingPathComponent("titledemo_00000027.NSBTA", isDirectory: false),
                titleDir.appendingPathComponent("titledemo_00000029.NSBTP", isDirectory: false),
                titleDir.appendingPathComponent("titledemo_00000028.NSBMA", isDirectory: false),
            ],
            provenance: "External/pokeheartgold/src/title_screen.c"
        )
        registerAsset(titleHoOhModel.asset, upstreamFiles: titleHoOhModel.upstreamFiles)

        let titleSparklesModel = try convertModel(
            assetID: "title_handoff_sparkles_model",
            sceneDirectory: titleAssetDirectory,
            intermediateDirectory: model3DRoot.appendingPathComponent("title/sparkles", isDirectory: true),
            apicula: apicula,
            inputs: [
                titleDir.appendingPathComponent("titledemo_00000038.NSBMD", isDirectory: false),
                titleDir.appendingPathComponent("titledemo_00000039.NSBCA", isDirectory: false),
                titleDir.appendingPathComponent("titledemo_00000040.NSBTP", isDirectory: false),
            ],
            provenance: "External/pokeheartgold/src/title_screen.c"
        )
        registerAsset(titleSparklesModel.asset, upstreamFiles: titleSparklesModel.upstreamFiles)

        let scene1AudioCue = try renderAudioCue(
            cueName: "SEQ_GS_TITLE",
            sceneID: "scene1",
            audioRoot: audioRoot,
            intermediateAudioRoot: intermediateAudioRoot,
            soundArchive: soundArchive,
            helperScript: helperScript,
            pythonTool: pythonTool,
            provenance: "External/pokeheartgold/src/intro_movie.c"
        )
        registerAsset(scene1AudioCue.asset, upstreamFiles: scene1AudioCue.upstreamFiles)
        referenceAudioTraces.append(
            .init(
                cueName: scene1AudioCue.cueName,
                sceneID: scene1AudioCue.sceneID,
                wavRelativePath: scene1AudioCue.wavRelativePath,
                traceRelativePath: scene1AudioCue.traceRelativePath,
                provenance: scene1AudioCue.upstreamFiles
            )
        )

        let titleAudioCue = try renderAudioCue(
            cueName: "SEQ_GS_POKEMON_THEME",
            sceneID: "title_handoff",
            audioRoot: audioRoot,
            intermediateAudioRoot: intermediateAudioRoot,
            soundArchive: soundArchive,
            helperScript: helperScript,
            pythonTool: pythonTool,
            provenance: "External/pokeheartgold/src/title_screen.c"
        )
        registerAsset(titleAudioCue.asset, upstreamFiles: titleAudioCue.upstreamFiles)
        referenceAudioTraces.append(
            .init(
                cueName: titleAudioCue.cueName,
                sceneID: titleAudioCue.sceneID,
                wavRelativePath: titleAudioCue.wavRelativePath,
                traceRelativePath: titleAudioCue.traceRelativePath,
                provenance: titleAudioCue.upstreamFiles
            )
        )

        assets.sort { lhs, rhs in lhs.id < rhs.id }
        provenanceSources.sort { lhs, rhs in lhs.assetID < rhs.assetID }

        let initialBundle = HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: assets,
            scenes: buildScenes(
                scene1Sun: scene1Sun,
                scene1Bird: scene1Bird,
                scene2FlowerSprites: scene2FlowerSprites,
                scene2PlayerSprites: scene2PlayerSprites,
                scene3Source: scene3Source,
                scene3Timing: scene3Timing,
                scene3Silver: scene3Silver,
                scene3EusineAndUnown: scene3EusineAndUnown,
                scene4Source: scene4Source,
                scene4Hands: scene4Hands,
                scene4Timing: scene4Timing,
                scene4GrassParticles: scene4GrassParticles.frameAssetIDs,
                scene4FireParticles: scene4FireParticles.frameAssetIDs,
                scene4WaterParticles: scene4WaterParticles.frameAssetIDs,
                scene4Chikorita: scene4Chikorita,
                scene4Cyndaquil: scene4Cyndaquil,
                scene4Totodile: scene4Totodile,
                titleHandoffSource: titleHandoffSource
            )
        )

        let bundle: HGSSOpeningBundle
        if ProcessInfo.processInfo.environment["HGSS_ENABLE_SCENEKIT_BAKE"] == "1" {
            bundle = try bakeModelScreens(
                bundle: initialBundle,
                outputRoot: outputRoot,
                provenanceSources: &provenanceSources
            )
        } else {
            bundle = initialBundle
        }

        try writeJSON(
            bundle,
            to: outputRoot.appendingPathComponent("opening_bundle.json", isDirectory: false)
        )

        let provenance = OpeningProvenanceDocument(
            mode: config.mode.rawValue,
            canonicalVariant: HGSSOpeningBundle.CanonicalVariant.heartGold.rawValue,
            pretRoot: pretRoot.path(),
            sourceFiles: [
                "External/pokeheartgold/src/intro_movie.c",
                "External/pokeheartgold/src/intro_movie_scene_1.c",
                "External/pokeheartgold/src/intro_movie_scene_2.c",
                "External/pokeheartgold/src/intro_movie_scene_3.c",
                "External/pokeheartgold/src/intro_movie_scene_4.c",
                "External/pokeheartgold/src/intro_movie_scene_5.c",
                "External/pokeheartgold/src/title_screen.c",
                "External/pokeheartgold/files/demo/opening/gs_opening",
                "External/pokeheartgold/files/demo/title/titledemo",
                "External/pokeheartgold/files/a/0/5/9",
            ],
            assetSources: provenanceSources,
            audioArchive: "External/pokeheartgold/files/data/sound/gs_sound_data.sdat"
        )
        try writeJSON(
            provenance,
            to: outputRoot.appendingPathComponent("opening_provenance.json", isDirectory: false)
        )

        let reference = OpeningReferenceDocument(
            schemaVersion: 1,
            mode: config.mode.rawValue,
            canonicalVariant: HGSSOpeningBundle.CanonicalVariant.heartGold.rawValue,
            sourceFiles: provenance.sourceFiles + [provenance.audioArchive],
            scenes: bundle.scenes.map { scene in
                .init(
                    sceneID: scene.id.rawValue,
                    durationFrames: scene.durationFrames,
                    skipAllowedFromFrame: scene.skipAllowedFromFrame,
                    transitionCueIDs: scene.transitionCues.map(\.id),
                    audioCueIDs: scene.audioCues.map(\.id)
                )
            },
            audioTraces: referenceAudioTraces.sorted { lhs, rhs in
                if lhs.sceneID == rhs.sceneID {
                    return lhs.cueName < rhs.cueName
                }
                return lhs.sceneID < rhs.sceneID
            }
        )

        let audioCueCount = bundle.scenes.flatMap(\.audioCues).count
        let report = OpeningExtractReport(
            mode: config.mode.rawValue,
            canonicalVariant: HGSSOpeningBundle.CanonicalVariant.heartGold.rawValue,
            sceneCount: bundle.scenes.count,
            assetCount: bundle.assets.count,
            audioCueCount: audioCueCount,
            referenceTraceCount: reference.audioTraces.count,
            outputRoot: outputRoot.path(),
            pretRoot: pretRoot.path()
        )
        try OpeningHeartGoldArtifactWriter().write(
            bundle: bundle,
            provenance: provenance,
            reference: reference,
            report: report,
            outputRoot: outputRoot
        )

        print("Extractor complete.")
        print("Mode: \(config.mode.rawValue)")
        print("Output: \(outputRoot.path())")
        print("Dry run: no")
        print("Scenes: \(bundle.scenes.count)")
        print("Assets: \(bundle.assets.count)")
        print("Audio cues: \(audioCueCount)")
        print("Pret root: \(pretRoot.path())")
    }

    private func buildScenes(
        scene1Sun: SpriteSequenceResult?,
        scene1Bird: SpriteSequenceResult,
        scene2FlowerSprites: [Int: SpriteSequenceResult],
        scene2PlayerSprites: [Int: SpriteSequenceResult],
        scene3Source: Scene3SourceConfig,
        scene3Timing: Scene3Timing,
        scene3Silver: SpriteSequenceResult,
        scene3EusineAndUnown: [Int: SpriteSequenceResult],
        scene4Source: Scene4SourceConfig,
        scene4Hands: [Int: SpriteSequenceResult],
        scene4Timing: Scene4Timing,
        scene4GrassParticles: [String],
        scene4FireParticles: [String],
        scene4WaterParticles: [String],
        scene4Chikorita: SpriteSequenceResult,
        scene4Cyndaquil: SpriteSequenceResult,
        scene4Totodile: SpriteSequenceResult,
        titleHandoffSource: TitleHandoffSourceConfig
    ) -> [HGSSOpeningBundle.Scene] {
        let fullScreen = HGSSOpeningBundle.ScreenRect(x: 0, y: 0, width: 256, height: 192)
        let tallScreen = HGSSOpeningBundle.ScreenRect(x: 0, y: 0, width: 256, height: 256)
        let scene3Camera = HGSSOpeningBundle.ModelAnimationRef.CameraState(
            position: .init(x: 0, y: 352.41914372271066, z: 307.32376850882963),
            target: .init(x: 0, y: 0, z: 96),
            fieldOfViewDegrees: 13.3648681640625
        )
        let scene3NewBarkMaterial = HGSSOpeningBundle.ModelAnimationRef.MaterialState(
            diffuseHex: rgb15Hex(red: 15, green: 15, blue: 15),
            ambientHex: rgb15Hex(red: 9, green: 11, blue: 11),
            specularHex: rgb15Hex(red: 16, green: 16, blue: 16),
            emissionHex: rgb15Hex(red: 14, green: 14, blue: 14)
        )
        let scene3GoldenrodMaterial = HGSSOpeningBundle.ModelAnimationRef.MaterialState(
            diffuseHex: rgb15Hex(red: 14, green: 14, blue: 16),
            ambientHex: rgb15Hex(red: 10, green: 10, blue: 10),
            specularHex: rgb15Hex(red: 14, green: 14, blue: 16),
            emissionHex: rgb15Hex(red: 8, green: 8, blue: 11)
        )
        let scene3EcruteakMaterial = HGSSOpeningBundle.ModelAnimationRef.MaterialState(
            diffuseHex: rgb15Hex(red: 15, green: 15, blue: 15),
            ambientHex: rgb15Hex(red: 11, green: 12, blue: 12),
            specularHex: rgb15Hex(red: 17, green: 17, blue: 17),
            emissionHex: rgb15Hex(red: 8, green: 8, blue: 7)
        )
        let scene3NewBarkLights: [HGSSOpeningBundle.ModelAnimationRef.LightState] = [
            .init(direction: .init(x: -0.46923828125, y: -0.8662109375, z: -0.072265625), colorHex: rgb15Hex(red: 22, green: 22, blue: 20)),
            .init(direction: .init(x: 0, y: 0, z: 0), colorHex: rgb15Hex(red: 0, green: 0, blue: 0)),
            .init(direction: .init(x: 0, y: 0, z: 1), colorHex: rgb15Hex(red: 0, green: 4, blue: 9)),
            .init(direction: .init(x: 0, y: 0, z: 1), colorHex: rgb15Hex(red: 0, green: 0, blue: 0)),
        ]
        let scene3GoldenrodLights: [HGSSOpeningBundle.ModelAnimationRef.LightState] = [
            .init(direction: .init(x: -0.46728515625, y: -0.8662109375, z: -0.072265625), colorHex: rgb15Hex(red: 11, green: 11, blue: 16)),
            .init(direction: .init(x: 0, y: 0, z: 0), colorHex: rgb15Hex(red: 0, green: 0, blue: 0)),
            .init(direction: .init(x: 0, y: 0, z: 1), colorHex: rgb15Hex(red: 18, green: 10, blue: 0)),
            .init(direction: .init(x: 0, y: 0, z: 1), colorHex: rgb15Hex(red: 0, green: 0, blue: 0)),
        ]
        let scene3EcruteakLights: [HGSSOpeningBundle.ModelAnimationRef.LightState] = [
            .init(direction: .init(x: -0.46728515625, y: -0.8662109375, z: -0.072265625), colorHex: rgb15Hex(red: 19, green: 16, blue: 12)),
            .init(direction: .init(x: 0, y: 0, z: 0), colorHex: rgb15Hex(red: 0, green: 0, blue: 0)),
            .init(direction: .init(x: 0, y: 0, z: 1), colorHex: rgb15Hex(red: 16, green: 6, blue: 0)),
            .init(direction: .init(x: 0, y: 0, z: 1), colorHex: rgb15Hex(red: 0, green: 0, blue: 0)),
        ]
        let scene2FlowerSequenceOrder = [0, 1, 2, 3, 0, 1, 2, 3, 0, 1]
        let scene2FlowerStartFrames = [1, 8, 16, 24, 28, 32, 34, 38, 42, 48]
        let scene2FlowerAnimations = scene2FlowerSequenceOrder.enumerated().map { index, sequenceIndex in
            HGSSOpeningBundle.SpriteAnimationRef(
                id: "scene2_flower_\(index)_anim",
                screen: .bottom,
                frameAssetIDs: scene2FlowerSprites[sequenceIndex]?.frameAssetIDs ?? [],
                screenRect: spriteRect(
                    from: scene2FlowerSprites[sequenceIndex],
                    positionX: 128,
                    positionY: 192,
                    surfaceY: 192
                ),
                frameDurationFrames: 1,
                startFrame: scene2FlowerStartFrames[index],
                loop: true,
                zIndex: 4
            )
        }
        let scene2FlowerExitCues = scene2FlowerAnimations.map {
            HGSSOpeningBundle.TransitionCue(
                id: "\($0.id)_exit",
                kind: .scroll,
                targetID: $0.id,
                startFrame: 56,
                durationFrames: 5,
                offsetY: 192
            )
        }
        let scene2PlayerAnimations: [HGSSOpeningBundle.SpriteAnimationRef] = [
            .init(
                id: "scene2_ethan_0_anim",
                screen: .top,
                frameAssetIDs: staticFrameAssetIDs(from: scene2PlayerSprites[0]),
                screenRect: spriteRect(from: scene2PlayerSprites[0], positionX: 64, positionY: -96),
                frameDurationFrames: 1,
                loop: false,
                zIndex: 5
            ),
            .init(
                id: "scene2_ethan_1_anim",
                screen: .top,
                frameAssetIDs: staticFrameAssetIDs(from: scene2PlayerSprites[1]),
                screenRect: spriteRect(from: scene2PlayerSprites[1], positionX: 64, positionY: -96),
                frameDurationFrames: 1,
                loop: false,
                zIndex: 5
            ),
            .init(
                id: "scene2_ethan_2_anim",
                screen: .top,
                frameAssetIDs: staticFrameAssetIDs(from: scene2PlayerSprites[2]),
                screenRect: spriteRect(from: scene2PlayerSprites[2], positionX: 64, positionY: -96),
                frameDurationFrames: 1,
                loop: false,
                zIndex: 5
            ),
            .init(
                id: "scene2_lyra_0_anim",
                screen: .top,
                frameAssetIDs: staticFrameAssetIDs(from: scene2PlayerSprites[3]),
                screenRect: spriteRect(from: scene2PlayerSprites[3], positionX: 320, positionY: -96),
                frameDurationFrames: 1,
                loop: false,
                zIndex: 5
            ),
            .init(
                id: "scene2_lyra_1_anim",
                screen: .top,
                frameAssetIDs: staticFrameAssetIDs(from: scene2PlayerSprites[4]),
                screenRect: spriteRect(from: scene2PlayerSprites[4], positionX: 320, positionY: -96),
                frameDurationFrames: 1,
                loop: false,
                zIndex: 5
            ),
            .init(
                id: "scene2_lyra_2_anim",
                screen: .top,
                frameAssetIDs: staticFrameAssetIDs(from: scene2PlayerSprites[5]),
                screenRect: spriteRect(from: scene2PlayerSprites[5], positionX: 320, positionY: -96),
                frameDurationFrames: 1,
                loop: false,
                zIndex: 5
            ),
        ]
        let scene2PlayerMotionCues = scene2PlayerAnimations.flatMap { animation in
            [
                HGSSOpeningBundle.TransitionCue(
                    id: "\(animation.id)_fly_in",
                    kind: .scroll,
                    targetID: animation.id,
                    startFrame: 56,
                    durationFrames: 5,
                    offsetY: 192
                ),
                HGSSOpeningBundle.TransitionCue(
                    id: "\(animation.id)_slow_pan_ethan",
                    kind: .scroll,
                    targetID: animation.id,
                    startFrame: 64,
                    durationFrames: 90,
                    offsetX: -32
                ),
                HGSSOpeningBundle.TransitionCue(
                    id: "\(animation.id)_fast_pan_to_lyra",
                    kind: .scroll,
                    targetID: animation.id,
                    startFrame: 154,
                    durationFrames: 7,
                    offsetX: -64
                ),
                HGSSOpeningBundle.TransitionCue(
                    id: "\(animation.id)_slow_pan_lyra",
                    kind: .scroll,
                    targetID: animation.id,
                    startFrame: 161,
                    durationFrames: 66,
                    offsetX: -32
                ),
                HGSSOpeningBundle.TransitionCue(
                    id: "\(animation.id)_vertical_exit",
                    kind: .scroll,
                    targetID: animation.id,
                    startFrame: 227,
                    durationFrames: 10,
                    offsetY: 128
                ),
            ]
        }

        let scene1: HGSSOpeningBundle.Scene = .init(
                id: .scene1,
                durationFrames: 745,
                skipAllowedFromFrame: 110,
                topLayers: [
                    .init(id: "scene1_top_logo", assetID: "scene1_top_main0", screenRect: fullScreen, zIndex: 1, startFrame: 0, endFrame: 219),
                    .init(id: "scene1_sunrise_back", assetID: "scene1_top_main1", screenRect: tallScreen, zIndex: 1, startFrame: 220),
                    .init(id: "scene1_sunrise_mid", assetID: "scene1_top_main2", screenRect: tallScreen, zIndex: 2, startFrame: 220),
                    .init(id: "scene1_sunrise_front", assetID: "scene1_top_main3", screenRect: tallScreen, zIndex: 3, startFrame: 220),
                ],
                bottomLayers: [
                    .init(id: "scene1_bottom_copyright", assetID: "scene1_bottom_sub0", screenRect: fullScreen, zIndex: 1, startFrame: 0, endFrame: 109),
                    .init(id: "scene1_bottom_gamefreak", assetID: "scene1_bottom_sub1", screenRect: fullScreen, zIndex: 1, startFrame: 110, endFrame: 219),
                    .init(id: "scene1_bottom_sunrise", assetID: "scene1_bottom_sub1", screenRect: fullScreen, zIndex: 1, startFrame: 220),
                ],
                spriteAnimations: [
                    .init(
                        id: "scene1_sun_anim",
                        screen: .top,
                        frameAssetIDs: scene1Sun?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene1Sun, positionX: 128, positionY: 96),
                        frameDurationFrames: 1,
                        startFrame: 221,
                        loop: true,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene1_bird_anim",
                        screen: .top,
                        frameAssetIDs: scene1Bird.frameAssetIDs,
                        screenRect: spriteRect(from: scene1Bird, positionX: 128, positionY: 96),
                        frameDurationFrames: 1,
                        startFrame: 589,
                        loop: true,
                        zIndex: 5
                    )
                ],
                modelAnimations: [],
                transitionCues: [
                    .init(id: "scene1_top_scroll_back", kind: .scroll, targetID: "scene1_sunrise_back", startFrame: 221, durationFrames: 240, offsetY: -32),
                    .init(id: "scene1_top_scroll_mid", kind: .scroll, targetID: "scene1_sunrise_mid", startFrame: 221, durationFrames: 240, offsetY: -16),
                    .init(id: "scene1_fade_white", kind: .fade, screen: .top, startFrame: 679, durationFrames: 65, fromValue: 0.0, toValue: 1.0, colorHex: "#FFFFFF"),
                    .init(id: "scene1_fade_white_bottom", kind: .fade, screen: .bottom, startFrame: 679, durationFrames: 65, fromValue: 0.0, toValue: 1.0, colorHex: "#FFFFFF"),
                ],
                audioCues: [
                    .init(
                        id: "scene1_bgm_start",
                        action: .startBGM,
                        cueName: "SEQ_GS_TITLE",
                        frame: 0,
                        playableAssetID: "scene1_seq_gs_title_audio",
                        provenance: "External/pokeheartgold/src/intro_movie.c"
                    ),
                ]
            )

        let scene2: HGSSOpeningBundle.Scene = .init(
                id: .scene2,
                durationFrames: 246,
                skipAllowedFromFrame: 0,
                topLayers: [
                    .init(id: "scene2_top_main0_layer", assetID: "scene2_top_main0", screenRect: .init(x: 0, y: -192, width: 256, height: 256), wraps: true, zIndex: 1),
                    .init(id: "scene2_top_main1_layer", assetID: "scene2_top_main1", screenRect: .init(x: 0, y: -320, width: 512, height: 512), wraps: true, zIndex: 2),
                    .init(id: "scene2_top_main2_layer", assetID: "scene2_top_main2", screenRect: .init(x: 0, y: -64, width: 256, height: 256), wraps: true, zIndex: 3),
                ],
                bottomLayers: [
                    .init(id: "scene2_bottom_sub0_layer", assetID: "scene2_bottom_sub0", screenRect: .init(x: 0, y: -64, width: 256, height: 256), wraps: true, zIndex: 1),
                ],
                spriteAnimations: scene2FlowerAnimations + scene2PlayerAnimations,
                modelAnimations: [],
                transitionCues: [
                    .init(id: "scene2_fade_from_white_top", kind: .fade, screen: .top, startFrame: 0, durationFrames: 3, fromValue: 1.0, toValue: 0.0, colorHex: "#FFFFFF"),
                    .init(id: "scene2_fade_from_white_bottom", kind: .fade, screen: .bottom, startFrame: 0, durationFrames: 3, fromValue: 1.0, toValue: 0.0, colorHex: "#FFFFFF"),
                    .init(id: "scene2_scroll_main1_slow_pan_ethan", kind: .scroll, targetID: "scene2_top_main1_layer", startFrame: 64, durationFrames: 90, offsetX: 32),
                    .init(id: "scene2_scroll_main0_slow_pan_ethan", kind: .scroll, targetID: "scene2_top_main0_layer", startFrame: 64, durationFrames: 90, offsetX: 32),
                    .init(id: "scene2_scroll_main1_fast_pan_to_lyra", kind: .scroll, targetID: "scene2_top_main1_layer", startFrame: 154, durationFrames: 7, offsetX: 64),
                    .init(id: "scene2_scroll_main0_fast_pan_to_lyra", kind: .scroll, targetID: "scene2_top_main0_layer", startFrame: 154, durationFrames: 7, offsetX: 64),
                    .init(id: "scene2_scroll_main1_slow_pan_lyra", kind: .scroll, targetID: "scene2_top_main1_layer", startFrame: 161, durationFrames: 66, offsetX: 32),
                    .init(id: "scene2_scroll_main0_slow_pan_lyra", kind: .scroll, targetID: "scene2_top_main0_layer", startFrame: 161, durationFrames: 66, offsetX: 32),
                    .init(id: "scene2_scroll_main1_vertical_exit", kind: .scroll, targetID: "scene2_top_main1_layer", startFrame: 227, durationFrames: 10, offsetY: -128),
                    .init(id: "scene2_scroll_main0_vertical_exit", kind: .scroll, targetID: "scene2_top_main0_layer", startFrame: 227, durationFrames: 5, offsetY: -64),
                    .init(id: "scene2_circle_wipe_out", kind: .circleWipe, screen: .top, startFrame: 237, durationFrames: 8, colorHex: "#FFFFFF", mode: 1, revealsInside: true),
                ] + scene2FlowerExitCues + scene2PlayerMotionCues,
                audioCues: []
            )

        let scene3BottomLayers: [HGSSOpeningBundle.LayerRef] = [
                    .init(id: "scene3_rival_panel_0_layer", assetID: "scene3_bottom_rival_panel_0", screenRect: fullScreen, zIndex: 1, startFrame: scene3Timing.rivalPanelsStartFrame, endFrame: scene3Timing.rivalPanelSwapFrames[0] - 1),
                    .init(id: "scene3_rival_panel_1_layer", assetID: "scene3_bottom_rival_panel_1", screenRect: fullScreen, zIndex: 1, startFrame: scene3Timing.rivalPanelSwapFrames[0], endFrame: scene3Timing.rivalPanelSwapFrames[1] - 1),
                    .init(id: "scene3_rival_panel_2_layer", assetID: "scene3_bottom_rival_panel_2", screenRect: fullScreen, zIndex: 1, startFrame: scene3Timing.rivalPanelSwapFrames[1], endFrame: scene3Timing.rivalPanelSwapFrames[2] - 1),
                    .init(id: "scene3_rival_panel_3_layer", assetID: "scene3_bottom_rival_panel_3", screenRect: fullScreen, zIndex: 1, startFrame: scene3Timing.rivalPanelSwapFrames[2], endFrame: scene3Timing.rivalWholeRevealStartFrame - 45),
                    .init(id: "scene3_rival_border_layer", assetID: "scene3_bottom_rival_border", screenRect: fullScreen, zIndex: 2, startFrame: scene3Timing.rivalPanelsStartFrame, endFrame: scene3Timing.rivalWholeRevealStartFrame - 45),
                    .init(id: "scene3_rival_whole_layer", assetID: "scene3_bottom_rival_whole", screenRect: fullScreen, zIndex: 1, startFrame: scene3Timing.rivalWholeRevealStartFrame - 44, endFrame: scene3Timing.rocketExpandStartFrame - 1),
                    .init(id: "scene3_entei_layer", assetID: "scene3_bottom_entei", screenRect: fullScreen, zIndex: 2, startFrame: scene3Timing.enteiRevealStartFrame, endFrame: scene3Timing.unown1StartFrame - 2),
                    .init(id: "scene3_raikou_layer", assetID: "scene3_bottom_raikou", screenRect: fullScreen, zIndex: 3, startFrame: scene3Timing.raikouRevealStartFrame, endFrame: scene3Timing.rocketLayersStartFrame - 1),
                    .init(id: "scene3_rocket_0_layer", assetID: "scene3_bottom_rocket_0", screenRect: fullScreen, zIndex: 1, startFrame: scene3Timing.rocketLayersStartFrame),
                    .init(id: "scene3_rocket_1_layer", assetID: "scene3_bottom_rocket_1", screenRect: fullScreen, zIndex: 2, startFrame: scene3Timing.rocketLayersStartFrame),
                    .init(id: "scene3_rocket_2_layer", assetID: "scene3_bottom_rocket_2", screenRect: fullScreen, zIndex: 3, startFrame: scene3Timing.rocketLayersStartFrame),
                ]

        let scene3SpriteAnimations: [HGSSOpeningBundle.SpriteAnimationRef] = [
                    .init(
                        id: "scene3_silver_anim",
                        screen: .bottom,
                        frameAssetIDs: scene3Silver.frameAssetIDs,
                        screenRect: spriteRect(from: scene3Silver, positionX: 128, positionY: 608, surfaceY: 512),
                        frameDurationFrames: 1,
                        startFrame: 0,
                        endFrame: scene3Timing.rivalPanelSwapFrames[2] - 1,
                        loop: true,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene3_eusine_anim",
                        screen: .bottom,
                        frameAssetIDs: scene3EusineAndUnown[0]?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene3EusineAndUnown[0], positionX: 32, positionY: 608, surfaceY: 512),
                        frameDurationFrames: 1,
                        startFrame: scene3Timing.eusineStartFrame,
                        loop: true,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene3_unown_0_anim",
                        screen: .bottom,
                        frameAssetIDs: scene3EusineAndUnown[1]?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene3EusineAndUnown[1], positionX: 128, positionY: 544, surfaceY: 512),
                        frameDurationFrames: 1,
                        startFrame: scene3Timing.unown0StartFrame,
                        loop: true,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene3_unown_1_anim",
                        screen: .bottom,
                        frameAssetIDs: scene3EusineAndUnown[2]?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene3EusineAndUnown[2], positionX: 128, positionY: 672, surfaceY: 512),
                        frameDurationFrames: 1,
                        startFrame: scene3Timing.unown1StartFrame,
                        loop: true,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene3_unown_2_anim",
                        screen: .bottom,
                        frameAssetIDs: scene3EusineAndUnown[3]?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene3EusineAndUnown[3], positionX: 128, positionY: 608, surfaceY: 512),
                        frameDurationFrames: 1,
                        startFrame: scene3Timing.unown2StartFrame,
                        loop: true,
                        zIndex: 4
                    ),
                ]

        let scene3ModelAnimations: [HGSSOpeningBundle.ModelAnimationRef] = [
                    .init(
                        id: "scene3_newbark_model",
                        screen: .top,
                        assetID: "scene3_top_newbark_model",
                        screenRect: fullScreen,
                        startFrame: 0,
                        endFrame: scene3Timing.goldenrodStartFrame - 1,
                        zIndex: 1,
                        camera: scene3Camera,
                        lights: scene3NewBarkLights,
                        material: scene3NewBarkMaterial
                    ),
                    .init(
                        id: "scene3_goldenrod_model",
                        screen: .top,
                        assetID: "scene3_top_goldenrod_model",
                        screenRect: fullScreen,
                        startFrame: scene3Timing.goldenrodStartFrame,
                        endFrame: scene3Timing.ecruteakStartFrame - 1,
                        zIndex: 1,
                        camera: scene3Camera,
                        lights: scene3GoldenrodLights,
                        material: scene3GoldenrodMaterial
                    ),
                    .init(
                        id: "scene3_ecruteak_model",
                        screen: .top,
                        assetID: "scene3_top_ecruteak_model",
                        screenRect: fullScreen,
                        startFrame: scene3Timing.ecruteakStartFrame,
                        endFrame: scene3Timing.ecruteakHideStartFrame + scene3Source.circleWipeDurationFrames - 1,
                        zIndex: 1,
                        camera: scene3Camera,
                        lights: scene3EcruteakLights,
                        material: scene3EcruteakMaterial
                    ),
                ]

        let scene3TransitionCues: [HGSSOpeningBundle.TransitionCue] = [
                    .init(id: "scene3_circle_newbark_reveal", kind: .circleWipe, screen: .top, startFrame: 0, durationFrames: scene3Source.circleWipeDurationFrames, colorHex: "#FFFFFF", mode: 0, revealsInside: false),
                    .init(id: "scene3_circle_newbark_hide", kind: .circleWipe, screen: .top, startFrame: scene3Timing.goldenrodStartFrame - scene3Source.circleWipeDurationFrames, durationFrames: scene3Source.circleWipeDurationFrames, colorHex: "#000000", mode: 3, revealsInside: true),
                    .init(id: "scene3_circle_goldenrod_reveal", kind: .circleWipe, screen: .top, startFrame: scene3Timing.goldenrodStartFrame, durationFrames: scene3Source.circleWipeDurationFrames, colorHex: "#000000", mode: 2, revealsInside: false),
                    .init(id: "scene3_circle_goldenrod_hide", kind: .circleWipe, screen: .top, startFrame: scene3Timing.ecruteakStartFrame - scene3Source.circleWipeDurationFrames, durationFrames: scene3Source.circleWipeDurationFrames, colorHex: "#000000", mode: 3, revealsInside: true),
                    .init(id: "scene3_circle_ecruteak_reveal", kind: .circleWipe, screen: .top, startFrame: scene3Timing.ecruteakStartFrame, durationFrames: scene3Source.circleWipeDurationFrames, colorHex: "#000000", mode: 2, revealsInside: false),
                    .init(id: "scene3_circle_ecruteak_hide", kind: .circleWipe, screen: .top, startFrame: scene3Timing.ecruteakHideStartFrame, durationFrames: scene3Source.circleWipeDurationFrames, colorHex: "#000000", mode: 3, revealsInside: true),
                    .init(id: "scene3_circle_rival_reveal", kind: .circleWipe, screen: .bottom, startFrame: scene3Timing.rivalRevealStartFrame, durationFrames: scene3Source.circleWipeDurationFrames, colorHex: "#000000", mode: 2, revealsInside: false),
                    .init(id: "scene3_window_cinematic_aspect", kind: .window, screen: .bottom, startFrame: scene3Timing.rivalWholeRevealStartFrame - scene3Source.rivalWholeRevealDelay + scene3Source.cinematicAspectDelay - 1, durationFrames: scene3Source.rivalWholeRevealWindow.durationFrames - 2, fromRect: .init(x: 0, y: 0, width: 255, height: 192), toRect: .init(x: 0, y: 64, width: 255, height: 64)),
                    .init(id: "scene3_window_entei_reveal", kind: .window, screen: .bottom, startFrame: scene3Timing.rivalWholeRevealStartFrame, durationFrames: scene3Source.rivalWholeRevealWindow.durationFrames, fromRect: scene3Source.rivalWholeRevealWindow.fromRect, toRect: scene3Source.rivalWholeRevealWindow.toRect),
                    .init(id: "scene3_window_entei_to_raikou", kind: .window, screen: .bottom, startFrame: scene3Timing.enteiRevealStartFrame, durationFrames: scene3Source.enteiRevealWindow.durationFrames, fromRect: scene3Source.enteiRevealWindow.fromRect, toRect: scene3Source.enteiRevealWindow.toRect),
                    .init(id: "scene3_window_raikou_full", kind: .window, screen: .bottom, startFrame: scene3Timing.raikouRevealStartFrame, durationFrames: scene3Source.raikouRevealWindow.durationFrames, fromRect: scene3Source.raikouRevealWindow.fromRect, toRect: scene3Source.raikouRevealWindow.toRect),
                    .init(id: "scene3_window_narrow_x", kind: .window, screen: .bottom, startFrame: scene3Timing.narrowWindowStartFrame, durationFrames: scene3Source.narrowWindow.durationFrames, fromRect: scene3Source.narrowWindow.fromRect, toRect: scene3Source.narrowWindow.toRect),
                    .init(
                        id: "scene3_window_entei_exit",
                        kind: .window,
                        screen: .bottom,
                        startFrame: scene3Timing.unown0StartFrame,
                        durationFrames: scene3Source.enteiExitWindow.durationFrames,
                        fromRect: scene3Source.enteiExitWindow.fromRect,
                        toRect: scene3Source.enteiExitWindow.toRect,
                        auxiliaryFromRect: .init(x: 70, y: 64, width: 115, height: 128),
                        auxiliaryToRect: .init(x: 70, y: 64, width: 115, height: 128)
                    ),
                    .init(
                        id: "scene3_window_raikou_exit",
                        kind: .window,
                        screen: .bottom,
                        startFrame: scene3Timing.unown1StartFrame + scene3Source.raikouExitDelay - 1,
                        durationFrames: scene3Source.raikouExitWindow.durationFrames,
                        fromRect: scene3Source.raikouExitWindow.fromRect,
                        toRect: scene3Source.raikouExitWindow.toRect,
                        auxiliaryFromRect: .init(x: 70, y: 64, width: 115, height: 64),
                        auxiliaryToRect: .init(x: 70, y: 64, width: 115, height: 64)
                    ),
                    .init(
                        id: "scene3_window_suicune_exit",
                        kind: .window,
                        screen: .bottom,
                        startFrame: scene3Timing.unown2StartFrame + scene3Source.suicuneExitDelay - 1,
                        durationFrames: scene3Source.suicuneExitWindow.durationFrames,
                        fromRect: scene3Source.suicuneExitWindow.fromRect,
                        toRect: scene3Source.suicuneExitWindow.toRect,
                        auxiliaryFromRect: .init(x: 70, y: 64, width: 115, height: 64),
                        auxiliaryToRect: .init(x: 70, y: 64, width: 115, height: 64)
                    ),
                    .init(id: "scene3_window_expand_rocket", kind: .window, screen: .bottom, startFrame: scene3Timing.rocketExpandStartFrame, durationFrames: scene3Source.rocketExpandWindow.durationFrames, fromRect: scene3Source.rocketExpandWindow.fromRect, toRect: scene3Source.rocketExpandWindow.toRect),
                    .init(id: "scene3_scroll_rival_whole_reveal", kind: .scroll, targetID: "scene3_rival_whole_layer", startFrame: scene3Timing.rivalWholeRevealStartFrame, durationFrames: scene3Source.rivalWholeRevealWindow.durationFrames, offsetX: -256),
                    .init(id: "scene3_scroll_entei_reveal", kind: .scroll, targetID: "scene3_entei_layer", startFrame: scene3Timing.enteiRevealStartFrame, durationFrames: scene3Source.enteiRevealScrollDuration, offsetX: 256),
                    .init(id: "scene3_scroll_raikou_reveal", kind: .scroll, targetID: "scene3_raikou_layer", startFrame: scene3Timing.raikouRevealStartFrame, durationFrames: scene3Source.raikouRevealScrollDuration, offsetX: -256),
                    .init(id: "scene3_scroll_entei_exit", kind: .scroll, targetID: "scene3_entei_layer", startFrame: scene3Timing.unown0StartFrame, durationFrames: scene3Source.enteiExitScrollDuration, offsetX: -116),
                    .init(id: "scene3_scroll_raikou_exit", kind: .scroll, targetID: "scene3_raikou_layer", startFrame: scene3Timing.unown1StartFrame + scene3Source.raikouExitDelay - 1, durationFrames: scene3Source.raikouExitScrollDuration, offsetX: -116),
                    .init(id: "scene3_scroll_rival_whole_return", kind: .scroll, targetID: "scene3_rival_whole_layer", startFrame: scene3Timing.unown2StartFrame + scene3Source.suicuneExitDelay - 1, durationFrames: scene3Source.suicuneExitScrollDuration, offsetX: 116),
                    .init(id: "scene3_scroll_rocket_0", kind: .scroll, targetID: "scene3_rocket_0_layer", startFrame: scene3Timing.rocketExpandStartFrame, durationFrames: scene3Source.rocketScrollDurationFrames, offsetY: Double(scene3Source.rocketScrollOffsetsY[0])),
                    .init(id: "scene3_scroll_rocket_1", kind: .scroll, targetID: "scene3_rocket_1_layer", startFrame: scene3Timing.rocketExpandStartFrame, durationFrames: scene3Source.rocketScrollDurationFrames, offsetY: Double(scene3Source.rocketScrollOffsetsY[1])),
                    .init(id: "scene3_scroll_rocket_2", kind: .scroll, targetID: "scene3_rocket_2_layer", startFrame: scene3Timing.rocketExpandStartFrame, durationFrames: scene3Source.rocketScrollDurationFrames, offsetY: Double(scene3Source.rocketScrollOffsetsY[2])),
                ]

        let scene3: HGSSOpeningBundle.Scene = .init(
                id: .scene3,
                durationFrames: scene3Timing.durationFrames,
                skipAllowedFromFrame: 0,
                topLayers: [],
                bottomLayers: scene3BottomLayers,
                spriteAnimations: scene3SpriteAnimations,
                modelAnimations: scene3ModelAnimations,
                transitionCues: scene3TransitionCues,
                audioCues: []
            )

        let scene4TopLayers: [HGSSOpeningBundle.LayerRef] = [
                    .init(id: "scene4_top_sub1_layer", assetID: "scene4_bottom_sub1", screenRect: .init(x: Double(scene4Source.initialTopLayerX), y: 0, width: 256, height: 192), zIndex: 1, startFrame: scene4Timing.slideInStartFrame, endFrame: scene4Timing.playersEndFrame),
                    .init(id: "scene4_top_sub2_phase_a", assetID: "scene4_bottom_sub2", screenRect: fullScreen, zIndex: 2, startFrame: 0, endFrame: scene4Timing.chikoritaEndFrame),
                    .init(id: "scene4_top_sub3_phase_a", assetID: "scene4_bottom_sub3", screenRect: fullScreen, zIndex: 3, startFrame: 0, endFrame: scene4Timing.chikoritaEndFrame),
                    .init(id: "scene4_top_main2_phase_b", assetID: "scene4_top_main2", screenRect: fullScreen, zIndex: 2, startFrame: scene4Timing.cyndaquilStartFrame, endFrame: scene4Timing.cyndaquilEndFrame),
                    .init(id: "scene4_top_main3_phase_b", assetID: "scene4_top_main3", screenRect: fullScreen, zIndex: 3, startFrame: scene4Timing.cyndaquilStartFrame, endFrame: scene4Timing.cyndaquilEndFrame),
                    .init(id: "scene4_top_sub2_phase_c", assetID: "scene4_bottom_sub2", screenRect: fullScreen, zIndex: 2, startFrame: scene4Timing.totodileStartFrame, endFrame: scene4Timing.totodileEndFrame),
                    .init(id: "scene4_top_sub3_phase_c", assetID: "scene4_bottom_sub3", screenRect: fullScreen, zIndex: 3, startFrame: scene4Timing.totodileStartFrame, endFrame: scene4Timing.totodileEndFrame),
                ]

        let scene4BottomLayers: [HGSSOpeningBundle.LayerRef] = [
                    .init(id: "scene4_bottom_main1_layer", assetID: "scene4_top_main1", screenRect: .init(x: Double(scene4Source.initialBottomLayerX), y: 0, width: 256, height: 192), zIndex: 1, startFrame: scene4Timing.slideInStartFrame, endFrame: scene4Timing.playersEndFrame),
                    .init(id: "scene4_bottom_main2_phase_a", assetID: "scene4_top_main2", screenRect: fullScreen, zIndex: 2, startFrame: 0, endFrame: scene4Timing.chikoritaEndFrame),
                    .init(id: "scene4_bottom_main3_phase_a", assetID: "scene4_top_main3", screenRect: fullScreen, zIndex: 3, startFrame: 0, endFrame: scene4Timing.chikoritaEndFrame),
                    .init(id: "scene4_bottom_sub2_phase_b", assetID: "scene4_bottom_sub2", screenRect: fullScreen, zIndex: 2, startFrame: scene4Timing.cyndaquilStartFrame, endFrame: scene4Timing.cyndaquilEndFrame),
                    .init(id: "scene4_bottom_sub3_phase_b", assetID: "scene4_bottom_sub3", screenRect: fullScreen, zIndex: 3, startFrame: scene4Timing.cyndaquilStartFrame, endFrame: scene4Timing.cyndaquilEndFrame),
                    .init(id: "scene4_bottom_main2_phase_c", assetID: "scene4_top_main2", screenRect: fullScreen, zIndex: 2, startFrame: scene4Timing.totodileStartFrame, endFrame: scene4Timing.totodileEndFrame),
                    .init(id: "scene4_bottom_main3_phase_c", assetID: "scene4_top_main3", screenRect: fullScreen, zIndex: 3, startFrame: scene4Timing.totodileStartFrame, endFrame: scene4Timing.totodileEndFrame),
                ]

        let scene4SpriteAnimations: [HGSSOpeningBundle.SpriteAnimationRef] = [
                    .init(
                        id: "scene4_top_hand_anim",
                        screen: .top,
                        frameAssetIDs: scene4Hands[0]?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene4Hands[0], positionX: 128, positionY: 352, surfaceY: 256),
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.slideInStartFrame,
                        endFrame: scene4Timing.playersEndFrame,
                        loop: true,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene4_bottom_hand_anim",
                        screen: .bottom,
                        frameAssetIDs: scene4Hands[1]?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene4Hands[1], positionX: 128, positionY: 96),
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.slideInStartFrame,
                        endFrame: scene4Timing.playersEndFrame,
                        loop: true,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene4_grass_particles_anim",
                        screen: .bottom,
                        frameAssetIDs: scene4GrassParticles,
                        screenRect: fullScreen,
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.grassParticleStartFrame,
                        endFrame: scene4Timing.grassParticleEndFrame,
                        loop: false,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene4_chikorita_anim",
                        screen: .bottom,
                        frameAssetIDs: scene4Chikorita.frameAssetIDs,
                        screenRect: spriteRect(from: scene4Chikorita, positionX: 128, positionY: 96),
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.chikoritaStartFrame,
                        endFrame: scene4Timing.chikoritaEndFrame,
                        loop: true,
                        zIndex: 5
                    ),
                    .init(
                        id: "scene4_fire_particles_anim",
                        screen: .top,
                        frameAssetIDs: scene4FireParticles,
                        screenRect: fullScreen,
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.fireParticleStartFrame,
                        endFrame: scene4Timing.fireParticleEndFrame,
                        loop: false,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene4_cyndaquil_anim",
                        screen: .top,
                        frameAssetIDs: scene4Cyndaquil.frameAssetIDs,
                        screenRect: spriteRect(from: scene4Cyndaquil, positionX: 128, positionY: 96),
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.cyndaquilStartFrame,
                        endFrame: scene4Timing.cyndaquilEndFrame,
                        loop: true,
                        zIndex: 5
                    ),
                    .init(
                        id: "scene4_water_particles_anim",
                        screen: .bottom,
                        frameAssetIDs: scene4WaterParticles,
                        screenRect: fullScreen,
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.waterParticleStartFrame,
                        endFrame: scene4Timing.waterParticleEndFrame,
                        loop: false,
                        zIndex: 4
                    ),
                    .init(
                        id: "scene4_totodile_anim",
                        screen: .bottom,
                        frameAssetIDs: scene4Totodile.frameAssetIDs,
                        screenRect: spriteRect(from: scene4Totodile, positionX: 128, positionY: 96),
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.totodileStartFrame,
                        endFrame: scene4Timing.totodileEndFrame,
                        loop: true,
                        zIndex: 5
                    ),
                    .init(
                        id: "scene4_sparkles_anim",
                        screen: .bottom,
                        frameAssetIDs: scene4Hands[2]?.frameAssetIDs ?? [],
                        screenRect: spriteRect(from: scene4Hands[2], positionX: 128, positionY: 96),
                        frameDurationFrames: 1,
                        startFrame: scene4Timing.sparklesStartFrame,
                        endFrame: scene4Timing.sparklesEndFrame,
                        loop: false,
                        zIndex: 6
                    ),
                ]

        let scene4TransitionCues: [HGSSOpeningBundle.TransitionCue] = [
                    .init(id: "scene4_top_slide_in_window", kind: .window, screen: .top, startFrame: scene4Timing.slideInStartFrame, durationFrames: scene4Source.slideInWindowTop.durationFrames, fromRect: scene4Source.slideInWindowTop.fromRect, toRect: scene4Source.slideInWindowTop.toRect),
                    .init(id: "scene4_bottom_slide_in_window", kind: .window, screen: .bottom, startFrame: scene4Timing.slideInStartFrame, durationFrames: scene4Source.slideInWindowBottom.durationFrames, fromRect: scene4Source.slideInWindowBottom.fromRect, toRect: scene4Source.slideInWindowBottom.toRect),
                    .init(id: "scene4_top_slide_in", kind: .scroll, targetID: "scene4_top_sub1_layer", startFrame: scene4Timing.slideInStartFrame, durationFrames: scene4Source.slideInWindowTop.durationFrames, offsetX: Double(scene4Source.slideInScrollTopX)),
                    .init(id: "scene4_bottom_slide_in", kind: .scroll, targetID: "scene4_bottom_main1_layer", startFrame: scene4Timing.slideInStartFrame, durationFrames: scene4Source.slideInWindowBottom.durationFrames, offsetX: Double(scene4Source.slideInScrollBottomX)),
                    .init(id: "scene4_top_slide_out_window", kind: .window, screen: .top, startFrame: scene4Timing.slideOutStartFrame, durationFrames: scene4Source.slideOutWindowTop.durationFrames, fromRect: scene4Source.slideOutWindowTop.fromRect, toRect: scene4Source.slideOutWindowTop.toRect),
                    .init(id: "scene4_bottom_slide_out_window", kind: .window, screen: .bottom, startFrame: scene4Timing.slideOutStartFrame, durationFrames: scene4Source.slideOutWindowBottom.durationFrames, fromRect: scene4Source.slideOutWindowBottom.fromRect, toRect: scene4Source.slideOutWindowBottom.toRect),
                    .init(id: "scene4_top_slide_out", kind: .scroll, targetID: "scene4_top_sub1_layer", startFrame: scene4Timing.slideOutStartFrame, durationFrames: scene4Source.slideOutWindowTop.durationFrames, offsetX: Double(scene4Source.slideOutScrollTopX)),
                    .init(id: "scene4_bottom_slide_out", kind: .scroll, targetID: "scene4_bottom_main1_layer", startFrame: scene4Timing.slideOutStartFrame, durationFrames: scene4Source.slideOutWindowBottom.durationFrames, offsetX: Double(scene4Source.slideOutScrollBottomX)),
                    .init(id: "scene4_fade_in", kind: .fade, screen: .top, startFrame: 0, durationFrames: scene4Timing.fadeInDurationFrames, fromValue: 1.0, toValue: 0.0, colorHex: "#000000"),
                    .init(id: "scene4_fade_in_bottom", kind: .fade, screen: .bottom, startFrame: 0, durationFrames: scene4Timing.fadeInDurationFrames, fromValue: 1.0, toValue: 0.0, colorHex: "#000000"),
                    .init(id: "scene4_fade_out_black", kind: .fade, screen: .top, startFrame: scene4Timing.fadeToBlackStartFrame, durationFrames: scene4Timing.fadeToBlackDurationFrames, fromValue: 0.0, toValue: 1.0, colorHex: "#000000"),
                    .init(id: "scene4_fade_out_black_bottom", kind: .fade, screen: .bottom, startFrame: scene4Timing.fadeToBlackStartFrame, durationFrames: scene4Timing.fadeToBlackDurationFrames, fromValue: 0.0, toValue: 1.0, colorHex: "#000000"),
                ]

        let scene4: HGSSOpeningBundle.Scene = .init(
                id: .scene4,
                durationFrames: scene4Timing.totalDurationFrames,
                skipAllowedFromFrame: 0,
                topLayers: scene4TopLayers,
                bottomLayers: scene4BottomLayers,
                spriteAnimations: scene4SpriteAnimations,
                modelAnimations: [],
                transitionCues: scene4TransitionCues,
                audioCues: []
            )

        let scene5: HGSSOpeningBundle.Scene = .init(
                id: .scene5,
                durationFrames: 90,
                skipAllowedFromFrame: 0,
                topLayers: [
                    .init(id: "scene5_top_main1_layer", assetID: "scene5_top_main1", screenRect: tallScreen, zIndex: 1),
                    .init(id: "scene5_top_main2_layer", assetID: "scene5_top_main2", screenRect: .init(x: 0, y: 160, width: 256, height: 512), zIndex: 2),
                ],
                bottomLayers: [
                    .init(id: "scene5_bottom_sub1_layer", assetID: "scene5_bottom_sub1", screenRect: tallScreen, zIndex: 1),
                    .init(id: "scene5_bottom_sub2_layer", assetID: "scene5_bottom_sub2", screenRect: .init(x: 0, y: 160, width: 256, height: 512), zIndex: 2),
                ],
                spriteAnimations: [],
                modelAnimations: [],
                transitionCues: [
                    .init(id: "scene5_top_scroll", kind: .scroll, targetID: "scene5_top_main2_layer", startFrame: 18, durationFrames: 73, offsetY: -160),
                    .init(id: "scene5_bottom_scroll", kind: .scroll, targetID: "scene5_bottom_sub2_layer", startFrame: 18, durationFrames: 73, offsetY: -160),
                    .init(id: "scene5_fade_white_top", kind: .fade, screen: .top, startFrame: 38, durationFrames: 50, fromValue: 0.0, toValue: 1.0, colorHex: "#FFFFFF"),
                    .init(id: "scene5_fade_white_bottom", kind: .fade, screen: .bottom, startFrame: 38, durationFrames: 50, fromValue: 0.0, toValue: 1.0, colorHex: "#FFFFFF"),
                ],
                audioCues: []
            )

        let titleHandoff: HGSSOpeningBundle.Scene = .init(
                id: .titleHandoff,
                durationFrames: 1,
                skipAllowedFromFrame: 0,
                topLayers: [
                    .init(id: "title_handoff_background_layer", assetID: "title_handoff_top", screenRect: fullScreen, zIndex: 1),
                    .init(id: "title_handoff_gamefreak_strip_layer", assetID: "title_handoff_gamefreak_strip", screenRect: fullScreen, zIndex: 2),
                ],
                bottomLayers: [],
                spriteAnimations: [],
                modelAnimations: [
                    .init(
                        id: "title_handoff_hooh_model_layer",
                        screen: .bottom,
                        assetID: "title_handoff_hooh_model",
                        screenRect: fullScreen,
                        zIndex: 1,
                        translation: titleHandoffSource.translation,
                        freezeAtFrame: 0,
                        camera: .init(
                            position: titleHandoffSource.cameraPosition,
                            target: titleHandoffSource.cameraTarget,
                            fieldOfViewDegrees: titleHandoffSource.fieldOfViewDegrees,
                            nearClipDistance: 0,
                            farClipDistance: titleHandoffSource.farClipDistance
                        ),
                        lights: titleHandoffSource.lights
                    ),
                    .init(
                        id: "title_handoff_sparkles_model_layer",
                        screen: .bottom,
                        assetID: "title_handoff_sparkles_model",
                        screenRect: fullScreen,
                        zIndex: 2,
                        freezeAtFrame: 0,
                        camera: .init(
                            position: titleHandoffSource.cameraPosition,
                            target: titleHandoffSource.cameraTarget,
                            fieldOfViewDegrees: titleHandoffSource.fieldOfViewDegrees,
                            nearClipDistance: 0,
                            farClipDistance: titleHandoffSource.farClipDistance
                        ),
                        lights: titleHandoffSource.lights
                    ),
                ],
                transitionCues: [],
                audioCues: [
                    .init(
                        id: "title_handoff_bgm_start",
                        action: .startBGM,
                        cueName: "SEQ_GS_POKEMON_THEME",
                        frame: 0,
                        playableAssetID: "title_handoff_seq_gs_pokemon_theme_audio",
                        provenance: "External/pokeheartgold/src/title_screen.c"
                    ),
                ]
            )

        return [scene1, scene2, scene3, scene4, scene5, titleHandoff]
    }

    private func parseScene3Source(from url: URL) throws -> Scene3SourceConfig {
        let source = try String(contentsOf: url)
        let file = url.lastPathComponent

        let showNewBarkBlock = try caseBody(named: "INTRO_SCENE3_SHOW_NEWBARK", in: source, file: file)
        let showGoldenrodBlock = try caseBody(named: "INTRO_SCENE3_SHOW_GOLDENROD", in: source, file: file)
        let waitEcruteakBlock = try caseBody(named: "INTRO_SCENE3_WAIT_ECRUTEAK", in: source, file: file)
        let rivalPanelsBlock = try caseBody(named: "INTRO_SCENE3_DRAMATIC_RIVAL_PANELS", in: source, file: file)
        let removeBordersBlock = try caseBody(named: "INTRO_SCENE3_REMOVE_RIVAL_PANEL_BORDERS", in: source, file: file)
        let cinematicBlock = try caseBody(named: "INTRO_SCENE3_CINEMATIC_ASPECT_RIVAL", in: source, file: file)
        let appearEnteiBlock = try caseBody(named: "INTRO_SCENE3_APPEAR_ENTEI", in: source, file: file)
        let appearRaikouBlock = try caseBody(named: "INTRO_SCENE3_APPEAR_RAIKOU", in: source, file: file)
        let narrowWindowsBlock = try caseBody(named: "INTRO_SCENE3_NARROW_WINDOWS", in: source, file: file)
        let spritesVisibleBlock = try caseBody(named: "INTRO_SCENE3_SPRITES_VISIBLE", in: source, file: file)
        let unownRaikouExitBlock = try caseBody(named: "INTRO_SCENE3_UNOWN_RAIKOU_EXIT", in: source, file: file)
        let unownSuicuneExitBlock = try caseBody(named: "INTRO_SCENE3_UNOWN_SUICUNE_EXIT", in: source, file: file)
        let expandRocketBlock = try caseBody(named: "INTRO_SCENE3_EXPAND_ROCKET_VIEWPORT", in: source, file: file)

        let scene3PanelDelayList = try parseIntList(
            pattern: #"silver_bg_appear_frame_delays\[3\]\s*=\s*\{([^}]*)\}"#,
            in: rivalPanelsBlock,
            file: file
        )
        let spriteVisibleTimers = try allIntMatches(pattern: #"if\s*\(\s*stepTimer\s*==\s*(\d+)\s*\)"#, in: spritesVisibleBlock, file: file)
        guard spriteVisibleTimers.count >= 2 else {
            throw OpeningHeartGoldExtractModeError.sourcePatternNotFound(
                file: file,
                pattern: "scene3 sprite-visible timers"
            )
        }

        let rocketScroll1 = try parseScrollCall(layer: "GF_BG_LYR_SUB_1", in: expandRocketBlock, file: file)
        let rocketScroll2 = try parseScrollCall(layer: "GF_BG_LYR_SUB_2", in: expandRocketBlock, file: file)
        let rocketScroll3 = try parseScrollCall(layer: "GF_BG_LYR_SUB_3", in: expandRocketBlock, file: file)

        return Scene3SourceConfig(
            circleWipeDurationFrames: try parseSingleInt(
                pattern: #"IntroMovie_BeginCircleWipeEffect\(data,\s*0,\s*TRUE,\s*(\d+)\);"#,
                in: source,
                file: file
            ),
            showNewBarkHoldThreshold: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>\s*(\d+)\s*\)"#,
                in: showNewBarkBlock,
                file: file
            ),
            showGoldenrodHoldThreshold: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>\s*(\d+)\s*\)"#,
                in: showGoldenrodBlock,
                file: file
            ),
            waitEcruteakThreshold: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>\s*(\d+)\s*\)"#,
                in: waitEcruteakBlock,
                file: file
            ),
            rivalPanelDelays: scene3PanelDelayList,
            removePanelBordersDelay: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>=\s*(\d+)\s*\)"#,
                in: removeBordersBlock,
                file: file
            ),
            cinematicAspectDelay: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*==\s*(\d+)\s*\)"#,
                in: cinematicBlock,
                file: file
            ),
            rivalWholeRevealDelay: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>=\s*(\d+)\s*\)"#,
                in: cinematicBlock,
                file: file
            ),
            rivalWholeRevealWindow: try parseWindowPan(named: "windowPan_widenLeftToRight", in: cinematicBlock, file: file),
            enteiRevealWindow: try parseWindowPan(named: "windowPan_widenRightToLeft", in: appearEnteiBlock, file: file),
            enteiRevealScrollDuration: try parseScrollCall(layer: "GF_BG_LYR_SUB_1", in: appearEnteiBlock, file: file).durationFrames,
            raikouRevealWindow: try parseWindowPan(named: "windowPan_widenLeftToRight", in: appearRaikouBlock, file: file),
            raikouRevealScrollDuration: try parseScrollCall(layer: "GF_BG_LYR_SUB_2", in: appearRaikouBlock, file: file).durationFrames,
            narrowWindowDelay: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>=\s*(\d+)\s*\)"#,
                in: narrowWindowsBlock,
                file: file
            ),
            narrowWindow: try parseWindowPan(named: "windowPan_narrowX", in: narrowWindowsBlock, file: file),
            eusineAppearDelay: spriteVisibleTimers[0],
            unownSlideDelay: spriteVisibleTimers[1],
            enteiExitWindow: try parseWindowPan(named: "windowPan_narrowLeftToRight", in: spritesVisibleBlock, file: file),
            enteiExitScrollDuration: try parseScrollCall(layer: "GF_BG_LYR_SUB_1", in: spritesVisibleBlock, file: file).durationFrames,
            raikouExitDelay: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>=\s*(\d+)\s*\)"#,
                in: unownRaikouExitBlock,
                file: file
            ),
            raikouExitWindow: try parseWindowPan(named: "windowPan_narrowLeftToRight", in: unownRaikouExitBlock, file: file),
            raikouExitScrollDuration: try parseScrollCall(layer: "GF_BG_LYR_SUB_2", in: unownRaikouExitBlock, file: file).durationFrames,
            suicuneExitDelay: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>=\s*(\d+)\s*\)"#,
                in: unownSuicuneExitBlock,
                file: file
            ),
            suicuneExitWindow: try parseWindowPan(named: "windowPan_narrowRightToLeft", in: unownSuicuneExitBlock, file: file),
            suicuneExitScrollDuration: try parseScrollCall(layer: "GF_BG_LYR_SUB_0", in: unownSuicuneExitBlock, file: file).durationFrames,
            rocketExpandWindow: try parseWindowPan(named: "windowPan_expandFromCenter", in: expandRocketBlock, file: file),
            rocketExpandDurationFrames: try parseWindowPan(named: "windowPan_expandFromCenter", in: expandRocketBlock, file: file).durationFrames,
            rocketScrollOffsetsY: [rocketScroll1.yChange, rocketScroll2.yChange, rocketScroll3.yChange],
            rocketScrollDurationFrames: rocketScroll1.durationFrames
        )
    }

    private func parseScene4Source(from url: URL) throws -> Scene4SourceConfig {
        let source = try String(contentsOf: url)
        let file = url.lastPathComponent

        let fadeInBlock = try caseBody(named: "INTRO_SCENE4_FADE_IN", in: source, file: file)
        let slideInBlock = try caseBody(named: "INTRO_SCENE4_SLIDE_IN_PLAYERS", in: source, file: file)
        let holdPlayersBlock = try caseBody(named: "INTRO_SCENE4_HOLD_PLAYERS_GFX", in: source, file: file)
        let slideOutBlock = try caseBody(named: "INTRO_SCENE4_SLIDE_OUT_PLAYERS", in: source, file: file)
        let runWaterBlock = try caseBody(named: "INTRO_SCENE4_RUN_WATER_PARTICLES", in: source, file: file)
        let enableBgLayersBlock = try functionBody(named: "IntroMovie_Scene4_EnableBgLayers", in: source, file: file)

        let initialTopScroll = try parseScrollCall(layer: "GF_BG_LYR_SUB_1", in: enableBgLayersBlock, file: file)
        let initialBottomScroll = try parseScrollCall(layer: "GF_BG_LYR_MAIN_1", in: enableBgLayersBlock, file: file)
        let slideInTopScroll = try parseScrollCall(layer: "GF_BG_LYR_SUB_1", in: slideInBlock, file: file)
        let slideInBottomScroll = try parseScrollCall(layer: "GF_BG_LYR_MAIN_1", in: slideInBlock, file: file)
        let slideOutTopScroll = try parseScrollCall(layer: "GF_BG_LYR_SUB_1", in: slideOutBlock, file: file)
        let slideOutBottomScroll = try parseScrollCall(layer: "GF_BG_LYR_MAIN_1", in: slideOutBlock, file: file)

        return Scene4SourceConfig(
            fadeInDurationFrames: try parseSingleInt(
                pattern: #"BeginNormalPaletteFade\([^;]*?,\s*(\d+)\s*,\s*1\s*,\s*HEAP_ID_INTRO_MOVIE\);"#,
                in: fadeInBlock,
                file: file
            ),
            initialTopLayerX: initialTopScroll.xChange,
            initialBottomLayerX: initialBottomScroll.xChange,
            slideInWindowTop: try parseWindowPan(named: "windowPan_widenRightToLeft", in: slideInBlock, file: file),
            slideInWindowBottom: try parseWindowPan(named: "windowPan_widenLeftToRight", in: slideInBlock, file: file),
            slideInScrollTopX: slideInTopScroll.xChange,
            slideInScrollBottomX: slideInBottomScroll.xChange,
            holdPlayersThreshold: try parseSingleInt(
                pattern: #"if\s*\(\s*stepTimer\s*>\s*(\d+)\s*\)"#,
                in: holdPlayersBlock,
                file: file
            ),
            slideOutWindowTop: try parseWindowPan(named: "windowPan_narrowRightToLeft", in: slideOutBlock, file: file),
            slideOutWindowBottom: try parseWindowPan(named: "windowPan_narrowLeftToRight", in: slideOutBlock, file: file),
            slideOutScrollTopX: slideOutTopScroll.xChange,
            slideOutScrollBottomX: slideOutBottomScroll.xChange,
            fadeToBlackDurationFrames: try parseSingleInt(
                pattern: #"BeginNormalPaletteFade\([^;]*?,\s*(\d+)\s*,\s*1\s*,\s*HEAP_ID_INTRO_MOVIE\);"#,
                in: runWaterBlock,
                file: file
            )
        )
    }

    private func parseTitleHandoffSource(from url: URL) throws -> TitleHandoffSourceConfig {
        let source = try String(contentsOf: url)
        let file = url.lastPathComponent
        let load3DBlock = try functionBody(named: "TitleScreen_Load3DObjects", in: source, file: file)
        let cameraFunctionBlock = try functionBody(named: "TitleScreenAnim_SetCameraInitialPos", in: source, file: file)
        let cameraBlock = try firstMatch(
            pattern: #"if\s*\(\s*animData->gameVersion\s*==\s*VERSION_HEARTGOLD\s*\)\s*\{(.*?)\}\s*else"#,
            in: cameraFunctionBlock,
            file: file
        )[0]

        let light0 = normalize(
            try parseVector3(
                pattern: #"SetVec\(animData->light0Vec,\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*\);"#,
                in: cameraBlock,
                file: file
            )
        )
        let light1 = try parseVector3(
            pattern: #"SetVec\(animData->light1Vec,\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*\);"#,
            in: cameraBlock,
            file: file
        )

        return TitleHandoffSourceConfig(
            translation: try parseVector3(
                pattern: #"animObj->translation\s*=\s*\(VecFx32\)\s*\{\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*\};"#,
                in: load3DBlock,
                file: file
            ),
            cameraPosition: try parseVector3(
                pattern: #"SetVec\(animData->cameraPosEnd,\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*\);"#,
                in: cameraBlock,
                file: file
            ),
            cameraTarget: try parseVector3(
                pattern: #"SetVec\(animData->cameraTargetEnd,\s*(.*?)\s*,\s*(.*?)\s*,\s*(.*?)\s*\);"#,
                in: cameraBlock,
                file: file
            ),
            fieldOfViewDegrees: try parsePerspectiveDegrees(
                pattern: #"Camera_Init_FromTargetAndPos\([^;]*?,\s*(0x[0-9A-Fa-f]+|\d+)\s*,\s*0\s*,\s*FALSE"#,
                in: source,
                file: file
            ),
            farClipDistance: try parseFixedLiteral(
                try firstMatch(
                    pattern: #"Camera_SetPerspectiveClippingPlane\(\s*0\s*,\s*(.*?)\s*,\s*animData->hooh_lugia\.camera\s*\);"#,
                    in: source,
                    file: file
                )[0],
                file: file,
                pattern: "Camera_SetPerspectiveClippingPlane"
            ),
            lights: [
                .init(direction: light0, colorHex: "#FFFFFF"),
                .init(direction: light1, colorHex: "#FFFFFF"),
            ]
        )
    }

    private func makeScene3Timing(source: Scene3SourceConfig) -> Scene3Timing {
        let newBarkHideStartFrame = 1 + source.showNewBarkHoldThreshold
        let goldenrodStartFrame = newBarkHideStartFrame + source.circleWipeDurationFrames
        let goldenrodHideStartFrame = goldenrodStartFrame + 1 + source.showGoldenrodHoldThreshold
        let ecruteakStartFrame = goldenrodHideStartFrame + source.circleWipeDurationFrames
        let ecruteakHideStartFrame = ecruteakStartFrame + 1 + source.waitEcruteakThreshold
        let end3DRenderStartFrame = ecruteakHideStartFrame + 1
        let rivalRevealStartFrame = end3DRenderStartFrame + source.circleWipeDurationFrames
        let rivalPanelsStartFrame = rivalRevealStartFrame + source.circleWipeDurationFrames + 1
        let rivalPanelSwapFrames = source.rivalPanelDelays.map { rivalPanelsStartFrame + $0 - 1 }
        let removePanelBordersStartFrame = rivalPanelSwapFrames[2] + 1
        let cinematicStartFrame = removePanelBordersStartFrame + source.removePanelBordersDelay
        let rivalWholeRevealStartFrame = cinematicStartFrame + source.rivalWholeRevealDelay - 1
        let enteiRevealStartFrame = rivalWholeRevealStartFrame + source.rivalWholeRevealWindow.durationFrames
        let raikouRevealStartFrame = enteiRevealStartFrame + source.enteiRevealScrollDuration
        let loadRocketsStartFrame = raikouRevealStartFrame + source.raikouRevealScrollDuration
        let narrowWindowStartFrame = loadRocketsStartFrame + source.narrowWindowDelay
        let spritesVisibleStartFrame = narrowWindowStartFrame + source.narrowWindow.durationFrames + 1
        let eusineStartFrame = spritesVisibleStartFrame + source.eusineAppearDelay - 1
        let unown0StartFrame = spritesVisibleStartFrame + source.unownSlideDelay - 1
        let unown1StartFrame = unown0StartFrame + source.enteiExitScrollDuration + 1
        let rocketLayersStartFrame = unown1StartFrame + source.raikouExitDelay - 1 + source.raikouExitScrollDuration
        let unown2StartFrame = rocketLayersStartFrame + 1
        let rocketExpandStartFrame = unown2StartFrame + source.suicuneExitDelay - 1 + source.suicuneExitScrollDuration
        let durationFrames = rocketExpandStartFrame + source.rocketScrollDurationFrames + 1

        return Scene3Timing(
            durationFrames: durationFrames,
            goldenrodStartFrame: goldenrodStartFrame,
            ecruteakStartFrame: ecruteakStartFrame,
            ecruteakHideStartFrame: ecruteakHideStartFrame,
            rivalRevealStartFrame: rivalRevealStartFrame,
            rivalPanelsStartFrame: rivalPanelsStartFrame,
            rivalPanelSwapFrames: rivalPanelSwapFrames,
            removePanelBordersStartFrame: removePanelBordersStartFrame,
            rivalWholeRevealStartFrame: rivalWholeRevealStartFrame,
            enteiRevealStartFrame: enteiRevealStartFrame,
            raikouRevealStartFrame: raikouRevealStartFrame,
            narrowWindowStartFrame: narrowWindowStartFrame,
            spritesVisibleStartFrame: spritesVisibleStartFrame,
            eusineStartFrame: eusineStartFrame,
            unown0StartFrame: unown0StartFrame,
            unown1StartFrame: unown1StartFrame,
            rocketLayersStartFrame: rocketLayersStartFrame,
            unown2StartFrame: unown2StartFrame,
            rocketExpandStartFrame: rocketExpandStartFrame
        )
    }

    private func caseBody(named name: String, in source: String, file: String) throws -> String {
        try firstMatch(
            pattern: #"case\s+\#(NSRegularExpression.escapedPattern(for: name))\s*:\s*(.*?)\n\s*break;"#,
            in: source,
            file: file
        )[0]
    }

    private func functionBody(named name: String, in source: String, file: String) throws -> String {
        try firstMatch(
            pattern: #"(?:static\s+)?(?:BOOL|void)\s+\#(NSRegularExpression.escapedPattern(for: name))\s*\([^)]*\)\s*\{(.*?)\n\}"#,
            in: source,
            file: file
        )[0]
    }

    private func firstMatch(
        pattern: String,
        in source: String,
        file: String
    ) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = regex.firstMatch(in: source, options: [], range: fullRange) else {
            throw OpeningHeartGoldExtractModeError.sourcePatternNotFound(file: file, pattern: pattern)
        }

        return (1..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: source) else {
                return ""
            }
            return String(source[range])
        }
    }

    private func allIntMatches(
        pattern: String,
        in source: String,
        file: String
    ) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, options: [], range: fullRange)
        guard !matches.isEmpty else {
            throw OpeningHeartGoldExtractModeError.sourcePatternNotFound(file: file, pattern: pattern)
        }

        return try matches.map { match in
            guard let range = Range(match.range(at: 1), in: source) else {
                throw OpeningHeartGoldExtractModeError.invalidSourceNumbers(file: file, pattern: pattern)
            }
            return try parseCInt(String(source[range]), file: file, pattern: pattern)
        }
    }

    private func parseSingleInt(
        pattern: String,
        in source: String,
        file: String
    ) throws -> Int {
        let rawValue = try firstMatch(pattern: pattern, in: source, file: file)[0]
        return try parseCInt(rawValue, file: file, pattern: pattern)
    }

    private func parseIntList(
        pattern: String,
        in source: String,
        file: String
    ) throws -> [Int] {
        let rawList = try firstMatch(pattern: pattern, in: source, file: file)[0]
        let values = rawList
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !values.isEmpty else {
            throw OpeningHeartGoldExtractModeError.invalidSourceNumbers(file: file, pattern: pattern)
        }
        return try values.map { try parseCInt($0, file: file, pattern: pattern) }
    }

    private func parseWindowPan(
        named name: String,
        in source: String,
        file: String
    ) throws -> ParsedWindowPan {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let valuePattern = #"IntroMovieBgWindowAnimParam\s+\#(escapedName)\s*=\s*\{\s*([^}]*)\};"#
        let durationPattern = #"IntroMovie_StartWindowPanEffect\([^;]*?,\s*([^,]+)\s*,\s*[^,]+\s*,\s*&\#(escapedName)\s*\);"#
        let values = try parseIntList(pattern: valuePattern, in: source, file: file)
        guard values.count >= 8 else {
            throw OpeningHeartGoldExtractModeError.invalidSourceNumbers(file: file, pattern: valuePattern)
        }

        return ParsedWindowPan(
            durationFrames: try parseSingleInt(pattern: durationPattern, in: source, file: file),
            startX1: values[0],
            startY1: values[1],
            startX2: values[2],
            startY2: values[3],
            endX1: values[4],
            endY1: values[5],
            endX2: values[6],
            endY2: values[7]
        )
    }

    private func parseScrollCall(
        layer: String,
        in source: String,
        file: String
    ) throws -> ParsedScrollCall {
        let pattern = #"IntroMovie_StartBgScroll_VBlank\([^;]*?\b\#(NSRegularExpression.escapedPattern(for: layer))\b\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,\)]+)\);"#
        let captures = try firstMatch(pattern: pattern, in: source, file: file)
        return ParsedScrollCall(
            xChange: try parseCInt(captures[0], file: file, pattern: pattern),
            yChange: try parseCInt(captures[1], file: file, pattern: pattern),
            durationFrames: try parseCInt(captures[2], file: file, pattern: pattern)
        )
    }

    private func parseVector3(
        pattern: String,
        in source: String,
        file: String
    ) throws -> HGSSOpeningBundle.Vector3 {
        let captures = try firstMatch(pattern: pattern, in: source, file: file)
        guard captures.count == 3 else {
            throw OpeningHeartGoldExtractModeError.invalidSourceNumbers(file: file, pattern: pattern)
        }
        return .init(
            x: try parseFixedLiteral(captures[0], file: file, pattern: pattern),
            y: try parseFixedLiteral(captures[1], file: file, pattern: pattern),
            z: try parseFixedLiteral(captures[2], file: file, pattern: pattern)
        )
    }

    private func parsePerspectiveDegrees(
        pattern: String,
        in source: String,
        file: String
    ) throws -> Double {
        let raw = try parseSingleInt(pattern: pattern, in: source, file: file)
        return (Double(raw) * 360.0) / 65536.0
    }

    private func parseFixedLiteral(
        _ literal: String,
        file: String,
        pattern: String
    ) throws -> Double {
        let trimmed = literal.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "0" {
            return 0
        }
        if let match = trimmed.firstMatch(of: #/FX(?:16|32)_CONST\((-?[0-9]+(?:\.[0-9]+)?)\)/#) {
            guard let value = Double(match.1) else {
                throw OpeningHeartGoldExtractModeError.invalidSourceNumbers(file: file, pattern: pattern)
            }
            return value
        }
        if let match = trimmed.firstMatch(of: #/(-?0x[0-9A-Fa-f]+|-?[0-9]+)\s*\*\s*FX32_ONE/#) {
            return Double(try parseCInt(String(match.1), file: file, pattern: pattern))
        }
        if let match = trimmed.firstMatch(of: #/(-?0x[0-9A-Fa-f]+|-?[0-9]+)\s*\*\s*FX16_ONE/#) {
            return Double(try parseCInt(String(match.1), file: file, pattern: pattern))
        }
        if let direct = Double(trimmed) {
            return direct
        }
        throw OpeningHeartGoldExtractModeError.invalidSourceNumbers(file: file, pattern: pattern)
    }

    private func parseCInt(
        _ rawValue: String,
        file: String,
        pattern: String
    ) throws -> Int {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = trimmed.lowercased()
        if lowercase.hasPrefix("-0x"), let parsed = Int(lowercase.dropFirst(3), radix: 16) {
            return -parsed
        }
        if lowercase.hasPrefix("0x"), let parsed = Int(lowercase.dropFirst(2), radix: 16) {
            return parsed
        }
        if let parsed = Int(trimmed) {
            return parsed
        }
        throw OpeningHeartGoldExtractModeError.invalidSourceNumbers(file: file, pattern: pattern)
    }

    private func normalize(_ vector: HGSSOpeningBundle.Vector3) -> HGSSOpeningBundle.Vector3 {
        let magnitude = sqrt((vector.x * vector.x) + (vector.y * vector.y) + (vector.z * vector.z))
        guard magnitude > 0 else {
            return vector
        }
        return .init(x: vector.x / magnitude, y: vector.y / magnitude, z: vector.z / magnitude)
    }

    private func validateOpeningInputs(pretRoot: URL) throws {
        let requiredPaths = [
            pretRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false),
            pretRoot.appendingPathComponent("src/intro_movie_scene_1.c", isDirectory: false),
            pretRoot.appendingPathComponent("src/intro_movie_scene_2.c", isDirectory: false),
            pretRoot.appendingPathComponent("src/intro_movie_scene_3.c", isDirectory: false),
            pretRoot.appendingPathComponent("src/intro_movie_scene_4.c", isDirectory: false),
            pretRoot.appendingPathComponent("src/intro_movie_scene_5.c", isDirectory: false),
            pretRoot.appendingPathComponent("src/title_screen.c", isDirectory: false),
            pretRoot.appendingPathComponent("files/demo/opening/gs_opening", isDirectory: true),
            pretRoot.appendingPathComponent("files/demo/title/titledemo", isDirectory: true),
            pretRoot.appendingPathComponent("files/data/sound/gs_sound_data.sdat", isDirectory: false),
        ]

        for requiredPath in requiredPaths where !FileManager.default.fileExists(atPath: requiredPath.path()) {
            throw ExtractCLIError.missingPretFile(path: requiredPath.path())
        }
    }

    private func runPythonHelper(
        pythonTool: URL,
        helperScript: URL,
        arguments: [String]
    ) throws {
        try runProcess(
            executable: pythonTool,
            arguments: [helperScript.path()] + arguments,
            commandLabel: "opening_asset_helper.py"
        )
    }

    private func decodeTilemap(
        assetID: String,
        outputName: String,
        sceneDirectory: URL,
        intermediateDirectory: URL,
        helperScript: URL,
        pythonTool: URL,
        ncgr: URL,
        nscr: URL,
        nclr: URL,
        provenance: String
    ) throws -> (asset: HGSSOpeningBundle.Asset, upstreamFiles: [String]) {
        try FileManager.default.createDirectory(at: intermediateDirectory, withIntermediateDirectories: true)
        let intermediatePNG = intermediateDirectory.appendingPathComponent(outputName, isDirectory: false)
        try runPythonHelper(
            pythonTool: pythonTool,
            helperScript: helperScript,
            arguments: [
                "tilemap",
                "--ncgr", ncgr.path(),
                "--nscr", nscr.path(),
                "--nclr", nclr.path(),
                "--output", intermediatePNG.path(),
            ]
        )

        let assetURL = sceneDirectory.appendingPathComponent(outputName, isDirectory: false)
        try FileManager.default.copyItem(at: intermediatePNG, to: assetURL)
        let image = try loadImage(at: assetURL)
        let relativePath = relativePathString(for: assetURL)
        let asset = HGSSOpeningBundle.Asset(
            id: assetID,
            kind: .image,
            relativePath: relativePath,
            pixelWidth: Int(image.size.width),
            pixelHeight: Int(image.size.height),
            provenance: provenance
        )
        return (asset, [ncgr.path(), nscr.path(), nclr.path(), provenance])
    }

    private func copyImageAsset(
        source: URL,
        destinationDirectory: URL,
        outputName: String,
        assetID: String,
        provenance: String
    ) throws -> (asset: HGSSOpeningBundle.Asset, upstreamFiles: [String]) {
        let destination = destinationDirectory.appendingPathComponent(outputName, isDirectory: false)
        try FileManager.default.copyItem(at: source, to: destination)
        let image = try loadImage(at: destination)
        let asset = HGSSOpeningBundle.Asset(
            id: assetID,
            kind: .image,
            relativePath: relativePathString(for: destination),
            pixelWidth: Int(image.size.width),
            pixelHeight: Int(image.size.height),
            provenance: provenance
        )
        return (asset, [source.path(), provenance])
    }

    private func copyBakedScene4ParticlePhase(
        phaseID: String,
        manifest: Scene4BakedParticleManifest,
        manifestRoot: URL,
        sceneDirectory: URL,
        assetIDPrefix: String,
        provenance: String
    ) throws -> BakedFrameSequenceResult {
        guard let phase = manifest.phases.first(where: { $0.id == phaseID }) else {
            throw OpeningHeartGoldExtractModeError.missingScene4BakedParticlePhase(phaseID)
        }

        var assets: [HGSSOpeningBundle.Asset] = []
        var frameAssetIDs: [String] = []
        for (index, framePath) in phase.framePaths.enumerated() {
            let source = manifestRoot.appendingPathComponent(framePath, isDirectory: false)
            let outputName = "\(assetIDPrefix)_frame_\(String(format: "%03d", index)).png"
            let assetID = "\(assetIDPrefix)_frame_\(index)"
            let copied = try copyImageAsset(
                source: source,
                destinationDirectory: sceneDirectory,
                outputName: outputName,
                assetID: assetID,
                provenance: provenance
            )
            assets.append(copied.asset)
            frameAssetIDs.append(assetID)
        }

        return BakedFrameSequenceResult(
            assets: assets,
            frameAssetIDs: frameAssetIDs,
            upstreamFiles: [
                "External/pokeheartgold/files/a/0/5/9",
                manifestRoot.appendingPathComponent("scene4_particle_frames.json", isDirectory: false).path(),
                provenance,
            ]
        )
    }

    private func composePNGTilemap(
        assetID: String,
        outputName: String,
        sceneDirectory: URL,
        intermediateDirectory: URL,
        helperScript: URL,
        pythonTool: URL,
        pngSheet: URL,
        nscr: URL,
        transparentTopLeft: Bool = false,
        cropHeight: Int? = nil,
        provenance: String
    ) throws -> (asset: HGSSOpeningBundle.Asset, upstreamFiles: [String]) {
        try FileManager.default.createDirectory(at: intermediateDirectory, withIntermediateDirectories: true)
        let intermediatePNG = intermediateDirectory.appendingPathComponent(outputName, isDirectory: false)

        var arguments = [
            "png-tilemap",
            "--sheet", pngSheet.path(),
            "--nscr", nscr.path(),
            "--output", intermediatePNG.path(),
        ]
        if transparentTopLeft {
            arguments.append("--transparent-top-left")
        }
        if let cropHeight {
            arguments += ["--crop-height", String(cropHeight)]
        }

        try runPythonHelper(
            pythonTool: pythonTool,
            helperScript: helperScript,
            arguments: arguments
        )

        let assetURL = sceneDirectory.appendingPathComponent(outputName, isDirectory: false)
        try FileManager.default.copyItem(at: intermediatePNG, to: assetURL)
        let image = try loadImage(at: assetURL)
        let asset = HGSSOpeningBundle.Asset(
            id: assetID,
            kind: .image,
            relativePath: relativePathString(for: assetURL),
            pixelWidth: Int(image.size.width),
            pixelHeight: Int(image.size.height),
            provenance: provenance
        )
        return (asset, [pngSheet.path(), nscr.path(), provenance])
    }

    private func extractSpriteSequence(
        sequenceIndex: Int,
        assetIDPrefix: String,
        sceneDirectory: URL,
        intermediateDirectory: URL,
        helperScript: URL,
        pythonTool: URL,
        ncgr: URL,
        nclr: URL,
        ncer: URL,
        nanr: URL,
        provenance: String
    ) throws -> SpriteSequenceResult {
        let results = try extractSpriteSequences(
            sequenceIndices: [sequenceIndex],
            assetIDPrefix: assetIDPrefix,
            sceneDirectory: sceneDirectory,
            intermediateDirectory: intermediateDirectory,
            helperScript: helperScript,
            pythonTool: pythonTool,
            ncgr: ncgr,
            nclr: nclr,
            ncer: ncer,
            nanr: nanr,
            provenance: provenance
        )

        guard let result = results[sequenceIndex] else {
            throw ExtractCLIError.missingPretRenderAsset(path: nanr.path())
        }
        return result
    }

    private func extractSpriteSequences(
        sequenceIndices: [Int],
        assetIDPrefix: String,
        sceneDirectory: URL,
        intermediateDirectory: URL,
        helperScript: URL,
        pythonTool: URL,
        ncgr: URL,
        nclr: URL,
        ncer: URL,
        nanr: URL,
        provenance: String
    ) throws -> [Int: SpriteSequenceResult] {
        try FileManager.default.createDirectory(at: intermediateDirectory, withIntermediateDirectories: true)
        try runPythonHelper(
            pythonTool: pythonTool,
            helperScript: helperScript,
            arguments: [
                "sprite",
                "--ncgr", ncgr.path(),
                "--nclr", nclr.path(),
                "--ncer", ncer.path(),
                "--nanr", nanr.path(),
                "--output-dir", intermediateDirectory.path(),
            ]
        )
        let manifest = try loadJSON(
            HelperSpriteManifest.self,
            from: intermediateDirectory.appendingPathComponent("manifest.json", isDirectory: false)
        )

        var results: [Int: SpriteSequenceResult] = [:]
        for requestedIndex in sequenceIndices {
            guard let sequence = manifest.sequences.first(where: { $0.index == requestedIndex }) else {
                continue
            }

            var assets: [HGSSOpeningBundle.Asset] = []
            var assetIDsByPath: [String: String] = [:]
            for frame in sequence.frames {
                let source = intermediateDirectory.appendingPathComponent(frame.path, isDirectory: false)
                let destination = sceneDirectory.appendingPathComponent("\(assetIDPrefix)_\(frame.path.replacingOccurrences(of: "/", with: "_"))", isDirectory: false)
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: destination)
                let frameAssetID = "\(assetIDPrefix)_seq\(requestedIndex)_frame\(frame.cellIndex)_\(assets.count)"
                assetIDsByPath[frame.path] = frameAssetID
                assets.append(
                    HGSSOpeningBundle.Asset(
                        id: frameAssetID,
                        kind: .image,
                        relativePath: relativePathString(for: destination),
                        pixelWidth: frame.canvasWidth,
                        pixelHeight: frame.canvasHeight,
                        provenance: provenance
                    )
                )
            }

            let frameAssetIDs = sequence.expandedFrames.compactMap { assetIDsByPath[$0] }
            let canvasWidth = sequence.canvasWidth
            let canvasHeight = sequence.canvasHeight
            results[requestedIndex] = SpriteSequenceResult(
                assets: assets,
                frameAssetIDs: frameAssetIDs,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                originX: sequence.originX,
                originY: sequence.originY,
                upstreamFiles: [ncgr.path(), nclr.path(), ncer.path(), nanr.path(), provenance]
            )
        }

        return results
    }

    private func convertModel(
        assetID: String,
        sceneDirectory: URL,
        intermediateDirectory: URL,
        apicula: URL,
        inputs: [URL],
        provenance: String
    ) throws -> (asset: HGSSOpeningBundle.Asset, upstreamFiles: [String]) {
        try FileManager.default.createDirectory(at: intermediateDirectory, withIntermediateDirectories: true)
        try runProcess(
            executable: apicula,
            arguments: ["convert"] + inputs.map(\.path) + ["-o", intermediateDirectory.path(), "--overwrite"],
            commandLabel: "apicula convert"
        )

        let generatedFiles = try FileManager.default.contentsOfDirectory(
            at: intermediateDirectory,
            includingPropertiesForKeys: nil
        )
        let destinationDirectory = sceneDirectory.appendingPathComponent(assetID, isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        for file in generatedFiles {
            let destination = destinationDirectory.appendingPathComponent(file.lastPathComponent, isDirectory: false)
            if !FileManager.default.fileExists(atPath: destination.path()) {
                try FileManager.default.copyItem(at: file, to: destination)
            }
        }

        guard let dae = generatedFiles.first(where: { $0.pathExtension.lowercased() == "dae" }) else {
            throw ExtractCLIError.missingPretRenderAsset(path: intermediateDirectory.path())
        }
        let relativePath = relativePathString(for: destinationDirectory.appendingPathComponent(dae.lastPathComponent, isDirectory: false))
        let asset = HGSSOpeningBundle.Asset(
            id: assetID,
            kind: .modelScene,
            relativePath: relativePath,
            provenance: provenance
        )
        return (asset, inputs.map(\.path) + [provenance])
    }

    private func renderAudioCue(
        cueName: String,
        sceneID: String,
        audioRoot: URL,
        intermediateAudioRoot: URL,
        soundArchive: URL,
        helperScript: URL,
        pythonTool: URL,
        provenance: String
    ) throws -> RenderedAudioCueResult {
        let sceneAudioRoot = audioRoot.appendingPathComponent(sceneID, isDirectory: true)
        try FileManager.default.createDirectory(at: sceneAudioRoot, withIntermediateDirectories: true)
        let sceneIntermediateAudioRoot = intermediateAudioRoot.appendingPathComponent(sceneID, isDirectory: true)
        try FileManager.default.createDirectory(at: sceneIntermediateAudioRoot, withIntermediateDirectories: true)

        let wavOutput = sceneAudioRoot.appendingPathComponent("\(cueName.lowercased()).wav", isDirectory: false)
        let metadataOutput = sceneIntermediateAudioRoot.appendingPathComponent("\(cueName.lowercased()).json", isDirectory: false)

        try runPythonHelper(
            pythonTool: pythonTool,
            helperScript: helperScript,
            arguments: [
                "render-audio",
                "--input", soundArchive.path(),
                "--cue-name", cueName,
                "--output-wav", wavOutput.path(),
                "--output-json", metadataOutput.path(),
            ]
        )

        let asset = HGSSOpeningBundle.Asset(
            id: "\(sceneID)_\(cueName.lowercased())_audio",
            kind: .audioFile,
            relativePath: relativePathString(for: wavOutput),
            provenance: provenance
        )
        return .init(
            asset: asset,
            upstreamFiles: [soundArchive.path(), provenance],
            wavRelativePath: relativePathString(for: wavOutput),
            traceRelativePath: relativePathString(for: metadataOutput),
            cueName: cueName,
            sceneID: sceneID,
            provenance: provenance
        )
    }

    private func bakeModelScreens(
        bundle: HGSSOpeningBundle,
        outputRoot: URL,
        provenanceSources: inout [OpeningProvenanceDocument.AssetSource]
    ) throws -> HGSSOpeningBundle {
        let assetByID = Dictionary(uniqueKeysWithValues: bundle.assets.map { ($0.id, $0) })
        let provenanceByAssetID = Dictionary(uniqueKeysWithValues: provenanceSources.map { ($0.assetID, $0.upstreamFiles) })
        let fullScreen = HGSSOpeningBundle.ScreenRect(x: 0, y: 0, width: 256, height: 192)
        var assets = bundle.assets
        var scenes: [HGSSOpeningBundle.Scene] = []

        for scene in bundle.scenes {
            guard !scene.modelAnimations.isEmpty else {
                scenes.append(scene)
                continue
            }

            var topLayers = scene.topLayers
            var bottomLayers = scene.bottomLayers
            var spriteAnimations = scene.spriteAnimations
            let groupedModels = Dictionary(grouping: scene.modelAnimations, by: \.screen)

            for (screen, models) in groupedModels {
                let baked = try bakeModelScreen(
                    sceneID: scene.id,
                    screen: screen,
                    sceneDurationFrames: scene.durationFrames,
                    models: models,
                    assetByID: assetByID,
                    provenanceByAssetID: provenanceByAssetID,
                    outputRoot: outputRoot
                )

                assets.append(contentsOf: baked.assets)
                let assetSources = baked.assets.map {
                    OpeningProvenanceDocument.AssetSource(assetID: $0.id, upstreamFiles: baked.upstreamFiles)
                }
                provenanceSources.append(contentsOf: assetSources)

                if baked.frameAssetIDs.count == 1, baked.startFrame == 0, baked.endFrame == 0 {
                    let layer = HGSSOpeningBundle.LayerRef(
                        id: "\(scene.id.rawValue)_\(screen.rawValue)_model_bake_layer",
                        assetID: baked.frameAssetIDs[0],
                        screenRect: fullScreen,
                        zIndex: baked.zIndex
                    )
                    if screen == .top {
                        topLayers.append(layer)
                    } else {
                        bottomLayers.append(layer)
                    }
                } else {
                    spriteAnimations.append(
                        .init(
                            id: "\(scene.id.rawValue)_\(screen.rawValue)_model_bake_anim",
                            screen: screen,
                            frameAssetIDs: baked.frameAssetIDs,
                            screenRect: fullScreen,
                            frameDurationFrames: 1,
                            startFrame: baked.startFrame,
                            endFrame: baked.endFrame,
                            loop: false,
                            zIndex: baked.zIndex
                        )
                    )
                }
            }

            scenes.append(
                .init(
                    id: scene.id,
                    durationFrames: scene.durationFrames,
                    skipAllowedFromFrame: scene.skipAllowedFromFrame,
                    topLayers: topLayers,
                    bottomLayers: bottomLayers,
                    spriteAnimations: spriteAnimations,
                    modelAnimations: [],
                    transitionCues: scene.transitionCues,
                    audioCues: scene.audioCues
                )
            )
        }

        assets.sort { lhs, rhs in lhs.id < rhs.id }
        provenanceSources.sort { lhs, rhs in lhs.assetID < rhs.assetID }
        return HGSSOpeningBundle(
            schemaVersion: bundle.schemaVersion,
            canonicalVariant: bundle.canonicalVariant,
            topScreen: bundle.topScreen,
            bottomScreen: bundle.bottomScreen,
            assets: assets,
            scenes: scenes
        )
    }

    private func bakeModelScreen(
        sceneID: HGSSOpeningBundle.SceneID,
        screen: HGSSOpeningBundle.ScreenID,
        sceneDurationFrames: Int,
        models: [HGSSOpeningBundle.ModelAnimationRef],
        assetByID: [String: HGSSOpeningBundle.Asset],
        provenanceByAssetID: [String: [String]],
        outputRoot: URL
    ) throws -> BakedModelScreenResult {
        let screenSize = CGSize(width: 256, height: 192)
        let startFrame = models.map(\.startFrame).min() ?? 0
        let endFrame = models.map { $0.endFrame ?? (sceneDurationFrames - 1) }.max() ?? 0
        let zIndex = models.map(\.zIndex).min() ?? 1
        let screenDirectory = outputRoot
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent(sceneID.rawValue, isDirectory: true)

        var assets: [HGSSOpeningBundle.Asset] = []
        var frameAssetIDs: [String] = []
        var upstreamFiles: [String] = []

        var renderers: [String: SCNRenderer] = [:]
        for model in models {
            guard let asset = assetByID[model.assetID] else {
                throw ExtractCLIError.missingPretRenderAsset(path: model.assetID)
            }
            let assetURL = outputRoot.appendingPathComponent(asset.relativePath, isDirectory: false)
            renderers[model.id] = try makeModelRenderer(assetURL: assetURL, model: model)
        }

        for frame in startFrame...endFrame {
            let activeModels = models.filter { model in
                let modelEndFrame = model.endFrame ?? (sceneDurationFrames - 1)
                return frame >= model.startFrame && frame <= modelEndFrame
            }

            let composite = NSImage(size: screenSize)
            composite.lockFocus()
            NSColor.clear.set()
            NSBezierPath(rect: CGRect(origin: .zero, size: screenSize)).fill()

            for model in activeModels.sorted(by: { lhs, rhs in
                lhs.zIndex == rhs.zIndex ? lhs.id < rhs.id : lhs.zIndex < rhs.zIndex
            }) {
                guard let renderer = renderers[model.id] else {
                    continue
                }
                let sceneTime = modelSceneTime(model: model, sceneFrame: frame)
                let rendered = renderer.snapshot(
                    atTime: sceneTime,
                    with: screenSize,
                    antialiasingMode: .none
                )
                rendered.draw(in: CGRect(origin: .zero, size: screenSize))
            }

            composite.unlockFocus()

            let assetID = "\(sceneID.rawValue)_\(screen.rawValue)_model_bake_frame_\(frame)"
            let outputURL = screenDirectory.appendingPathComponent("\(assetID).png", isDirectory: false)
            try writePNG(composite, to: outputURL)
            assets.append(
                .init(
                    id: assetID,
                    kind: .image,
                    relativePath: relativePathString(for: outputURL),
                    pixelWidth: Int(screenSize.width),
                    pixelHeight: Int(screenSize.height),
                    provenance: screen == .top ? "External/pokeheartgold/src/intro_movie_scene_3.c" : "External/pokeheartgold/src/title_screen.c"
                )
            )
            frameAssetIDs.append(assetID)
        }

        for model in models {
            upstreamFiles.append(contentsOf: provenanceByAssetID[model.assetID] ?? [])
        }
        upstreamFiles = Array(Set(upstreamFiles)).sorted()

        return BakedModelScreenResult(
            assets: assets,
            frameAssetIDs: frameAssetIDs,
            startFrame: startFrame,
            endFrame: endFrame,
            zIndex: zIndex,
            upstreamFiles: upstreamFiles
        )
    }

    private func makeModelRenderer(
        assetURL: URL,
        model: HGSSOpeningBundle.ModelAnimationRef
    ) throws -> SCNRenderer {
        _ = NSApplication.shared
        let stagedAssetURL = try stageModelAssetForSceneKit(assetURL)
        let scene = try SCNScene(url: stagedAssetURL, options: nil)
        scene.background.contents = NSColor.clear
        configureModelScene(scene, model: model)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: "openingCamera", recursively: false)
        renderer.isJitteringEnabled = false
        return renderer
    }

    private func configureModelScene(
        _ scene: SCNScene,
        model: HGSSOpeningBundle.ModelAnimationRef
    ) {
        if let translation = model.translation {
            scene.rootNode.position = SCNVector3(Float(translation.x), Float(translation.y), Float(translation.z))
        }

        if let camera = model.camera {
            let cameraNode = SCNNode()
            let scnCamera = SCNCamera()
            if let fieldOfViewDegrees = camera.fieldOfViewDegrees {
                scnCamera.fieldOfView = fieldOfViewDegrees
            }
            if let nearClipDistance = camera.nearClipDistance {
                scnCamera.zNear = max(0.001, nearClipDistance)
            }
            if let farClipDistance = sceneKitFarClipDistance(for: camera) {
                scnCamera.zFar = farClipDistance
            }
            cameraNode.name = "openingCamera"
            cameraNode.camera = scnCamera
            cameraNode.position = SCNVector3(Float(camera.position.x), Float(camera.position.y), Float(camera.position.z))
            cameraNode.look(at: SCNVector3(Float(camera.target.x), Float(camera.target.y), Float(camera.target.z)))
            scene.rootNode.addChildNode(cameraNode)
        }

        scene.rootNode.enumerateChildNodes { node, _ in
            if node.light != nil {
                node.removeFromParentNode()
            }
        }

        for lightState in model.lights {
            let directionVector = SIMD3<Float>(
                Float(lightState.direction.x),
                Float(lightState.direction.y),
                Float(lightState.direction.z)
            )
            guard simd_length_squared(directionVector) > 0.000001 else {
                continue
            }

            let lightNode = SCNNode()
            let light = SCNLight()
            light.type = .directional
            light.color = nsColor(hex: lightState.colorHex)
            lightNode.light = light
            lightNode.simdLook(at: simd_normalize(directionVector), up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
            scene.rootNode.addChildNode(lightNode)
        }

        if let materialState = model.material {
            scene.rootNode.enumerateHierarchy { node, _ in
                guard let geometry = node.geometry else {
                    return
                }

                for material in geometry.materials {
                    if let diffuseHex = materialState.diffuseHex {
                        material.multiply.contents = nsColor(hex: diffuseHex)
                    }
                    if let ambientHex = materialState.ambientHex {
                        material.ambient.contents = nsColor(hex: ambientHex)
                    }
                    if let specularHex = materialState.specularHex {
                        material.specular.contents = nsColor(hex: specularHex)
                    }
                    if let emissionHex = materialState.emissionHex {
                        material.emission.contents = nsColor(hex: emissionHex)
                    }
                }
            }
        }

        scene.isPaused = false
    }

    private func sceneKitFarClipDistance(
        for camera: HGSSOpeningBundle.ModelAnimationRef.CameraState
    ) -> Double? {
        guard let farClipDistance = camera.farClipDistance else {
            return nil
        }

        let dx = camera.position.x - camera.target.x
        let dy = camera.position.y - camera.target.y
        let dz = camera.position.z - camera.target.z
        let targetDistance = sqrt((dx * dx) + (dy * dy) + (dz * dz))
        guard farClipDistance > targetDistance else {
            return nil
        }
        return farClipDistance
    }

    private func stageModelAssetForSceneKit(_ assetURL: URL) throws -> URL {
        let sourceDirectory = assetURL.deletingLastPathComponent()
        let stagedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-3d-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.copyItem(at: sourceDirectory, to: stagedDirectory)
        return stagedDirectory.appendingPathComponent(assetURL.lastPathComponent, isDirectory: false)
    }

    private func modelSceneTime(
        model: HGSSOpeningBundle.ModelAnimationRef,
        sceneFrame: Int
    ) -> TimeInterval {
        let frameValue: Double
        if let freezeAtFrame = model.freezeAtFrame {
            frameValue = freezeAtFrame
        } else {
            let relativeFrame = max(0, sceneFrame - model.startFrame)
            if model.loop {
                frameValue = Double(relativeFrame)
            } else if let endFrame = model.endFrame {
                frameValue = Double(min(relativeFrame, max(0, endFrame - model.startFrame)))
            } else {
                frameValue = Double(relativeFrame)
            }
        }

        return frameValue / 60.0
    }

    private func writePNG(_ image: NSImage, to url: URL) throws {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw ExtractCLIError.imageWriteFailed(path: url.path())
        }

        try pngData.write(to: url)
    }

    private func nsColor(hex: String) -> NSColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
    }

    private func relativePathString(for url: URL) -> String {
        let path = url.path()
        if let range = path.range(of: "/intermediate/") {
            return String(path[path.index(after: range.lowerBound)...])
        }
        if let range = path.range(of: "/assets/") {
            return String(path[path.index(after: range.lowerBound)...])
        }
        if let range = path.range(of: "/audio/") {
            return String(path[path.index(after: range.lowerBound)...])
        }
        return url.lastPathComponent
    }

    private func makeScene4Timing(
        source: Scene4SourceConfig,
        particleManifest: Scene4ParticleManifest,
        sparkleFrameCount: Int
    ) throws -> Scene4Timing {
        guard sparkleFrameCount > 0 else {
            throw OpeningHeartGoldExtractModeError.missingScene4SparklesSequence
        }

        let resourceDurations = Dictionary(
            uniqueKeysWithValues: particleManifest.resources.map { resource in
                let duration = resource.base.startOffsetFrames
                    + resource.base.emitterLifeFrames
                    + resource.base.particleLifeFrames
                    + (resource.child?.lifeFrames ?? 0)
                    + 1
                return (resource.id, duration)
            }
        )

        let starterParticleResourceIDs = [
            [6, 7, 8],
            [3, 4, 5],
            [0, 1, 2],
        ]

        func maxParticleDuration(for resourceIDs: [Int]) throws -> Int {
            try resourceIDs.reduce(into: 0) { currentMax, resourceID in
                guard let duration = resourceDurations[resourceID] else {
                    throw OpeningHeartGoldExtractModeError.missingScene4ParticleResource(resourceID)
                }
                currentMax = max(currentMax, duration)
            }
        }

        let fadeInDurationFrames = source.fadeInDurationFrames
        let slideDurationFrames = source.slideInWindowTop.durationFrames
        let holdPlayersDurationFrames = source.holdPlayersThreshold + 1
        let starterFlipDurationFrames = 1
        let fadeToBlackDurationFrames = source.fadeToBlackDurationFrames

        let grassParticleDurationFrames = try maxParticleDuration(for: starterParticleResourceIDs[0])
        let fireParticleDurationFrames = try maxParticleDuration(for: starterParticleResourceIDs[1])
        let waterParticleDurationFrames = try maxParticleDuration(for: starterParticleResourceIDs[2])

        let slideInStartFrame = fadeInDurationFrames + 1
        let slideOutStartFrame = slideInStartFrame + slideDurationFrames + 1 + holdPlayersDurationFrames
        let playersEndFrame = slideOutStartFrame + slideDurationFrames

        let chikoritaDurationFrames = 1 + grassParticleDurationFrames + starterFlipDurationFrames
        let chikoritaStartFrame = playersEndFrame + 1
        let chikoritaEndFrame = chikoritaStartFrame + chikoritaDurationFrames - 1

        let cyndaquilDurationFrames = 1 + fireParticleDurationFrames + starterFlipDurationFrames
        let cyndaquilStartFrame = chikoritaEndFrame + 1
        let cyndaquilEndFrame = cyndaquilStartFrame + cyndaquilDurationFrames - 1

        let totodileDurationFrames = 1 + waterParticleDurationFrames + fadeToBlackDurationFrames
        let totodileStartFrame = cyndaquilEndFrame + 1
        let totodileEndFrame = totodileStartFrame + totodileDurationFrames - 1
        let fadeToBlackStartFrame = totodileEndFrame - fadeToBlackDurationFrames + 1

        let sparklesStartFrame = totodileEndFrame + 1
        let sparklesEndFrame = sparklesStartFrame + sparkleFrameCount - 1

        return Scene4Timing(
            fadeInDurationFrames: fadeInDurationFrames,
            slideDurationFrames: slideDurationFrames,
            fadeToBlackDurationFrames: fadeToBlackDurationFrames,
            grassParticleDurationFrames: grassParticleDurationFrames,
            fireParticleDurationFrames: fireParticleDurationFrames,
            waterParticleDurationFrames: waterParticleDurationFrames,
            slideInStartFrame: slideInStartFrame,
            slideOutStartFrame: slideOutStartFrame,
            playersEndFrame: playersEndFrame,
            chikoritaStartFrame: chikoritaStartFrame,
            chikoritaEndFrame: chikoritaEndFrame,
            cyndaquilStartFrame: cyndaquilStartFrame,
            cyndaquilEndFrame: cyndaquilEndFrame,
            totodileStartFrame: totodileStartFrame,
            totodileEndFrame: totodileEndFrame,
            fadeToBlackStartFrame: fadeToBlackStartFrame,
            sparklesStartFrame: sparklesStartFrame,
            sparklesEndFrame: sparklesEndFrame,
            totalDurationFrames: sparklesEndFrame + 1
        )
    }
}

private func spriteRect(
    from result: SpriteSequenceResult?,
    positionX: Double,
    positionY: Double,
    surfaceX: Double = 0,
    surfaceY: Double = 0
) -> HGSSOpeningBundle.ScreenRect {
    let width = Double(result?.canvasWidth ?? 64)
    let height = Double(result?.canvasHeight ?? 64)
    let originX = Double(result?.originX ?? 0)
    let originY = Double(result?.originY ?? 0)
    return .init(
        x: (positionX - surfaceX) + originX,
        y: (positionY - surfaceY) + originY,
        width: width,
        height: height
    )
}

private func staticFrameAssetIDs(from result: SpriteSequenceResult?) -> [String] {
    guard let firstFrame = result?.frameAssetIDs.first else {
        return []
    }
    return [firstFrame]
}

private func rgb15Hex(red: Int, green: Int, blue: Int) -> String {
    func convert(_ component: Int) -> Int {
        Int(round((Double(component) / 31.0) * 255.0))
    }

    return String(
        format: "#%02X%02X%02X",
        convert(red),
        convert(green),
        convert(blue)
    )
}
