import Foundation
import HGSSCore
import HGSSDataModel
import HGSSOpeningIR
import HGSSRender
@testable import HGSSExtractCLI
import Testing

@MainActor
struct OpeningProgramTraceTests {
    @Test("Runtime traces match source-backed title exits, CheckSave routing, and MainMenu setup")
    @MainActor
    func runtimeTracesMatchSourceBackedScenarios() throws {
        let pretRoot = repoRootURL().appendingPathComponent("External/pokeheartgold", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pretRoot.path()) else {
            return
        }

        let supportRoot = try makeTemporaryRoot(prefix: "hgss-opening-trace-support")
        defer { try? FileManager.default.removeItem(at: supportRoot) }

        let validation = try PokeheartgoldOpeningSourceValidator().validate(
            pretRoot: pretRoot,
            supportRoot: supportRoot
        )
        let program = try PokeheartgoldOpeningIRLowerer().lower(
            validation: validation,
            pretRoot: pretRoot
        )

        try program.validate()

        #expect(try traceTitleMenuExit(program: program, bootstrapState: .noSave) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash_2"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_menu"),
            .init(bundleSceneID: "title_handoff", programSceneID: "main_menu", programStateID: "main_menu_new_game"),
        ])

        #expect(try traceTitleMenuExit(
            program: program,
            bootstrapState: .init(
                mainMenuHasSaveData: true,
                mainMenuHasPokedex: true,
                drawMysteryGift: true,
                connectedAgbGame: 1
            )
        ) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash_2"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_menu"),
            .init(
                bundleSceneID: "title_handoff",
                programSceneID: "main_menu",
                programStateID: "main_menu_continue",
                selectedMenuOptionID: "continue",
                visibleMenuOptionIDs: [
                    "continue",
                    "new_game",
                    "pokewalker",
                    "mystery_gift",
                    "migrate_ruby",
                    "wfc",
                    "wii_settings",
                ]
            ),
        ])

        #expect(try traceTitleTimeoutExit(program: program) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_noflash"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_timeout"),
            .init(bundleSceneID: "scene1", programSceneID: nil, programStateID: nil),
        ])

        #expect(try traceClearSaveExit(program: program) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_clearsave"),
            .init(bundleSceneID: "title_handoff", programSceneID: "delete_save", programStateID: "delete_save_handoff"),
        ])

        #expect(try traceMicTestExit(program: program) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_mic_test"),
            .init(bundleSceneID: "title_handoff", programSceneID: "mic_test", programStateID: "mic_test_handoff"),
        ])

        #expect(try traceCheckSaveCorrupted(program: program) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash_2"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_menu"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_prepare_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_in_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_message_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_out_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "main_menu", programStateID: "main_menu_new_game"),
        ])
    }

    @Test("Menu confirmation dispatch preserves source-backed destination IDs")
    @MainActor
    func menuDispatchPreservesSourceBackedDestinationIDs() throws {
        let pretRoot = repoRootURL().appendingPathComponent("External/pokeheartgold", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pretRoot.path()) else {
            return
        }

        let supportRoot = try makeTemporaryRoot(prefix: "hgss-opening-dispatch-support")
        defer { try? FileManager.default.removeItem(at: supportRoot) }

        let validation = try PokeheartgoldOpeningSourceValidator().validate(
            pretRoot: pretRoot,
            supportRoot: supportRoot
        )
        let program = try PokeheartgoldOpeningIRLowerer().lower(
            validation: validation,
            pretRoot: pretRoot
        )

        try program.validate()

        let bootstrapVariants: [HGSSOpeningBootstrapState] = [
            .init(
                mainMenuHasSaveData: true,
                mainMenuHasPokedex: true,
                drawMysteryGift: true,
                drawRanger: true,
                drawConnectToWii: true,
                connectedAgbGame: 1
            ),
            .init(
                mainMenuHasSaveData: true,
                mainMenuHasPokedex: true,
                drawMysteryGift: true,
                drawRanger: true,
                drawConnectToWii: true,
                connectedAgbGame: 2
            ),
            .init(
                mainMenuHasSaveData: true,
                mainMenuHasPokedex: true,
                drawMysteryGift: true,
                drawRanger: true,
                drawConnectToWii: true,
                connectedAgbGame: 3
            ),
            .init(
                mainMenuHasSaveData: true,
                mainMenuHasPokedex: true,
                drawMysteryGift: true,
                drawRanger: true,
                drawConnectToWii: true,
                connectedAgbGame: 4
            ),
            .init(
                mainMenuHasSaveData: true,
                mainMenuHasPokedex: true,
                drawMysteryGift: true,
                drawRanger: true,
                drawConnectToWii: true,
                connectedAgbGame: 5
            ),
        ]

        for bootstrapState in bootstrapVariants {
            let controller = try advanceToMainMenu(program: program, bootstrapState: bootstrapState)
            let menu = try #require(controller.activeMenu(screen: .bottom))

            for option in menu.options where option.enabled {
                try selectMenuOption(option.id, on: controller, menu: menu)
                controller.confirmCurrentMenuSelection()
                #expect(controller.lastMenuDispatch == .init(
                    menuStateID: "main_menu_continue",
                    selectionID: option.id,
                    destinationID: option.destinationID
                ))
            }
        }
    }

    @Test("Runtime reaches MainMenu from a real local save snapshot without synthetic bootstrap defaults")
    @MainActor
    func runtimeReachesMainMenuFromLocalSaveSnapshot() throws {
        let pretRoot = repoRootURL().appendingPathComponent("External/pokeheartgold", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pretRoot.path()) else {
            return
        }

        let supportRoot = try makeTemporaryRoot(prefix: "hgss-opening-save-trace-support")
        defer { try? FileManager.default.removeItem(at: supportRoot) }

        let validation = try PokeheartgoldOpeningSourceValidator().validate(
            pretRoot: pretRoot,
            supportRoot: supportRoot
        )
        let program = try PokeheartgoldOpeningIRLowerer().lower(
            validation: validation,
            pretRoot: pretRoot
        )
        try program.validate()

        let bootstrapRoot = try makeTemporaryRoot(prefix: "hgss-opening-save-bootstrap")
        defer { try? FileManager.default.removeItem(at: bootstrapRoot) }

        let featureFlags = HGSSOpeningFeatureAvailability(
            mysteryGiftEnabled: nil,
            rangerEnabled: true,
            connectToWiiEnabled: true,
            connectedAGBGame: .emerald
        )
        try JSONEncoder().encode(featureFlags).write(
            to: bootstrapRoot.appendingPathComponent(HGSSOpeningLocalSaveSummaryLoader.featureAvailabilityFilename, isDirectory: false)
        )
        try makeOpeningRawSave(
            primaryMirror: .init(
                saveNumber: 21,
                hasPokedex: true,
                hasNationalDex: true,
                mysteryGiftReceived: false,
                mysteryGiftSystemActive: true
            ),
            secondaryMirror: nil
        ).write(
            to: bootstrapRoot.appendingPathComponent(HGSSOpeningLocalSaveSummaryLoader.localSaveFilenames[0], isDirectory: false)
        )

        let bootstrapState = try HGSSOpeningBootstrapLoader().load(from: bootstrapRoot)

        #expect(try traceCheckSaveCorruptedToContinue(
            program: program,
            bootstrapState: bootstrapState
        ) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash_2"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_menu"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_prepare_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_in_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_message_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_out_save_corrupted"),
            .init(
                bundleSceneID: "title_handoff",
                programSceneID: "main_menu",
                programStateID: "main_menu_continue",
                selectedMenuOptionID: "continue",
                visibleMenuOptionIDs: [
                    "continue",
                    "new_game",
                    "pokewalker",
                    "mystery_gift",
                    "ranger",
                    "migrate_emerald",
                    "connect_to_wii",
                    "wfc",
                    "wii_settings",
                ]
            ),
        ])
    }

    @Test("Runtime routes battle hall and battle video warnings from a real local save snapshot")
    @MainActor
    func runtimeRoutesFrontierWarningsFromLocalSaveSnapshot() throws {
        let pretRoot = repoRootURL().appendingPathComponent("External/pokeheartgold", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pretRoot.path()) else {
            return
        }

        let supportRoot = try makeTemporaryRoot(prefix: "hgss-opening-frontier-trace-support")
        defer { try? FileManager.default.removeItem(at: supportRoot) }

        let validation = try PokeheartgoldOpeningSourceValidator().validate(
            pretRoot: pretRoot,
            supportRoot: supportRoot
        )
        let program = try PokeheartgoldOpeningIRLowerer().lower(
            validation: validation,
            pretRoot: pretRoot
        )
        try program.validate()

        let bootstrapRoot = try makeTemporaryRoot(prefix: "hgss-opening-frontier-bootstrap")
        defer { try? FileManager.default.removeItem(at: bootstrapRoot) }

        try makeOpeningRawSave(
            primaryMirror: .init(
                saveNumber: 22,
                hasPokedex: true,
                hasNationalDex: false,
                mysteryGiftReceived: false,
                mysteryGiftSystemActive: false,
                frontierMetadataByChunkID: [
                    1: .init(currentToken: 0x1020_3040, previousToken: 0xFFFF_FFFF, activeSlot: 1),
                    2: .init(currentToken: 0x1111_2222, previousToken: 0xFFFF_FFFF, activeSlot: 0),
                ],
                frontierChunkCopiesByChunkID: [
                    1: .init(token: 0x1020_3040),
                ]
            ),
            secondaryMirror: nil
        ).write(
            to: bootstrapRoot.appendingPathComponent(HGSSOpeningLocalSaveSummaryLoader.localSaveFilenames[0], isDirectory: false)
        )

        let bootstrapState = try HGSSOpeningBootstrapLoader().load(from: bootstrapRoot)

        #expect(try traceCheckSaveFrontierWarnings(
            program: program,
            bootstrapState: bootstrapState
        ) == [
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_start_music"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play_delay"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_play"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_proceed_flash_2"),
            .init(bundleSceneID: "title_handoff", programSceneID: "title_screen", programStateID: "title_fadeout_menu"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_prepare_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_in_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_message_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_out_save_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_prepare_battle_hall_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_in_battle_hall_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_message_battle_hall_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_out_battle_hall_corrupted"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_prepare_battle_video_erased"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_in_battle_video_erased"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_message_battle_video_erased"),
            .init(bundleSceneID: "title_handoff", programSceneID: "check_save", programStateID: "check_save_fade_out_battle_video_erased"),
            .init(
                bundleSceneID: "title_handoff",
                programSceneID: "main_menu",
                programStateID: "main_menu_continue",
                selectedMenuOptionID: "continue",
                visibleMenuOptionIDs: [
                    "continue",
                    "new_game",
                    "pokewalker",
                    "wfc",
                    "wii_settings",
                ]
            ),
        ])
    }

    private func traceTitleMenuExit(
        program: HGSSOpeningProgramIR,
        bootstrapState: HGSSOpeningBootstrapState
    ) throws -> [ProgramTraceStep] {
        let controller = try makeController(program: program, bootstrapState: bootstrapState)
        controller.requestSkip()

        var trace: [ProgramTraceStep] = []
        appendTraceStep(from: controller, into: &trace)
        var requestedMenu = false

        for _ in 0..<4_000 {
            if controller.currentProgramState?.id == "title_play" && requestedMenu == false {
                controller.requestSkip()
                requestedMenu = true
                appendTraceStep(from: controller, into: &trace)
            }

            if controller.currentProgramState?.id == "main_menu_new_game"
                || controller.currentProgramState?.id == "main_menu_continue"
            {
                return trace
            }

            controller.advanceFrame()
            appendTraceStep(from: controller, into: &trace)
        }

        Issue.record("Timed out waiting for title menu exit trace.")
        return trace
    }

    private func traceTitleTimeoutExit(
        program: HGSSOpeningProgramIR
    ) throws -> [ProgramTraceStep] {
        let controller = try makeController(program: program, bootstrapState: .noSave)
        controller.requestSkip()

        var trace: [ProgramTraceStep] = []
        appendTraceStep(from: controller, into: &trace)

        for _ in 0..<4_000 {
            if controller.currentProgramScene == nil && controller.currentScene.id == .scene1 {
                return trace
            }

            controller.advanceFrame()
            appendTraceStep(from: controller, into: &trace)
        }

        Issue.record("Timed out waiting for title timeout trace.")
        return trace
    }

    private func traceClearSaveExit(
        program: HGSSOpeningProgramIR
    ) throws -> [ProgramTraceStep] {
        let controller = try makeController(program: program, bootstrapState: .noSave)
        controller.requestSkip()

        var trace: [ProgramTraceStep] = []
        appendTraceStep(from: controller, into: &trace)
        var requestedExit = false

        for _ in 0..<4_000 {
            if controller.currentProgramState?.id == "title_play" && requestedExit == false {
                _ = controller.requestProgramFlagMutations(
                    [
                        "title_clear_save_requested": 1,
                        "title_mic_test_requested": 0,
                    ],
                    sceneID: .titleScreen,
                    stateID: "title_play"
                )
                requestedExit = true
            }

            if controller.currentProgramScene?.id == .deleteSave
                && controller.currentProgramState?.id == "delete_save_handoff"
            {
                return trace
            }

            controller.advanceFrame()
            appendTraceStep(from: controller, into: &trace)
        }

        Issue.record("Timed out waiting for clear-save trace.")
        return trace
    }

    private func traceMicTestExit(
        program: HGSSOpeningProgramIR
    ) throws -> [ProgramTraceStep] {
        let controller = try makeController(program: program, bootstrapState: .noSave)
        controller.requestSkip()

        var trace: [ProgramTraceStep] = []
        appendTraceStep(from: controller, into: &trace)
        var requestedExit = false

        for _ in 0..<4_000 {
            if controller.currentProgramState?.id == "title_play" && requestedExit == false {
                _ = controller.requestProgramFlagMutations(
                    [
                        "title_mic_test_requested": 1,
                        "title_clear_save_requested": 0,
                    ],
                    sceneID: .titleScreen,
                    stateID: "title_play"
                )
                requestedExit = true
            }

            if controller.currentProgramScene?.id == .micTest
                && controller.currentProgramState?.id == "mic_test_handoff"
            {
                return trace
            }

            controller.advanceFrame()
            appendTraceStep(from: controller, into: &trace)
        }

        Issue.record("Timed out waiting for mic-test trace.")
        return trace
    }

    private func traceCheckSaveCorrupted(
        program: HGSSOpeningProgramIR
    ) throws -> [ProgramTraceStep] {
        let controller = try makeController(
            program: program,
            bootstrapState: .init(checkSaveStatusFlags: 1 << 0)
        )
        controller.requestSkip()

        var trace: [ProgramTraceStep] = []
        appendTraceStep(from: controller, into: &trace)
        var requestedMenu = false
        var confirmedMessage = false

        for _ in 0..<4_000 {
            if controller.currentProgramState?.id == "title_play" && requestedMenu == false {
                controller.requestSkip()
                requestedMenu = true
                appendTraceStep(from: controller, into: &trace)
            }

            if controller.currentProgramState?.id == "check_save_message_save_corrupted" && confirmedMessage == false {
                controller.requestSkip()
                confirmedMessage = true
                appendTraceStep(from: controller, into: &trace)
            }

            if controller.currentProgramState?.id == "main_menu_new_game" {
                return trace
            }

            controller.advanceFrame()
            appendTraceStep(from: controller, into: &trace)
        }

        Issue.record("Timed out waiting for CheckSave corrupted trace.")
        return trace
    }

    private func traceCheckSaveCorruptedToContinue(
        program: HGSSOpeningProgramIR,
        bootstrapState: HGSSOpeningBootstrapState
    ) throws -> [ProgramTraceStep] {
        let controller = try makeController(
            program: program,
            bootstrapState: bootstrapState
        )
        controller.requestSkip()

        var trace: [ProgramTraceStep] = []
        appendTraceStep(from: controller, into: &trace)
        var requestedMenu = false
        var confirmedMessage = false

        for _ in 0..<4_000 {
            if controller.currentProgramState?.id == "title_play" && requestedMenu == false {
                controller.requestSkip()
                requestedMenu = true
                appendTraceStep(from: controller, into: &trace)
            }

            if controller.currentProgramState?.id == "check_save_message_save_corrupted" && confirmedMessage == false {
                controller.requestSkip()
                confirmedMessage = true
                appendTraceStep(from: controller, into: &trace)
            }

            if controller.currentProgramState?.id == "main_menu_continue" {
                return trace
            }

            controller.advanceFrame()
            appendTraceStep(from: controller, into: &trace)
        }

        Issue.record("Timed out waiting for save-backed MainMenu trace.")
        return trace
    }

    private func traceCheckSaveFrontierWarnings(
        program: HGSSOpeningProgramIR,
        bootstrapState: HGSSOpeningBootstrapState
    ) throws -> [ProgramTraceStep] {
        let controller = try makeController(
            program: program,
            bootstrapState: bootstrapState
        )
        controller.requestSkip()

        var trace: [ProgramTraceStep] = []
        appendTraceStep(from: controller, into: &trace)
        var requestedMenu = false
        var confirmedMessageStates = Set<String>()

        for _ in 0..<4_000 {
            if controller.currentProgramState?.id == "title_play" && requestedMenu == false {
                controller.requestSkip()
                requestedMenu = true
                appendTraceStep(from: controller, into: &trace)
            }

            if let currentStateID = controller.currentProgramState?.id,
               currentStateID.hasPrefix("check_save_message_"),
               confirmedMessageStates.insert(currentStateID).inserted {
                controller.requestSkip()
                appendTraceStep(from: controller, into: &trace)
            }

            if controller.currentProgramState?.id == "main_menu_continue" {
                return trace
            }

            controller.advanceFrame()
            appendTraceStep(from: controller, into: &trace)
        }

        Issue.record("Timed out waiting for frontier warning trace.")
        return trace
    }

    private func appendTraceStep(
        from controller: HGSSOpeningPlaybackController,
        into trace: inout [ProgramTraceStep]
    ) {
        let menu = controller.activeMenu(screen: .bottom) ?? controller.activeMenu(screen: .top)
        let nextStep = ProgramTraceStep(
            bundleSceneID: controller.currentScene.id.rawValue,
            programSceneID: controller.currentProgramScene?.id.rawValue,
            programStateID: controller.currentProgramState?.id,
            selectedMenuOptionID: menu.map { controller.resolvedMenuSelectionID(for: $0) },
            visibleMenuOptionIDs: menu?.options.map(\.id) ?? []
        )

        if trace.last != nextStep {
            trace.append(nextStep)
        }
    }

    private func advanceToMainMenu(
        program: HGSSOpeningProgramIR,
        bootstrapState: HGSSOpeningBootstrapState
    ) throws -> HGSSOpeningPlaybackController {
        let controller = try makeController(program: program, bootstrapState: bootstrapState)
        controller.requestSkip()

        var requestedMenu = false
        for _ in 0..<4_000 {
            if controller.currentProgramState?.id == "title_play" && requestedMenu == false {
                controller.requestSkip()
                requestedMenu = true
            }

            if controller.currentProgramState?.id == "main_menu_continue" {
                return controller
            }

            controller.advanceFrame()
        }

        Issue.record("Timed out waiting to reach the interactive main menu.")
        return controller
    }

    private func selectMenuOption(
        _ optionID: String,
        on controller: HGSSOpeningPlaybackController,
        menu: HGSSOpeningProgramIR.MenuCommand
    ) throws {
        guard menu.options.contains(where: { $0.id == optionID }) else {
            Issue.record("Expected menu option \(optionID) to be visible.")
            return
        }

        for _ in 0..<menu.options.count {
            if controller.resolvedMenuSelectionID(for: menu) == optionID {
                return
            }
            controller.moveCurrentMenuSelection(delta: 1)
        }

        Issue.record("Failed to select menu option \(optionID).")
    }

    private func makeController(
        program: HGSSOpeningProgramIR,
        bootstrapState: HGSSOpeningBootstrapState
    ) throws -> HGSSOpeningPlaybackController {
        let root = try makeTemporaryRoot(prefix: "hgss-opening-trace-runtime")
        defer { try? FileManager.default.removeItem(at: root) }

        try writeBundle(minimalBundle(), to: root)
        try writeProgram(program, to: root)

        let loadedBundle = try OpeningBundleLoader().load(from: root)
        let loadedProgram = try OpeningProgramLoader().load(from: root)
        return HGSSOpeningPlaybackController(
            loadedBundle: loadedBundle,
            loadedProgram: loadedProgram,
            bootstrapState: bootstrapState
        )
    }

    private func minimalBundle() -> HGSSOpeningBundle {
        HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: [],
            scenes: [
                .init(id: .scene1, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene2, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene3, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene4, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .scene5, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
                .init(id: .titleHandoff, durationFrames: 1, skipAllowedFromFrame: 0, topLayers: [], bottomLayers: [], spriteAnimations: [], modelAnimations: [], transitionCues: [], audioCues: []),
            ]
        )
    }

    private func writeBundle(_ bundle: HGSSOpeningBundle, to root: URL) throws {
        let data = try JSONEncoder().encode(bundle)
        try data.write(to: root.appendingPathComponent("opening_bundle.json", isDirectory: false))
    }

    private func writeProgram(_ program: HGSSOpeningProgramIR, to root: URL) throws {
        let data = try JSONEncoder().encode(program)
        try data.write(to: root.appendingPathComponent("opening_program_ir.json", isDirectory: false))
    }

    private func makeTemporaryRoot(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct SyntheticOpeningSaveMirror {
    let saveNumber: UInt32
    let hasPokedex: Bool
    let hasNationalDex: Bool
    let mysteryGiftReceived: Bool
    let mysteryGiftSystemActive: Bool

    let frontierMetadataByChunkID: [Int: SyntheticOpeningFrontierMetadata]
    let frontierChunkCopiesByChunkID: [Int: SyntheticOpeningExtraChunkCopy]

    init(
        saveNumber: UInt32,
        hasPokedex: Bool,
        hasNationalDex: Bool,
        mysteryGiftReceived: Bool,
        mysteryGiftSystemActive: Bool,
        frontierMetadataByChunkID: [Int: SyntheticOpeningFrontierMetadata] = [:],
        frontierChunkCopiesByChunkID: [Int: SyntheticOpeningExtraChunkCopy] = [:]
    ) {
        self.saveNumber = saveNumber
        self.hasPokedex = hasPokedex
        self.hasNationalDex = hasNationalDex
        self.mysteryGiftReceived = mysteryGiftReceived
        self.mysteryGiftSystemActive = mysteryGiftSystemActive
        self.frontierMetadataByChunkID = frontierMetadataByChunkID
        self.frontierChunkCopiesByChunkID = frontierChunkCopiesByChunkID
    }
}

private struct SyntheticOpeningFrontierMetadata {
    let currentToken: UInt32
    let previousToken: UInt32
    let activeSlot: UInt8
}

private struct SyntheticOpeningExtraChunkCopy {
    let token: UInt32
    let footerIsValid: Bool

    init(token: UInt32, footerIsValid: Bool = true) {
        self.token = token
        self.footerIsValid = footerIsValid
    }
}

private func makeOpeningRawSave(
    primaryMirror: SyntheticOpeningSaveMirror?,
    secondaryMirror: SyntheticOpeningSaveMirror?
) -> Data {
    var rawSave = Data(repeating: 0, count: 0x80000)
    if let primaryMirror {
        let bytes = makeOpeningSaveMirror(primaryMirror)
        rawSave.replaceSubrange(0 ..< 0x40000, with: bytes)
    }
    if let secondaryMirror {
        let bytes = makeOpeningSaveMirror(secondaryMirror)
        rawSave.replaceSubrange(0x40000 ..< 0x80000, with: bytes)
    }
    return rawSave
}

private func makeOpeningSaveMirror(_ mirror: SyntheticOpeningSaveMirror) -> Data {
    var data = Data(repeating: 0, count: 0x40000)
    var cursor = 0x200

    writeOpeningChunk(
        index: 0,
        payload: makeSysInfoPayload(mysteryGiftSystemActive: mirror.mysteryGiftSystemActive),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )
    writeOpeningChunk(
        index: 6,
        payload: makePokedexPayload(hasPokedex: mirror.hasPokedex, hasNationalDex: mirror.hasNationalDex),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )
    writeOpeningChunk(
        index: 27,
        payload: makeMysteryGiftPayload(receivedFlag7FF: mirror.mysteryGiftReceived),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )
    writeOpeningChunk(
        index: 9,
        payload: makeSaveMiscPayload(frontierMetadataByChunkID: mirror.frontierMetadataByChunkID),
        saveNumber: mirror.saveNumber,
        into: &data,
        cursor: &cursor
    )

    for (chunkID, copy) in mirror.frontierChunkCopiesByChunkID {
        writeOpeningExtraChunk(
            chunkID: chunkID,
            copy: copy,
            saveNumber: mirror.saveNumber,
            into: &data
        )
    }

    return data
}

private func writeOpeningChunk(
    index: UInt16,
    payload: Data,
    saveNumber: UInt32,
    into mirror: inout Data,
    cursor: inout Int
) {
    let footerSize = 16
    let footerStart = cursor + payload.count
    let chunkEnd = footerStart + footerSize

    mirror.replaceSubrange(cursor ..< footerStart, with: payload)

    var footerPrefix = Data()
    footerPrefix.appendLittleEndian(UInt32(0x2006_0623))
    footerPrefix.appendLittleEndian(saveNumber)
    footerPrefix.appendLittleEndian(UInt32(payload.count))
    footerPrefix.appendLittleEndian(index)

    let crc = openingTestCRC16(payload + footerPrefix)
    var footer = footerPrefix
    footer.appendLittleEndian(crc)
    mirror.replaceSubrange(footerStart ..< chunkEnd, with: footer)

    cursor = chunkEnd + 0x80
}

private func makeSysInfoPayload(mysteryGiftSystemActive: Bool) -> Data {
    var payload = Data(repeating: 0, count: 0x5C)
    payload[0x48] = mysteryGiftSystemActive ? 1 : 0
    return payload
}

private func makePokedexPayload(hasPokedex: Bool, hasNationalDex: Bool) -> Data {
    var payload = Data(repeating: 0, count: 0x340)
    payload[0x336] = hasPokedex ? 1 : 0
    payload[0x337] = hasNationalDex ? 1 : 0
    return payload
}

private func makeMysteryGiftPayload(receivedFlag7FF: Bool) -> Data {
    var payload = Data(repeating: 0, count: 0x1680)
    payload[0xFF] = receivedFlag7FF ? 0x80 : 0
    return payload
}

private func makeSaveMiscPayload(
    frontierMetadataByChunkID: [Int: SyntheticOpeningFrontierMetadata]
) -> Data {
    var payload = Data(repeating: 0, count: 0x2E0)
    if frontierMetadataByChunkID.isEmpty == false {
        payload[0x29B] = 0x01
    }

    for index in 0..<5 {
        payload.replaceSubrange((0x2A8 + (index * 4)) ..< (0x2AC + (index * 4)), with: [0xFF, 0xFF, 0xFF, 0xFF])
        payload.replaceSubrange((0x2BC + (index * 4)) ..< (0x2C0 + (index * 4)), with: [0xFF, 0xFF, 0xFF, 0xFF])
    }

    for (chunkID, metadata) in frontierMetadataByChunkID {
        let metadataIndex = chunkID - 1
        guard metadataIndex >= 0 && metadataIndex < 5 else {
            continue
        }
        payload.replaceLittleEndian(metadata.currentToken, at: 0x2A8 + (metadataIndex * 4))
        payload.replaceLittleEndian(metadata.previousToken, at: 0x2BC + (metadataIndex * 4))
        payload[0x2D0 + metadataIndex] = metadata.activeSlot
    }

    return payload
}

private func writeOpeningExtraChunk(
    chunkID: Int,
    copy: SyntheticOpeningExtraChunkCopy,
    saveNumber: UInt32,
    into mirror: inout Data
) {
    let sectorByChunkID: [Int: Int] = [1: 38, 2: 39, 3: 41, 4: 43, 5: 45]
    let payloadSizeByChunkID: [Int: Int] = [1: 0xBA0, 2: 0x1D50, 3: 0x1D50, 4: 0x1D50, 5: 0x1D50]
    guard let sector = sectorByChunkID[chunkID],
          let payloadSize = payloadSizeByChunkID[chunkID] else {
        return
    }

    let start = sector * 0x1000
    let end = start + payloadSize + 16
    guard end <= mirror.count else {
        return
    }

    var payload = Data(repeating: 0, count: payloadSize)
    payload.replaceLittleEndian(copy.token, at: 0)
    mirror.replaceSubrange(start ..< (start + payloadSize), with: payload)

    var footerPrefix = Data()
    footerPrefix.appendLittleEndian(UInt32(0x2006_0623))
    footerPrefix.appendLittleEndian(saveNumber)
    footerPrefix.appendLittleEndian(UInt32(payloadSize))
    footerPrefix.appendLittleEndian(UInt16(chunkID))

    let crc = copy.footerIsValid ? openingTestCRC16(payload + footerPrefix) : 0
    var footer = footerPrefix
    footer.appendLittleEndian(crc)
    if copy.footerIsValid == false {
        footer.replaceLittleEndian(UInt32(0xBAD0_F00D), at: 0)
    }
    mirror.replaceSubrange((start + payloadSize) ..< end, with: footer)
}

private func openingTestCRC16(_ data: Data) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in data {
        crc ^= UInt16(byte) << 8
        for _ in 0 ..< 8 {
            if (crc & 0x8000) != 0 {
                crc = (crc << 1) ^ 0x1021
            } else {
                crc <<= 1
            }
        }
    }
    return crc
}

private extension Data {
    mutating func replaceLittleEndian(_ value: UInt32, at offset: Int) {
        replaceSubrange(offset ..< (offset + 4), with: [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 24),
        ])
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}

private struct ProgramTraceStep: Equatable, Sendable {
    let bundleSceneID: String
    let programSceneID: String?
    let programStateID: String?
    let selectedMenuOptionID: String?
    let visibleMenuOptionIDs: [String]

    init(
        bundleSceneID: String,
        programSceneID: String?,
        programStateID: String?,
        selectedMenuOptionID: String? = nil,
        visibleMenuOptionIDs: [String] = []
    ) {
        self.bundleSceneID = bundleSceneID
        self.programSceneID = programSceneID
        self.programStateID = programStateID
        self.selectedMenuOptionID = selectedMenuOptionID
        self.visibleMenuOptionIDs = visibleMenuOptionIDs
    }
}
