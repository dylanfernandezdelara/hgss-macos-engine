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
                controller.requestTitleClearSaveExit()
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
                controller.requestTitleMicTestExit()
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
