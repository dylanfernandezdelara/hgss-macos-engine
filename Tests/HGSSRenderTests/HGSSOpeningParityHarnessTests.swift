import AppKit
import CryptoKit
import Foundation
import HGSSCore
import HGSSDataModel
@testable import HGSSRender
import Testing

@MainActor
struct HGSSOpeningParityHarnessTests {
    @Test("Visual parity digests remain stable across opening, title, CheckSave, and MainMenu")
    func visualParityDigestsRemainStable() throws {
        guard parityContentIsAvailable else {
            return
        }
        let actual = try makeVisualSnapshot()
        let fixturesURL = fixturesRootURL().appendingPathComponent("opening_visual_parity_snapshot.json", isDirectory: false)

        if shouldRecordFixtures {
            try writeJSON(actual, to: fixturesURL)
            return
        }

        let expected = try JSONDecoder().decode(
            VisualParitySnapshot.self,
            from: Data(contentsOf: fixturesURL)
        )
        #expect(actual == expected)
    }

    @Test("Audio parity digests and runtime cue trace remain stable")
    func audioParityDigestsAndRuntimeCueTraceRemainStable() throws {
        guard parityContentIsAvailable else {
            return
        }
        let actual = try makeAudioSnapshot()
        let fixturesURL = fixturesRootURL().appendingPathComponent("opening_audio_parity_snapshot.json", isDirectory: false)

        if shouldRecordFixtures {
            try writeJSON(actual, to: fixturesURL)
            return
        }

        let expected = try JSONDecoder().decode(
            AudioParitySnapshot.self,
            from: Data(contentsOf: fixturesURL)
        )
        #expect(actual == expected)
    }

    private func makeVisualSnapshot() throws -> VisualParitySnapshot {
        let loadedBundle = try OpeningBundleLoader().load(from: contentRootURL())
        let loadedProgram = try OpeningProgramLoader().load(from: contentRootURL())
        let compositor = HGSSOpeningScreenCompositor(loadedBundle: loadedBundle)

        let openingController = HGSSOpeningPlaybackController(
            loadedBundle: loadedBundle,
            loadedProgram: loadedProgram,
            bootstrapState: .noSave
        )
        let openingFrames = try captureOpeningFrames(
            controller: openingController,
            compositor: compositor,
            loadedBundle: loadedBundle
        )

        let noSaveController = HGSSOpeningPlaybackController(
            loadedBundle: loadedBundle,
            loadedProgram: loadedProgram,
            bootstrapState: .noSave
        )
        let noSaveFrames = try capturePostTitleFrames(
            scenarioID: "title_no_save",
            controller: noSaveController,
            compositor: compositor,
            loadedBundle: loadedBundle,
            menuBootstrapAction: { controller in
                controller.requestSkip()
            },
            completion: { controller in
                controller.lastMenuDispatch != nil
            }
        )

        let corruptedSummary = HGSSOpeningSaveSummary(
            hasUsableSaveData: true,
            mainSaveStatus: .corrupted,
            battleHallStatus: .absent,
            battleVideoStatus: .absent,
            hasPokedex: true,
            mysteryGiftEnabled: true,
            rangerEnabled: true,
            connectToWiiEnabled: true,
            connectedAGBGame: .ruby
        )
        let continueController = HGSSOpeningPlaybackController(
            loadedBundle: loadedBundle,
            loadedProgram: loadedProgram,
            bootstrapState: .init(saveSummary: corruptedSummary)
        )
        let continueFrames = try capturePostTitleFrames(
            scenarioID: "title_check_save_to_continue",
            controller: continueController,
            compositor: compositor,
            loadedBundle: loadedBundle,
            menuBootstrapAction: { controller in
                controller.requestSkip()
            },
            completion: { controller in
                controller.currentProgramState?.id == "main_menu_continue"
            }
        )

        return VisualParitySnapshot(
            openingFrames: openingFrames,
            noSaveFrames: noSaveFrames,
            continueFrames: continueFrames
        )
    }

