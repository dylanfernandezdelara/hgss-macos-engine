import Foundation
import HGSSOpeningIR
@testable import HGSSExtractCLI
import Testing

struct OpeningIRLowererTests {
    @Test("Lowerer derives opening scene ordering and title prompt timing from upstream sources")
    func lowersOpeningProgramIR() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let pretRoot = repoRoot.appendingPathComponent("External/pokeheartgold", isDirectory: true)

        guard FileManager.default.fileExists(atPath: pretRoot.path()) else {
            return
        }

        let supportRoot = try makeTemporaryRoot()
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
        #expect(program.entrySceneID == .scene1)
        #expect(program.sourceFiles == PokeheartgoldClangConfiguration.openingSourceRelativePaths)
        #expect(program.scenes.map(\.id) == [
            .scene1,
            .scene2,
            .scene3,
            .scene4,
            .scene5,
            .titleScreen,
            .deleteSave,
            .micTest,
            .checkSave,
            .mainMenu,
        ])

        let scene1 = try #require(program.scenes.first(where: { $0.id == .scene1 }))
        let scene1State = try #require(scene1.states.first(where: { $0.id == "scene1_run" }))
        #expect(scene1State.transitions.first?.targetSceneID == .scene2)
        #expect(scene1State.transitions.first?.targetStateID == "scene2_run")
        #expect(scene1State.commands.contains(where: { command in
            if case let .setScreenSwap(payload) = command {
                return payload.enabled
            }
            return false
        }))
        #expect(scene1State.commands.contains(where: { command in
            if case let .dispatchAudio(payload) = command {
                return payload.action == .startBGM && payload.cueName == "SEQ_GS_TITLE"
            }
            return false
        }))

        let titleScene = try #require(program.scenes.first(where: { $0.id == .titleScreen }))
        #expect(titleScene.initialStateID == "title_wait_fade")
        #expect(titleScene.states.map(\.id) == [
            "title_wait_fade",
            "title_start_music",
            "title_play_delay",
            "title_play",
            "title_proceed_flash",
            "title_proceed_flash_2",
            "title_proceed_noflash",
            "title_fadeout_menu",
            "title_fadeout_clearsave",
            "title_fadeout_timeout",
            "title_fadeout_mic_test",
        ])

        let titleStartMusic = try #require(titleScene.states.first(where: { $0.id == "title_start_music" }))
        #expect(titleStartMusic.duration == .fixedFrames(1))
        #expect(titleStartMusic.commands.contains(where: { command in
            if case let .dispatchAudio(payload) = command {
                return payload.action == .startBGM && payload.cueName == "SEQ_GS_POKEMON_THEME"
            }
            return false
        }))

        let playDelay = try #require(titleScene.states.first(where: { $0.id == "title_play_delay" }))
        #expect(playDelay.duration == .fixedFrames(30))

        let playState = try #require(titleScene.states.first(where: { $0.id == "title_play" }))
        #expect(playState.duration == .fixedFrames(2341))
        let promptFlash = try #require(playState.commands.compactMap { command -> HGSSOpeningProgramIR.PromptFlashCommand? in
            if case let .setPromptFlash(payload) = command {
                return payload
            }
            return nil
        }.first)
        #expect(promptFlash.visibleFrames == 30)
        #expect(promptFlash.hiddenFrames == 15)
        #expect(promptFlash.screen == .top)
        #expect(promptFlash.rect == .init(x: 0, y: 144, width: 256, height: 16))
        #expect(promptFlash.text == "TOUCH TO START")

        let proceedFlash = try #require(titleScene.states.first(where: { $0.id == "title_proceed_flash" }))
        #expect(proceedFlash.duration == .fixedFrames(5))
        #expect(proceedFlash.transitions.contains(where: {
            $0.targetStateID == "title_proceed_flash_2" && $0.trigger == .stateCompleted
        }))
        #expect(proceedFlash.commands.contains(where: { command in
            if case let .fade(payload) = command {
                return payload.colorHex == "#FFFFFF" && payload.durationFrames == 5
            }
            return false
        }))

        let proceedFlash2 = try #require(titleScene.states.first(where: { $0.id == "title_proceed_flash_2" }))
        #expect(proceedFlash2.duration == .fixedFrames(55))

        let proceedNoFlash = try #require(titleScene.states.first(where: { $0.id == "title_proceed_noflash" }))
        #expect(proceedNoFlash.duration == .fixedFrames(60))

        let menuFadeout = try #require(titleScene.states.first(where: { $0.id == "title_fadeout_menu" }))
        #expect(menuFadeout.duration == .fixedFrames(6))
        #expect(menuFadeout.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetSceneID == .checkSave && $0.targetStateID == "check_save_route"
        }))
        #expect(menuFadeout.commands.contains(where: { command in
            if case let .dispatchAudio(payload) = command {
                return payload.action == .stopBGM && payload.cueName == "SEQ_GS_POKEMON_THEME"
            }
            return false
        }))
        let clearSaveFadeout = try #require(titleScene.states.first(where: { $0.id == "title_fadeout_clearsave" }))
        #expect(clearSaveFadeout.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetSceneID == .deleteSave && $0.targetStateID == "delete_save_handoff"
        }))
        #expect(clearSaveFadeout.commands.contains(where: { command in
            if case .dispatchAudio = command {
                return true
            }
            return false
        }) == false)
        let timeoutFadeout = try #require(titleScene.states.first(where: { $0.id == "title_fadeout_timeout" }))
        #expect(timeoutFadeout.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetSceneID == .scene1 && $0.targetStateID == "scene1_run"
        }))
        let micTestFadeout = try #require(titleScene.states.first(where: { $0.id == "title_fadeout_mic_test" }))
        #expect(micTestFadeout.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetSceneID == .micTest && $0.targetStateID == "mic_test_handoff"
        }))

        let deleteSaveScene = try #require(program.scenes.first(where: { $0.id == .deleteSave }))
        #expect(deleteSaveScene.initialStateID == "delete_save_handoff")
        let micTestScene = try #require(program.scenes.first(where: { $0.id == .micTest }))
        #expect(micTestScene.initialStateID == "mic_test_handoff")

        let checkSaveScene = try #require(program.scenes.first(where: { $0.id == .checkSave }))
        #expect(checkSaveScene.initialStateID == "check_save_route")
        let checkSaveRoute = try #require(checkSaveScene.states.first(where: { $0.id == "check_save_route" }))
        #expect(checkSaveRoute.transitions.contains(where: {
            if case .flagEquals(name: "check_save_status_flags", value: 0) = $0.trigger {
                return $0.targetSceneID == .mainMenu && $0.targetStateID == "main_menu_route"
            }
            return false
        }))
        #expect(checkSaveRoute.transitions.contains(where: {
            if case .flagBitSet(name: "check_save_status_flags", mask: 1 << 1) = $0.trigger {
                return $0.targetStateID == "check_save_prepare_save_erase"
            }
            return false
        }))
        let prepareState = try #require(checkSaveScene.states.first(where: { $0.id == "check_save_prepare_save_erase" }))
        #expect(prepareState.commands.contains(where: { command in
            if case let .mutateFlag(payload) = command {
                return payload.flagName == "check_save_status_flags"
                    && payload.operation == .clearBits
                    && payload.value == ((1 << 1) | (1 << 0))
            }
            return false
        }))
        let messageState = try #require(checkSaveScene.states.first(where: { $0.id == "check_save_message_save_corrupted" }))
        let messageBox = try #require(messageState.commands.compactMap { command -> HGSSOpeningProgramIR.MessageBoxCommand? in
            if case let .setMessageBox(payload) = command {
                return payload
            }
            return nil
        }.first)
        #expect(messageBox.text == "The save file is corrupted.\\nThe previous save file will be loaded.")
        #expect(messageState.transitions.contains(where: {
            if case .flagEquals(name: "program_confirm_requested", value: 1) = $0.trigger {
                return $0.targetStateID == "check_save_fade_out_save_corrupted"
            }
            return false
        }))

        let mainMenuScene = try #require(program.scenes.first(where: { $0.id == .mainMenu }))
        let routeState = try #require(mainMenuScene.states.first(where: { $0.id == "main_menu_route" }))
        #expect(routeState.transitions.contains(where: {
            if case .flagEquals(name: "main_menu_has_save_data", value: 0) = $0.trigger {
                return $0.targetStateID == "main_menu_new_game"
            }
            return false
        }))
        let continueState = try #require(mainMenuScene.states.first(where: { $0.id == "main_menu_continue" }))
        let continueMenu = try #require(continueState.commands.compactMap { command -> HGSSOpeningProgramIR.MenuCommand? in
            if case let .setMenu(payload) = command {
                return payload
            }
            return nil
        }.first)
        #expect(continueMenu.options.map(\.id) == [
            "continue",
            "new_game",
            "pokewalker",
            "mystery_gift",
            "ranger",
            "migrate_ruby",
            "migrate_sapphire",
            "migrate_leafgreen",
            "migrate_firered",
            "migrate_emerald",
            "connect_to_wii",
            "wfc",
            "wii_settings",
        ])
        let mysteryGift = try #require(continueMenu.options.first(where: { $0.id == "mystery_gift" }))
        #expect(mysteryGift.requiredFlags == [
            .init(name: "main_menu_draw_mystery_gift", value: 1),
            .init(name: "main_menu_has_pokedex", value: 1),
        ])
        #expect(mysteryGift.destinationID == "gApp_MainMenu_SelectOption_MysteryGift")
        let migrateRuby = try #require(continueMenu.options.first(where: { $0.id == "migrate_ruby" }))
        #expect(migrateRuby.requiredFlags == [
            .init(name: "main_menu_connected_agb_game", value: 1)
        ])
        #expect(migrateRuby.destinationID == "gApp_MainMenu_SelectOption_MigrateFromAgb")
        let newGameState = try #require(mainMenuScene.states.first(where: { $0.id == "main_menu_new_game" }))
        let menu = try #require(newGameState.commands.compactMap { command -> HGSSOpeningProgramIR.MenuCommand? in
            if case let .setMenu(payload) = command {
                return payload
            }
            return nil
        }.first)
        #expect(menu.options.map(\.text) == ["NEW GAME"])
        #expect(menu.selectedOptionID == "new_game")
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-ir-lowerer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
