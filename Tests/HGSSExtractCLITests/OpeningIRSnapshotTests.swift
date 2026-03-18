import CryptoKit
import Foundation
import HGSSOpeningIR
@testable import HGSSExtractCLI
import Testing

struct OpeningIRSnapshotTests {
    @Test("Regresses parser-derived opening program IR against committed snapshots")
    func regressesParserDerivedOpeningProgramIRAgainstCommittedSnapshots() throws {
        let pretRoot = repoRootURL().appendingPathComponent("External/pokeheartgold", isDirectory: true)
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

        let expectedDigest = try String(
            contentsOf: fixturesRootURL().appendingPathComponent("opening_program_ir.sha256", isDirectory: false),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let actualDigest = try sha256Hex(of: encoded(program))
        #expect(actualDigest == expectedDigest)

        let expectedSurface = try JSONDecoder().decode(
            OpeningProgramSurfaceSnapshot.self,
            from: Data(contentsOf: fixturesRootURL().appendingPathComponent("opening_program_surface_snapshot.json", isDirectory: false))
        )
        #expect(OpeningProgramSurfaceSnapshot(program: program) == expectedSurface)
    }

    private func encoded(_ program: HGSSOpeningProgramIR) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(program)
    }

    private func sha256Hex(of data: Data) throws -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-ir-snapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func fixturesRootURL() -> URL {
        repoRootURL().appendingPathComponent("Tests/Fixtures/PretOpening", isDirectory: true)
    }

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct OpeningProgramSurfaceSnapshot: Codable, Equatable {
    struct TitlePromptSnapshot: Codable, Equatable {
        let text: String
        let screen: String
        let rect: RectSnapshot
        let visibleFrames: Int
        let hiddenFrames: Int
        let initialPhase: String
    }

    struct RectSnapshot: Codable, Equatable {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    struct TransitionSnapshot: Codable, Equatable {
        let flagName: String
        let flagValue: Int
        let targetSceneID: String?
        let targetStateID: String
    }

    struct CheckSaveRoutingSnapshot: Codable, Equatable {
        let initialStateID: String
        let transitions: [TransitionSnapshot]
        let messageTexts: [String: String]
    }

    struct MenuOptionSnapshot: Codable, Equatable {
        struct FlagRequirementSnapshot: Codable, Equatable {
            let name: String
            let value: Int
        }

        let id: String
        let text: String
        let enabled: Bool
        let requiredFlags: [FlagRequirementSnapshot]
        let destinationID: String?
    }

    struct MenuStateSnapshot: Codable, Equatable {
        let selectedOptionID: String
        let options: [MenuOptionSnapshot]
    }

    struct MainMenuRoutingSnapshot: Codable, Equatable {
        let initialStateID: String
        let transitions: [TransitionSnapshot]
        let options: [String: MenuStateSnapshot]
    }

    let sceneOrder: [String]
    let stateOrder: [String: [String]]
    let titlePrompt: TitlePromptSnapshot
    let checkSaveRouting: CheckSaveRoutingSnapshot
    let mainMenuRouting: MainMenuRoutingSnapshot

    init(program: HGSSOpeningProgramIR) {
        sceneOrder = program.scenes.map(\.id.rawValue)
        stateOrder = program.scenes.reduce(into: [:]) { result, scene in
            if [.titleScreen, .checkSave, .mainMenu].contains(scene.id) {
                result[scene.id.rawValue] = scene.states.map(\.id)
            }
        }

        let titleScene = program.scenes.first(where: { $0.id == .titleScreen })!
        let titlePlayState = titleScene.states.first(where: { $0.id == "title_play" })!
        let prompt = titlePlayState.commands.compactMap { command -> HGSSOpeningProgramIR.PromptFlashCommand? in
            if case let .setPromptFlash(payload) = command {
                return payload
            }
            return nil
        }.first!
        titlePrompt = TitlePromptSnapshot(
            text: prompt.text!,
            screen: prompt.screen!.rawValue,
            rect: RectSnapshot(
                x: prompt.rect!.x,
                y: prompt.rect!.y,
                width: prompt.rect!.width,
                height: prompt.rect!.height
            ),
            visibleFrames: prompt.visibleFrames,
            hiddenFrames: prompt.hiddenFrames,
            initialPhase: prompt.initialPhase.rawValue
        )

        let checkSaveScene = program.scenes.first(where: { $0.id == .checkSave })!
        let checkSaveRoute = checkSaveScene.states.first(where: { $0.id == "check_save_route" })!
        let messageTexts = Dictionary(
            uniqueKeysWithValues: checkSaveScene.states
                .filter { $0.id.hasPrefix("check_save_message_") }
                .map { state in
                    let message = state.commands.compactMap { command -> HGSSOpeningProgramIR.MessageBoxCommand? in
                        if case let .setMessageBox(payload) = command {
                            return payload
                        }
                        return nil
                    }.first!
                    return (state.id, message.text)
                }
        )
        checkSaveRouting = CheckSaveRoutingSnapshot(
            initialStateID: checkSaveScene.initialStateID,
            transitions: checkSaveRoute.transitions.map(TransitionSnapshot.init),
            messageTexts: messageTexts
        )

        let mainMenuScene = program.scenes.first(where: { $0.id == .mainMenu })!
        let mainMenuRoute = mainMenuScene.states.first(where: { $0.id == "main_menu_route" })!
        let options = Dictionary(
            uniqueKeysWithValues: mainMenuScene.states
                .filter { $0.id.hasPrefix("main_menu_") && $0.id != "main_menu_route" }
                .map { state in
                    let menu = state.commands.compactMap { command -> HGSSOpeningProgramIR.MenuCommand? in
                        if case let .setMenu(payload) = command {
                            return payload
                        }
                        return nil
                    }.first!
                    return (
                        state.id,
                        MenuStateSnapshot(
                            selectedOptionID: menu.selectedOptionID,
                            options: menu.options.map { option in
                                MenuOptionSnapshot(
                                    id: option.id,
                                    text: option.text,
                                    enabled: option.enabled,
                                    requiredFlags: option.requiredFlags.map {
                                        .init(name: $0.name, value: $0.value)
                                    },
                                    destinationID: option.destinationID
                                )
                            }
                        )
                    )
                }
        )
        mainMenuRouting = MainMenuRoutingSnapshot(
            initialStateID: mainMenuScene.initialStateID,
            transitions: mainMenuRoute.transitions.map(TransitionSnapshot.init),
            options: options
        )
    }
}

private extension OpeningProgramSurfaceSnapshot.TransitionSnapshot {
    init(_ transition: HGSSOpeningProgramIR.Transition) {
        switch transition.trigger {
        case let .flagEquals(name, value):
            flagName = name
            flagValue = value
        case .stateCompleted, .frameEquals, .frameAtLeast:
            fatalError("Unexpected non-flag trigger in routing snapshot.")
        }
        targetSceneID = transition.targetSceneID?.rawValue
        targetStateID = transition.targetStateID
    }
}