    private func makeAudioSnapshot() throws -> AudioParitySnapshot {
        let contentRoot = contentRootURL()
        let loadedBundle = try OpeningBundleLoader().load(from: contentRoot)
        let loadedProgram = try OpeningProgramLoader().load(from: contentRoot)

        let corruptedSummary = HGSSOpeningSaveSummary(
            hasUsableSaveData: true,
            mainSaveStatus: .corrupted,
            battleHallStatus: .absent,
            battleVideoStatus: .absent,
            hasPokedex: true,
            mysteryGiftEnabled: true,
            rangerEnabled: true,
            connectToWiiEnabled: true,
            connectedAGBGame: .ruby
        )
        let controller = HGSSOpeningPlaybackController(
            loadedBundle: loadedBundle,
            loadedProgram: loadedProgram,
            bootstrapState: .init(saveSummary: corruptedSummary)
        )

        var requestedMenu = false
        var confirmedMessageStates = Set<String>()
        var trace: [AudioTraceEvent] = []
        var consumedCueCount = 0

        captureNewAudioEvents(
            from: controller,
            into: &trace,
            consumedCueCount: &consumedCueCount
        )

        try fastForwardToTitleProgram(controller)
        captureNewAudioEvents(
            from: controller,
            into: &trace,
            consumedCueCount: &consumedCueCount
        )

        var safetyCounter = 0
        while controller.currentProgramState?.id != "main_menu_continue" {
            if controller.currentProgramState?.id == "title_play", requestedMenu == false {
                controller.requestSkip()
                requestedMenu = true
                captureNewAudioEvents(
                    from: controller,
                    into: &trace,
                    consumedCueCount: &consumedCueCount
                )
            }

            if let currentStateID = controller.currentProgramState?.id,
               currentStateID.hasPrefix("check_save_message_"),
               confirmedMessageStates.insert(currentStateID).inserted {
                controller.requestSkip()
                captureNewAudioEvents(
                    from: controller,
                    into: &trace,
                    consumedCueCount: &consumedCueCount
                )
            }

            controller.advanceFrame()
            captureNewAudioEvents(
                from: controller,
                into: &trace,
                consumedCueCount: &consumedCueCount
            )

            safetyCounter += 1
            if safetyCounter > 2_048 {
                Issue.record("Timed out while tracing opening/menu audio parity.")
                break
            }
        }

        let cueAssets = try [
            makeCueAssetSnapshot(
                cueName: "SEQ_GS_TITLE",
                wavURL: contentRoot.appendingPathComponent("audio/scene1/seq_gs_title.wav", isDirectory: false),
                traceURL: contentRoot.appendingPathComponent("intermediate/audio/scene1/seq_gs_title.json", isDirectory: false)
            ),
            makeCueAssetSnapshot(
                cueName: "SEQ_GS_POKEMON_THEME",
                wavURL: contentRoot.appendingPathComponent("audio/title_handoff/seq_gs_pokemon_theme.wav", isDirectory: false),
                traceURL: contentRoot.appendingPathComponent("intermediate/audio/title_handoff/seq_gs_pokemon_theme.json", isDirectory: false)
            ),
        ]

        return AudioParitySnapshot(
            cueAssets: cueAssets,
            runtimeTrace: trace
        )
    }

    private func captureOpeningFrames(
        controller: HGSSOpeningPlaybackController,
        compositor: HGSSOpeningScreenCompositor,
        loadedBundle: LoadedOpeningBundle
    ) throws -> [VisualFrameDigest] {
        var frames: [VisualFrameDigest] = []

        while controller.currentScene.id != .titleHandoff {
            frames.append(
                try captureFrameDigest(
                    scenarioID: "opening",
                    controller: controller,
                    compositor: compositor,
                    loadedBundle: loadedBundle
                )
            )

            controller.advanceFrame()
        }

        return frames
    }

    private func capturePostTitleFrames(
        scenarioID: String,
        controller: HGSSOpeningPlaybackController,
        compositor: HGSSOpeningScreenCompositor,
        loadedBundle: LoadedOpeningBundle,
        menuBootstrapAction: (HGSSOpeningPlaybackController) -> Void,
        completion: (HGSSOpeningPlaybackController) -> Bool
    ) throws -> [VisualFrameDigest] {
        var frames: [VisualFrameDigest] = []
        var requestedMenu = false
        var confirmedMessageStates = Set<String>()
        var safetyCounter = 0

        try fastForwardToTitleProgram(controller)
        menuBootstrapAction(controller)

        while true {
            if controller.currentProgramScene != nil {
                frames.append(
                    try captureFrameDigest(
                        scenarioID: scenarioID,
                        controller: controller,
                        compositor: compositor,
                        loadedBundle: loadedBundle
                    )
                )
            }

            if completion(controller) {
                break
            }

            if controller.currentProgramState?.id == "title_play", requestedMenu == false {
                controller.requestSkip()
                requestedMenu = true
                continue
            }

            if let currentStateID = controller.currentProgramState?.id,
               currentStateID.hasPrefix("check_save_message_"),
               confirmedMessageStates.insert(currentStateID).inserted {
                controller.requestSkip()
                continue
            }

            controller.advanceFrame()
            safetyCounter += 1
            if safetyCounter > 2_048 {
                Issue.record("Timed out while capturing \(scenarioID) parity frames.")
                break
            }
        }

        return frames
    }

