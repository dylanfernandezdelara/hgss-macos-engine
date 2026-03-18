import Foundation
import HGSSDataModel
import HGSSRender
import Testing

struct HGSSOpeningRenderTests {
    @Test("Loads opening bundle and resolves local asset URLs")
    func loadsOpeningBundle() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeAsset(at: root, relativePath: "assets/scene1/top.png")
        try writeAsset(at: root, relativePath: "assets/title_handoff/top.png")
        try writeAsset(at: root, relativePath: "audio/scene1/title.wav")

        let bundle = makeBundle(
            scenes: [
                .init(
                    id: .scene1,
                    durationFrames: 10,
                    skipAllowedFromFrame: 5,
                    topLayers: [.init(id: "top", assetID: "scene1_top", screenRect: .init(x: 0, y: 0, width: 256, height: 192), zIndex: 1)],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: [
                        .init(
                            id: "bgm",
                            action: .startBGM,
                            cueName: "SEQ_GS_TITLE",
                            frame: 0,
                            playableAssetID: "scene1_title_bgm",
                            provenance: "pret"
                        )
                    ]
                ),
                .init(id: .scene2, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene3, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene4, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene5, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(
                    id: .titleHandoff,
                    durationFrames: 1,
                    skipAllowedFromFrame: 0,
                    topLayers: [.init(id: "title", assetID: "title_top", screenRect: .init(x: 0, y: 0, width: 256, height: 192), zIndex: 1)],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: []
                ),
            ],
            assets: [
                .init(id: "scene1_top", kind: .image, relativePath: "assets/scene1/top.png", pixelWidth: 256, pixelHeight: 192, provenance: "pret"),
                .init(id: "title_top", kind: .image, relativePath: "assets/title_handoff/top.png", pixelWidth: 256, pixelHeight: 192, provenance: "pret"),
                .init(id: "scene1_title_bgm", kind: .audioFile, relativePath: "audio/scene1/title.wav", provenance: "pret"),
            ]
        )
        try writeBundle(bundle, to: root)

        let loaded = try OpeningBundleLoader().load(from: root)

        #expect(loaded.bundle.canonicalVariant == .heartGold)
        #expect(loaded.bundle.scenes.map(\.id) == HGSSOpeningBundle.SceneID.allCases)
        #expect(try loaded.assetURL(id: "scene1_top").lastPathComponent == "top.png")
    }

    @Test("Rejects invalid opening scene order")
    func rejectsInvalidOpeningSceneOrder() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = makeBundle(
            scenes: [
                .init(id: .scene2, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene1, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene3, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene4, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene5, durationFrames: 10, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .titleHandoff, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
            ],
            assets: []
        )
        try writeBundle(bundle, to: root)

        do {
            _ = try OpeningBundleLoader().load(from: root)
            Issue.record("Expected invalid opening scene order to fail loading.")
        } catch let error as HGSSRenderError {
            if case let .invalidOpeningSceneOrder(_, actual) = error {
                #expect(actual.first == "scene2")
            } else {
                Issue.record("Expected invalidOpeningSceneOrder error, got \(error.localizedDescription).")
            }
        }
    }

    @Test("Rejects invalid title handoff duration")
    func rejectsInvalidTitleHandoffDuration() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = makeBundle(
            scenes: HGSSOpeningBundle.SceneID.allCases.map { id in
                .init(
                    id: id,
                    durationFrames: id == .titleHandoff ? 2 : 10,
                    skipAllowedFromFrame: 0,
                    topLayers: [],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: []
                )
            },
            assets: []
        )
        try writeBundle(bundle, to: root)

