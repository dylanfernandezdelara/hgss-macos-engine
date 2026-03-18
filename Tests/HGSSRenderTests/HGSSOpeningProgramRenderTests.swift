import Foundation
import HGSSDataModel
import HGSSOpeningIR
import HGSSRender
import Testing

struct HGSSOpeningProgramRenderTests {
    @Test("Loads opening program IR from local content")
    func loadsOpeningProgramIR() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeProgram(makeProgram(), to: root)

        let loaded = try OpeningProgramLoader().load(from: root)

        #expect(loaded.program.entrySceneID == .titleScreen)
        #expect(loaded.program.scenes.first?.id == .titleScreen)
    }

    @Test("Playback controller consumes title program states instead of freezing at title handoff")
    @MainActor
    func playbackControllerConsumesTitleProgram() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeAsset(at: root, relativePath: "assets/title_handoff/top.png")
        try writeAsset(at: root, relativePath: "audio/title_handoff/theme.wav")
        try writeBundle(makeBundle(), to: root)
        try writeProgram(makeProgram(), to: root)

        let loadedBundle = try OpeningBundleLoader().load(from: root)
        let loadedProgram = try OpeningProgramLoader().load(from: root)
        let controller = HGSSOpeningPlaybackController(
            loadedBundle: loadedBundle,
            loadedProgram: loadedProgram
        )

        controller.requestSkip()
        #expect(controller.currentScene.id == .titleHandoff)
        #expect(controller.currentProgramState?.id == "title_start_music")
        #expect(controller.audioCueLog.last?.cue.cueName == "SEQ_GS_POKEMON_THEME")

        controller.advanceFrame()
        #expect(controller.currentProgramState?.id == "title_play_delay")

        controller.advanceFrame()
        #expect(controller.currentProgramState?.id == "title_play_delay")
        #expect(controller.isProgramLayerVisible("start_prompt") == false)

        controller.advanceFrame()
        #expect(controller.currentProgramState?.id == "title_play")
        #expect(controller.isProgramLayerVisible("start_prompt") == true)

        controller.advanceFrame()
        #expect(controller.isProgramLayerVisible("start_prompt") == false)

        controller.requestSkip()
        controller.advanceFrame()
        #expect(controller.currentProgramState?.id == "title_proceed_flash")
        let whiteFade = try #require(controller.activeProgramFadeOverlay())
        #expect(whiteFade.colorHex == "#FFFFFF")

        controller.advanceFrame()
        #expect(controller.currentProgramState?.id == "title_proceed_flash_2")

        controller.advanceFrame()
        controller.advanceFrame()
        #expect(controller.currentProgramState?.id == "title_fadeout")

        controller.advanceFrame()
        #expect(controller.currentProgramScene?.id == .mainMenu)
        #expect(controller.currentProgramState?.id == "main_menu_new_game")
        let menu = try #require(controller.activeMenu(screen: .bottom))
        #expect(menu.options.map(\.text) == ["NEW GAME"])
        #expect(controller.state.hasReachedOpeningMenuHandoff)
        #expect(controller.audioCueLog.last?.cue.action == .stopBGM)
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-program-render-tests-\(UUID().uuidString)", isDirectory: true)
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

    private func writeProgram(_ program: HGSSOpeningProgramIR, to root: URL) throws {
        let data = try JSONEncoder().encode(program)
        try data.write(to: root.appendingPathComponent("opening_program_ir.json", isDirectory: false))
    }

    private func makeBundle() -> HGSSOpeningBundle {
        HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: [
                .init(
                    id: "title_top",
                    kind: .image,
                    relativePath: "assets/title_handoff/top.png",
                    pixelWidth: 256,
                    pixelHeight: 192,
                    provenance: "pret"
                ),
                .init(
                    id: "title_theme",
                    kind: .audioFile,
                    relativePath: "audio/title_handoff/theme.wav",
                    provenance: "pret"
                ),
            ],
            scenes: [
                .init(id: .scene1, durationFrames: 2, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene2, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene3, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene4, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene5, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(
                    id: .titleHandoff,
                    durationFrames: 1,
                    skipAllowedFromFrame: 0,
                    topLayers: [
                        .init(
                            id: "title_top_layer",
                            assetID: "title_top",
                            screenRect: .init(x: 0, y: 0, width: 256, height: 192),
                            zIndex: 1
                        )
                    ],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: [
                        .init(
                            id: "title_theme_start",
                            action: .startBGM,
                            cueName: "SEQ_GS_POKEMON_THEME",
                            frame: 0,
                            playableAssetID: "title_theme",
                            provenance: "pret"
                        )
                    ]
                ),
            ]
        )
    }

    private func makeProgram() -> HGSSOpeningProgramIR {
        let provenance = HGSSOpeningProgramIR.Provenance(
            sourceFile: "src/title_screen.c",
            symbol: "TitleScreen_Main"
        )
        return HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .titleScreen,
            sourceFiles: [
                "src/title_screen.c",
                "src/application/check_savedata.c",
                "src/application/main_menu/main_menu.c",
            ],
            scenes: [
                .init(
                    id: .titleScreen,
                    initialStateID: "title_wait_fade",
                    states: [
                        .init(
                            id: "title_wait_fade",
                            duration: .indefinite,
                            commands: [],
                            transitions: [
                                .init(
                                    trigger: .flagEquals(name: "title_anim_initialized", value: 1),
                                    targetStateID: "title_start_music",
                                    provenance: provenance
                                )
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "title_start_music",
                            duration: .fixedFrames(1),
                            commands: [
                                .dispatchAudio(
                                    .init(action: .startBGM, cueName: "SEQ_GS_POKEMON_THEME", provenance: provenance)
                                )
                            ],
                            transitions: [
                                .init(trigger: .stateCompleted, targetStateID: "title_play_delay", provenance: provenance)
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "title_play_delay",
                            duration: .fixedFrames(2),
                            commands: [
                                .setLayerVisibility(
                                    .init(layerID: "start_prompt", visible: false, provenance: provenance)
                                )
                            ],
                            transitions: [
                                .init(trigger: .stateCompleted, targetStateID: "title_play", provenance: provenance)
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "title_play",
                            duration: .fixedFrames(4),
                            commands: [
                                .setPromptFlash(
                                    .init(
                                        targetID: "start_prompt",
                                        visibleFrames: 1,
                                        hiddenFrames: 1,
                                        screen: .top,
                                        rect: .init(x: 0, y: 144, width: 256, height: 16),
                                        text: "TOUCH TO START",
                                        initialPhase: .visible,
                                        provenance: provenance
                                    )
                                )
                            ],
                            transitions: [
                                .init(
                                    trigger: .flagEquals(name: "title_menu_requested", value: 1),
                                    targetStateID: "title_proceed_flash",
                                    provenance: provenance
                                ),
                                .init(
                                    trigger: .stateCompleted,
                                    targetStateID: "title_proceed_noflash",
                                    provenance: provenance
                                )
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "title_proceed_flash",
                            duration: .fixedFrames(1),
                            commands: [
                                .setLayerVisibility(
                                    .init(layerID: "start_prompt", visible: false, provenance: provenance)
                                ),
                                .fade(
                                    .init(
                                        target: .palette,
                                        startLevel: 0,
                                        endLevel: 31,
                                        durationFrames: 1,
                                        colorHex: "#FFFFFF",
                                        provenance: provenance
                                    )
                                )
                            ],
                            transitions: [
                                .init(trigger: .stateCompleted, targetStateID: "title_proceed_flash_2", provenance: provenance)
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "title_proceed_flash_2",
                            duration: .fixedFrames(2),
                            commands: [
                                .setLayerVisibility(
                                    .init(layerID: "start_prompt", visible: false, provenance: provenance)
                                )
                            ],
                            transitions: [
                                .init(trigger: .stateCompleted, targetStateID: "title_fadeout", provenance: provenance)
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "title_proceed_noflash",
                            duration: .fixedFrames(3),
                            commands: [
                                .setLayerVisibility(
                                    .init(layerID: "start_prompt", visible: false, provenance: provenance)
                                )
                            ],
                            transitions: [
                                .init(trigger: .stateCompleted, targetStateID: "title_fadeout", provenance: provenance)
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "title_fadeout",
                            duration: .fixedFrames(1),
                            commands: [
                                .dispatchAudio(
                                    .init(action: .stopBGM, cueName: "SEQ_GS_POKEMON_THEME", provenance: provenance)
                                ),
                                .fade(
                                    .init(
                                        target: .palette,
                                        startLevel: 0,
                                        endLevel: 31,
                                        durationFrames: 1,
                                        colorHex: "#000000",
                                        provenance: provenance
                                    )
                                )
                            ],
                            transitions: [
                                .init(
                                    trigger: .stateCompleted,
                                    targetSceneID: .checkSave,
                                    targetStateID: "check_save_route",
                                    provenance: provenance
                                )
                            ],
                            provenance: provenance
                        ),
                    ],
                    provenance: provenance
                ),
                .init(
                    id: .checkSave,
                    initialStateID: "check_save_route",
                    states: [
                        .init(
                            id: "check_save_route",
                            duration: .indefinite,
                            commands: [
                                .setSolidFill(
                                    .init(screen: .top, colorHex: "#000000", provenance: provenance)
                                ),
                                .setSolidFill(
                                    .init(screen: .bottom, colorHex: "#000000", provenance: provenance)
                                )
                            ],
                            transitions: [
                                .init(
                                    trigger: .flagEquals(name: "check_save_message_index", value: -1),
                                    targetSceneID: .mainMenu,
                                    targetStateID: "main_menu_route",
                                    provenance: provenance
                                )
                            ],
                            provenance: provenance
                        ),
                    ],
                    provenance: provenance
                ),
                .init(
                    id: .mainMenu,
                    initialStateID: "main_menu_route",
                    states: [
                        .init(
                            id: "main_menu_route",
                            duration: .indefinite,
                            commands: [
                                .setSolidFill(
                                    .init(screen: .top, colorHex: "#6363FF", provenance: provenance)
                                ),
                                .setSolidFill(
                                    .init(screen: .bottom, colorHex: "#6363FF", provenance: provenance)
                                )
                            ],
                            transitions: [
                                .init(
                                    trigger: .flagEquals(name: "main_menu_has_save_data", value: 0),
                                    targetStateID: "main_menu_new_game",
                                    provenance: provenance
                                )
                            ],
                            provenance: provenance
                        ),
                        .init(
                            id: "main_menu_new_game",
                            duration: .indefinite,
                            commands: [
                                .setSolidFill(
                                    .init(screen: .top, colorHex: "#6363FF", provenance: provenance)
                                ),
                                .setSolidFill(
                                    .init(screen: .bottom, colorHex: "#6363FF", provenance: provenance)
                                ),
                                .setMenu(
                                    .init(
                                        screen: .bottom,
                                        options: [
                                            .init(id: "new_game", text: "NEW GAME")
                                        ],
                                        selectedOptionID: "new_game",
                                        provenance: provenance
                                    )
                                )
                            ],
                            transitions: [],
                            provenance: provenance
                        ),
                    ],
                    provenance: provenance
                )
            ]
        )
    }
}
