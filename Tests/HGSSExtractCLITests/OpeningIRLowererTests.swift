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
        #expect(scene1.initialStateID == "scene1_run")
        #expect(scene1.states.map(\.id) == [
            "scene1_run",
            "scene1_appear_copyright",
            "scene1_wait_copyright",
            "scene1_wait_fadeout_copyright",
            "scene1_wait_appear_gamefreak",
            "scene1_wait_gamefreak",
            "scene1_appear_bg_image",
            "scene1_wait_start_bg_scroll",
            "scene1_wait_bg_scroll",
            "scene1_wait_appear_bird",
            "scene1_delay90_start_fadeout",
            "scene1_wait_fadeout",
        ])
        #expect(scene1State.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetStateID == "scene1_appear_copyright"
        }))
        #expect(scene1State.transitions.contains(where: {
            if case .flagEquals(name: "scene1_complete", value: 1) = $0.trigger {
                return $0.targetSceneID == .scene2 && $0.targetStateID == "scene2_run"
            }
            return false
        }))
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
        let scene1FadeoutState = try #require(scene1.states.first(where: { $0.id == "scene1_wait_fadeout" }))
        #expect(scene1FadeoutState.commands.contains(where: { command in
            if case let .fade(payload) = command {
                return payload.target == .palette
                    && payload.colorHex == "#FFFFFF"
                    && payload.durationFrames == 65
            }
            return false
        }))
        let scene1ScrollState = try #require(scene1.states.first(where: { $0.id == "scene1_wait_start_bg_scroll" }))
        #expect(scene1ScrollState.commands.contains(where: { command in
            if case let .scroll(payload) = command {
                return payload.targetID == "main_bg1"
                    && payload.deltaY == -0x20
                    && payload.durationFrames == 0xF0
            }
            return false
        }))

        let scene2 = try #require(program.scenes.first(where: { $0.id == .scene2 }))
        #expect(scene2.states.map(\.id) == [
            "scene2_run",
            "scene2_start_flyin",
            "scene2_flyin",
            "scene2_start_slow_pan_ethan",
            "scene2_slow_pan_ethan",
            "scene2_fast_pan_to_lyra",
            "scene2_slow_pan_lyra",
            "scene2_circle_wipe_out",
            "scene2_end",
        ])
        let scene2PanState = try #require(scene2.states.first(where: { $0.id == "scene2_slow_pan_ethan" }))
        #expect(scene2PanState.duration == .fixedFrames(0x5A))
        #expect(scene2PanState.commands.contains(where: { command in
            if case let .scroll(payload) = command {
                return payload.targetID == "scene2_top_main1_layer"
                    && payload.deltaX == 0x20
                    && payload.durationFrames == 0x5A
            }
            return false
        }))
        let scene2CircleState = try #require(scene2.states.first(where: { $0.id == "scene2_end" }))
        #expect(scene2CircleState.commands.contains(where: { command in
            if case let .circleWipe(payload) = command {
                return payload.screen == .top
                    && payload.durationFrames == 8
                    && payload.colorHex == "#FFFFFF"
                    && payload.mode == 1
                    && payload.revealsInside
            }
            return false
        }))

        let scene3 = try #require(program.scenes.first(where: { $0.id == .scene3 }))
        #expect(scene3.states.map(\.id).contains("scene3_wait_admins"))
        let scene3ViewportState = try #require(scene3.states.first(where: { $0.id == "scene3_expand_rocket_viewport" }))
        #expect(scene3ViewportState.duration == .fixedFrames(254))
        #expect(scene3ViewportState.commands.contains(where: { command in
            if case let .animateWindowMask(payload) = command {
                return payload.screen == .bottom
                    && payload.durationFrames == 253
                    && payload.fromRect == .init(x: 0x46, y: 0x40, width: 0x74, height: 0x41)
                    && payload.toRect == .init(x: 0x00, y: 0x00, width: 0x100, height: 0xC1)
            }
            return false
        }))
        #expect(scene3ViewportState.commands.contains(where: { command in
            if case let .scroll(payload) = command {
                return payload.targetID == "scene3_rocket_0_layer"
                    && payload.deltaY == -0x30
                    && payload.durationFrames == 254
            }
            return false
        }))

        let scene4 = try #require(program.scenes.first(where: { $0.id == .scene4 }))
        #expect(scene4.states.map(\.id).contains("scene4_wait_sparkle"))
        let scene4SlideIn = try #require(scene4.states.first(where: { $0.id == "scene4_slide_in_players" }))
        #expect(scene4SlideIn.commands.contains(where: { command in
            if case let .animateWindowMask(payload) = command {
                return payload.screen == .top
                    && payload.durationFrames == 10
                    && payload.fromRect == .init(x: 255, y: 0, width: 1, height: 193)
                    && payload.toRect == .init(x: 0, y: 0, width: 256, height: 193)
            }
            return false
        }))
        let scene4FadeIn = try #require(scene4.states.first(where: { $0.id == "scene4_fade_in" }))
        #expect(scene4FadeIn.commands.contains(where: { command in
            if case let .setScreenSwap(payload) = command {
                return payload.enabled
            }
            return false
        }))
        let scene4GrassParticles = try #require(scene4.states.first(where: { $0.id == "scene4_run_grass_particles" }))
        #expect(scene4GrassParticles.duration == .fixedFrames(53))
        #expect(scene4GrassParticles.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetStateID == "scene4_finish_chikorita"
        }))
        let scene4FireParticles = try #require(scene4.states.first(where: { $0.id == "scene4_run_fire_particles" }))
        #expect(scene4FireParticles.duration == .fixedFrames(44))
        #expect(scene4FireParticles.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetStateID == "scene4_finish_cyndaquil"
        }))
        let scene4WaterParticles = try #require(scene4.states.first(where: { $0.id == "scene4_run_water_particles" }))
        #expect(scene4WaterParticles.duration == .fixedFrames(49))
        #expect(scene4WaterParticles.transitions.contains(where: {
            $0.trigger == .stateCompleted && $0.targetStateID == "scene4_finish_totodile"
        }))
        let scene4WaitSparkle = try #require(scene4.states.first(where: { $0.id == "scene4_wait_sparkle" }))
        #expect(scene4WaitSparkle.duration == .fixedFrames(24))

        let scene5 = try #require(program.scenes.first(where: { $0.id == .scene5 }))
        #expect(scene5.states.map(\.id) == [
            "scene5_run",
            "scene5_wipe_in",
            "scene5_wait_wipe",
            "scene5_begin_bg_scroll",
            "scene5_wait_bg_scroll",
            "scene5_wait_fade_out",
        ])
        let scene5WipeIn = try #require(scene5.states.first(where: { $0.id == "scene5_wipe_in" }))
        #expect(scene5WipeIn.duration == .fixedFrames(18))
        #expect(scene5WipeIn.commands.contains(where: { command in
            if case let .fade(payload) = command {
                return payload.target == .palette
                    && payload.colorHex == "#000000"
                    && payload.durationFrames == 18
            }
            return false
        }))
        let scene5FadeOut = try #require(scene5.states.first(where: { $0.id == "scene5_wait_fade_out" }))
        #expect(scene5FadeOut.duration == .fixedFrames(50))
        #expect(scene5FadeOut.commands.contains(where: { command in
            if case let .fade(payload) = command {
                return payload.target == .palette
                    && payload.colorHex == "#FFFFFF"
                    && payload.durationFrames == 50
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
        #expect(playDelay.commands.contains(where: { command in
            if case let .setPlaneVisibility(payload) = command {
                return payload.screen == .top && payload.planeID == "main_bg3" && payload.visible == false
            }
            return false
        }))
        #expect(playDelay.commands.contains(where: { command in
            if case let .setGlow(payload) = command {
                return payload.screen == .top
                    && payload.colorHex == "#636363"
                    && payload.peakLevel == 60
                    && payload.fadeInFrames == 60
                    && payload.fadeOutFrames == 60
                    && payload.pauseFrames == 21
            }
            return false
        }))

        let playState = try #require(titleScene.states.first(where: { $0.id == "title_play" }))
        #expect(playState.duration == .fixedFrames(2341))
        #expect(playState.commands.contains(where: { command in
            if case let .setPlaneVisibility(payload) = command {
                return payload.screen == .top && payload.planeID == "main_bg3" && payload.visible
            }
            return false
        }))
        #expect(playState.commands.contains(where: { command in
            if case let .setGlow(payload) = command {
                return payload.screen == .top && payload.colorHex == "#636363"
            }
            return false
        }))
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
        #expect(promptFlash.letterSpacing == 1)
        #expect(playState.transitions.contains(where: {
            if case .flagEquals(name: "program_confirm_requested", value: 1) = $0.trigger {
                return $0.targetStateID == "title_proceed_flash"
            }
            return false
        }))

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
        #expect(proceedFlash.commands.contains(where: { command in
            if case let .setPlaneVisibility(payload) = command {
                return payload.screen == .top && payload.planeID == "main_bg3" && payload.visible == false
            }
            return false
        }))
        #expect(proceedFlash.commands.contains(where: { command in
            if case .setGlow = command {
                return true
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
        let dispatch = try #require(newGameState.commands.compactMap { command -> HGSSOpeningProgramIR.DispatchMenuCommand? in
            if case let .dispatchMenu(payload) = command {
                return payload
            }
            return nil
        }.first)
        #expect(dispatch.selectionID == "new_game")
        #expect(dispatch.destinationID == "ov36_App_MainMenu_SelectOption_NewGame")
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-ir-lowerer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