        do {
            _ = try OpeningBundleLoader().load(from: root)
            Issue.record("Expected invalid title handoff duration to fail loading.")
        } catch let error as HGSSRenderError {
            if case .invalidTitleHandoffDuration = error {
                #expect(true)
            } else {
                Issue.record("Expected invalidTitleHandoffDuration error, got \(error.localizedDescription).")
            }
        }
    }

    @Test("Rejects invalid opening skip windows")
    func rejectsInvalidOpeningSkipWindow() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = makeBundle(
            scenes: HGSSOpeningBundle.SceneID.allCases.map { id in
                .init(
                    id: id,
                    durationFrames: id == .titleHandoff ? 1 : 10,
                    skipAllowedFromFrame: id == .scene1 ? 10 : 0,
                    topLayers: [],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: []
                )
            },
            assets: []
        )
        try writeBundle(bundle, to: root)

        do {
            _ = try OpeningBundleLoader().load(from: root)
            Issue.record("Expected invalid opening skip window to fail loading.")
        } catch let error as HGSSRenderError {
            if case let .invalidOpeningSkipWindow(sceneID, _, _) = error {
                #expect(sceneID == "scene1")
            } else {
                Issue.record("Expected invalidOpeningSkipWindow error, got \(error.localizedDescription).")
            }
        }
    }

    @Test("Playback controller advances scene durations and dispatches cues")
    @MainActor
    func playbackControllerAdvancesAndDispatchesCues() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeAsset(at: root, relativePath: "assets/title/title.png")

        let bundle = makeBundle(
            scenes: [
                .init(
                    id: .scene1,
                    durationFrames: 3,
                    skipAllowedFromFrame: 1,
                    topLayers: [],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: [.init(id: "scene1_bgm", action: .startBGM, cueName: "SEQ_GS_TITLE", frame: 0, provenance: "pret")]
                ),
                .init(id: .scene2, durationFrames: 2, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: [.init(id: "scene2_cue", action: .stopBGM, cueName: "SEQ_GS_TITLE", frame: 1, provenance: "pret")]),
                .init(id: .scene3, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene4, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene5, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(
                    id: .titleHandoff,
                    durationFrames: 1,
                    skipAllowedFromFrame: 0,
                    topLayers: [.init(id: "title", assetID: "title_top", screenRect: .init(x: 0, y: 0, width: 256, height: 192), zIndex: 1)],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: [.init(id: "title_bgm", action: .startBGM, cueName: "SEQ_GS_POKEMON_THEME", frame: 0, provenance: "pret")]
                ),
            ],
            assets: [.init(id: "title_top", kind: .image, relativePath: "assets/title/title.png", pixelWidth: 256, pixelHeight: 192, provenance: "pret")]
        )
        try writeBundle(bundle, to: root)

        let loaded = try OpeningBundleLoader().load(from: root)
        let controller = HGSSOpeningPlaybackController(loadedBundle: loaded)

        #expect(controller.currentScene.id == .scene1)
        #expect(controller.audioCueLog.map(\.cue.cueName) == ["SEQ_GS_TITLE"])

        controller.advanceFrame()
        #expect(controller.state.frameInScene == 1)

        controller.advanceFrame()
        #expect(controller.state.frameInScene == 2)

        controller.advanceFrame()
        #expect(controller.currentScene.id == .scene2)
        #expect(controller.state.frameInScene == 0)

        controller.advanceFrame()
        #expect(controller.audioCueLog.map(\.cue.cueName).contains("SEQ_GS_TITLE"))
        #expect(controller.audioCueLog.map(\.cue.cueName).contains("SEQ_GS_POKEMON_THEME") == false)

        controller.advanceFrame()
        controller.advanceFrame()
        controller.advanceFrame()
        controller.advanceFrame()
        #expect(controller.currentScene.id == .titleHandoff)
        #expect(controller.state.hasReachedTitleHandoff)
        #expect(controller.audioCueLog.last?.cue.cueName == "SEQ_GS_POKEMON_THEME")
    }

    @Test("Skip only activates once the extracted gate allows it")
    @MainActor
    func skipRespectsGate() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = makeBundle(
            scenes: HGSSOpeningBundle.SceneID.allCases.map { id in
                .init(
                    id: id,
                    durationFrames: id == .titleHandoff ? 1 : 4,
                    skipAllowedFromFrame: id == .scene1 ? 2 : 0,
                    topLayers: [],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: []
                )
            },
            assets: []
        )
        try writeBundle(bundle, to: root)

        let loaded = try OpeningBundleLoader().load(from: root)
        let controller = HGSSOpeningPlaybackController(loadedBundle: loaded)

        controller.requestSkip()
        #expect(controller.currentScene.id == .scene1)

        controller.advanceFrame()
        controller.requestSkip()
        #expect(controller.currentScene.id == .scene1)

        controller.advanceFrame()
        controller.requestSkip()
        #expect(controller.currentScene.id == .titleHandoff)
        #expect(controller.state.hasReachedTitleHandoff)
    }

    @Test("Skip remains disabled in later scenes unless that scene explicitly allows it")
    @MainActor
    func skipRequiresCurrentSceneGate() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = makeBundle(
            scenes: [
                .init(id: .scene1, durationFrames: 2, skipAllowedFromFrame: 1, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene2, durationFrames: 3, skipAllowedFromFrame: nil, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene3, durationFrames: 2, skipAllowedFromFrame: 1, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene4, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene5, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .titleHandoff, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
            ],
            assets: []
        )
        try writeBundle(bundle, to: root)

        let loaded = try OpeningBundleLoader().load(from: root)
        let controller = HGSSOpeningPlaybackController(loadedBundle: loaded)

        controller.advanceFrame()
        controller.requestSkip()
        #expect(controller.currentScene.id == .titleHandoff)

        controller.reset()
        controller.advanceFrame()
        controller.advanceFrame()
        #expect(controller.currentScene.id == .scene2)

        controller.requestSkip()
        #expect(controller.currentScene.id == .scene2)

        controller.advanceFrame()
        controller.advanceFrame()
        controller.advanceFrame()
        #expect(controller.currentScene.id == .scene3)

        controller.requestSkip()
        #expect(controller.currentScene.id == .scene3)

        controller.advanceFrame()
        controller.requestSkip()
        #expect(controller.currentScene.id == .titleHandoff)
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-render-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeAsset(at root: URL, relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
    }

    private func writeBundle(_ bundle: HGSSOpeningBundle, to root: URL) throws {
        let data = try JSONEncoder().encode(bundle)
        try data.write(to: root.appendingPathComponent("opening_bundle.json", isDirectory: false))
    }

    private func makeBundle(
        scenes: [HGSSOpeningBundle.Scene],
        assets: [HGSSOpeningBundle.Asset]
    ) -> HGSSOpeningBundle {
        HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: assets,
            scenes: scenes
        )
    }
}