    private func fastForwardToTitleProgram(
        _ controller: HGSSOpeningPlaybackController
    ) throws {
        var safetyCounter = 0

        while controller.currentProgramScene == nil {
            if let skipAllowedFromFrame = controller.currentScene.skipAllowedFromFrame,
               controller.state.frameInScene >= skipAllowedFromFrame {
                controller.requestSkip()
            } else {
                controller.advanceFrame()
            }

            safetyCounter += 1
            if safetyCounter > 4_096 {
                throw NSError(
                    domain: "HGSSRenderTests",
                    code: 402,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Timed out while fast-forwarding opening playback to the title program."
                    ]
                )
            }
        }
    }

    private func captureFrameDigest(
        scenarioID: String,
        controller: HGSSOpeningPlaybackController,
        compositor: HGSSOpeningScreenCompositor,
        loadedBundle: LoadedOpeningBundle
    ) throws -> VisualFrameDigest {
        let topImage = compositor.render(
            screen: .top,
            size: loadedBundle.bundle.topScreen,
            controller: controller
        )
        let bottomImage = compositor.render(
            screen: .bottom,
            size: loadedBundle.bundle.bottomScreen,
            controller: controller
        )

        return VisualFrameDigest(
            scenarioID: scenarioID,
            bundleSceneID: controller.currentScene.id.rawValue,
            programSceneID: controller.currentProgramScene?.id.rawValue,
            programStateID: controller.currentProgramState?.id,
            frameInScene: controller.state.frameInScene,
            frameInProgramState: controller.state.frameInProgramState,
            topDigest: try sha256Hex(ofBitmapDataIn: topImage),
            bottomDigest: try sha256Hex(ofBitmapDataIn: bottomImage)
        )
    }

    private func captureNewAudioEvents(
        from controller: HGSSOpeningPlaybackController,
        into trace: inout [AudioTraceEvent],
        consumedCueCount: inout Int
    ) {
        while consumedCueCount < controller.audioCueLog.count {
            let dispatchedCue = controller.audioCueLog[consumedCueCount]
            trace.append(
                AudioTraceEvent(
                    index: consumedCueCount,
                    bundleSceneID: controller.currentScene.id.rawValue,
                    programSceneID: controller.currentProgramScene?.id.rawValue,
                    programStateID: controller.currentProgramState?.id,
                    action: dispatchedCue.cue.action.rawValue,
                    cueName: dispatchedCue.cue.cueName,
                    fadeDurationFrames: dispatchedCue.cue.fadeDurationFrames
                )
            )
            consumedCueCount += 1
        }
    }

    private func makeCueAssetSnapshot(
        cueName: String,
        wavURL: URL,
        traceURL: URL
    ) throws -> CueAssetSnapshot {
        CueAssetSnapshot(
            cueName: cueName,
            wavDigest: try sha256Hex(of: Data(contentsOf: wavURL)),
            traceDigest: try sha256Hex(of: Data(contentsOf: traceURL))
        )
    }

    private func sha256Hex(ofBitmapDataIn image: NSImage) throws -> String {
        guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
              let bitmapData = bitmap.bitmapData else {
            throw NSError(
                domain: "HGSSRenderTests",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Failed to access bitmap data for parity capture."]
            )
        }

        let data = Data(
            bytes: bitmapData,
            count: bitmap.bytesPerRow * bitmap.pixelsHigh
        )
        return try sha256Hex(of: data)
    }

    private func sha256Hex(of data: Data) throws -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url)
    }

    private var shouldRecordFixtures: Bool {
        ProcessInfo.processInfo.environment["HGSS_RECORD_OPENING_PARITY"] == "1"
    }

    private func contentRootURL() -> URL {
        repoRootURL().appendingPathComponent("Content/Local/Boot/HeartGold", isDirectory: true)
    }

    private func fixturesRootURL() -> URL {
        repoRootURL().appendingPathComponent("Tests/Fixtures/PretOpening", isDirectory: true)
    }

    private var parityContentIsAvailable: Bool {
        let contentRoot = contentRootURL()
        return FileManager.default.fileExists(
            atPath: contentRoot.appendingPathComponent("opening_bundle.json", isDirectory: false).path()
        ) && FileManager.default.fileExists(
            atPath: contentRoot.appendingPathComponent("opening_program_ir.json", isDirectory: false).path()
        )
    }

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct VisualParitySnapshot: Codable, Equatable {
    let openingFrames: [VisualFrameDigest]
    let noSaveFrames: [VisualFrameDigest]
    let continueFrames: [VisualFrameDigest]
}

private struct VisualFrameDigest: Codable, Equatable {
    let scenarioID: String
    let bundleSceneID: String
    let programSceneID: String?
    let programStateID: String?
    let frameInScene: Int
    let frameInProgramState: Int
    let topDigest: String
    let bottomDigest: String
}

private struct AudioParitySnapshot: Codable, Equatable {
    let cueAssets: [CueAssetSnapshot]
    let runtimeTrace: [AudioTraceEvent]
}

private struct CueAssetSnapshot: Codable, Equatable {
    let cueName: String
    let wavDigest: String
    let traceDigest: String
}

private struct AudioTraceEvent: Codable, Equatable {
    let index: Int
    let bundleSceneID: String
    let programSceneID: String?
    let programStateID: String?
    let action: String
    let cueName: String
    let fadeDurationFrames: Int?
}
