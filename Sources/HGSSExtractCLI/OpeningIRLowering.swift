import Foundation
import HGSSOpeningIR

enum OpeningIRLoweringError: Error, LocalizedError {
    case missingTranslationUnit(String)
    case missingTopLevelNode(sourceFile: String, name: String, kind: String)
    case missingCaseNode(String)
    case duplicateCaseNode(String)
    case unsupportedSceneFunction(String)
    case invalidPromptFlashCycle(visibleFrames: Int, cycleFrames: Int)
    case missingPattern(sourceFile: String, description: String)
    case invalidPatternInteger(sourceFile: String, description: String, value: String)
    case unreadableSourceFile(String)

    var errorDescription: String? {
        switch self {
        case let .missingTranslationUnit(suffix):
            return "Missing parsed translation unit for \(suffix)."
        case let .missingTopLevelNode(sourceFile, name, kind):
            return "Missing \(kind) '\(name)' in parsed translation unit \(sourceFile)."
        case let .missingCaseNode(stateName):
            return "Unable to locate switch case for \(stateName) in TitleScreen_Main."
        case let .duplicateCaseNode(stateName):
            return "Encountered duplicate switch cases for \(stateName) in TitleScreen_Main."
        case let .unsupportedSceneFunction(symbol):
            return "Encountered unsupported intro movie scene function \(symbol)."
        case let .invalidPromptFlashCycle(visibleFrames, cycleFrames):
            return "Prompt flash cycle is invalid: visible \(visibleFrames), cycle \(cycleFrames)."
        case let .missingPattern(sourceFile, description):
            return "Unable to derive \(description) from \(sourceFile)."
        case let .invalidPatternInteger(sourceFile, description, value):
            return "Derived malformed integer '\(value)' for \(description) from \(sourceFile)."
        case let .unreadableSourceFile(path):
            return "Unable to read parsed source file \(path)."
        }
    }
}

struct PokeheartgoldOpeningIRLowerer {
    func lower(
        validation: PokeheartgoldOpeningParseValidation,
        pretRoot: URL
    ) throws -> HGSSOpeningProgramIR {
        let context = try OpeningIRLoweringContext(
            translationUnits: validation.translationUnits,
            pretRoot: pretRoot
        )

        let introMovie = try context.translationUnit(matchingSuffix: "/src/intro_movie.c")
        let titleScreen = try context.translationUnit(matchingSuffix: "/src/title_screen.c")

        let introInit = try context.topLevelNode(
            named: "IntroMovie_Init",
            kind: "FunctionDecl",
            in: introMovie
        )
        let introMain = try context.topLevelNode(
            named: "IntroMovie_Main",
            kind: "FunctionDecl",
            in: introMovie
        )
        let introSceneTable = try context.topLevelNode(
            named: "sIntroMovieSceneFuncs",
            kind: "VarDecl",
            in: introMovie
        )

        let titleMain = try context.topLevelNode(
            named: "TitleScreen_Main",
            kind: "FunctionDecl",
            in: titleScreen
        )
        let titleStateEnum = try context.topLevelNode(
            named: "TitleScreenMainState",
            kind: "EnumDecl",
            in: titleScreen
        )
        let titleAnimRun = try context.topLevelNode(
            named: "TitleScreenAnim_Run",
            kind: "FunctionDecl",
            in: titleScreen
        )

        let introScenes = try lowerIntroScenes(
            tableNode: introSceneTable,
            initNode: introInit,
            mainNode: introMain,
            context: context
        )
        let titleScene = try lowerTitleScene(
            mainNode: titleMain,
            stateEnumNode: titleStateEnum,
            animRunNode: titleAnimRun,
            context: context
        )

        let program = HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .scene1,
            sourceFiles: validation.translationUnits.map { context.relativePath(for: $0.sourceFile) },
            scenes: introScenes + [titleScene]
        )
        try program.validate()
        return program
    }

    private func lowerIntroScenes(
        tableNode: ClangASTNode,
        initNode: ClangASTNode,
        mainNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> [HGSSOpeningProgramIR.Scene] {
        let introMovieBGM = try context.requiredMatch(
            #"Sound_SetSceneAndPlayBGM\(\s*[0-9]+\s*,\s*([A-Z0-9_]+)\s*,\s*[0-9]+\s*\)"#,
            in: try context.snippet(for: mainNode),
            sourceFile: context.relativePath(for: mainNode.location?.file ?? tableNode.location?.file ?? "src/intro_movie.c"),
            description: "intro movie BGM cue"
        )

        let sceneRefs = tableNode
            .descendants(kind: "DeclRefExpr")
            .filter { $0.spelling.hasPrefix("IntroMovie_Scene") }

        let orderedScenes = try sceneRefs.map { node -> (id: HGSSOpeningProgramIR.SceneID, provenance: HGSSOpeningProgramIR.Provenance) in
            let sceneID = try sceneID(forSceneFunction: node.spelling)
            return (sceneID, context.provenance(for: node))
        }

        return orderedScenes.enumerated().map { index, entry in
            let stateID = "\(entry.id.rawValue)_run"
            let transitionTarget = index + 1 < orderedScenes.count
                ? (orderedScenes[index + 1].id, "\(orderedScenes[index + 1].id.rawValue)_run")
                : (.titleScreen, "title_wait_fade")

            var commands: [HGSSOpeningProgramIR.Command] = []
            if index == 0 {
                commands.append(
                    .setScreenSwap(
                        .init(
                            enabled: true,
                            provenance: context.provenance(for: initNode, symbolOverride: "IntroMovie_Init")
                        )
                    )
                )
                commands.append(
                    .dispatchAudio(
                        .init(
                            action: .startBGM,
                            cueName: introMovieBGM,
                            provenance: context.provenance(for: mainNode, symbolOverride: "IntroMovie_Main")
                        )
                    )
                )
            }

            return HGSSOpeningProgramIR.Scene(
                id: entry.id,
                initialStateID: stateID,
                states: [
                    .init(
                        id: stateID,
                        duration: .indefinite,
                        commands: commands,
                        transitions: [
                            .init(
                                trigger: .flagEquals(name: "\(entry.id.rawValue)_complete", value: 1),
                                targetSceneID: transitionTarget.0,
                                targetStateID: transitionTarget.1,
                                provenance: context.provenance(for: mainNode, symbolOverride: "IntroMovie_Main")
                            )
                        ],
                        provenance: entry.provenance
                    )
                ],
                provenance: entry.provenance
            )
        }
    }

    private func lowerTitleScene(
        mainNode: ClangASTNode,
        stateEnumNode: ClangASTNode,
        animRunNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.Scene {
        let titleSourceFile = context.relativePath(for: mainNode.location?.file ?? "src/title_screen.c")
        let titleSourceText = try context.fullSourceText(for: mainNode.location?.file ?? "")
        let stateNames = stateEnumNode.children
            .filter { $0.kind == "EnumConstantDecl" }
            .map(\.spelling)
        let caseNodes = try titleCaseNodes(from: mainNode, context: context)
        let initialDelayFrames = try context.requiredInt(
            #"initialDelay\s*=\s*([0-9]+)\s*;"#,
            in: try context.snippet(for: mainNode),
            sourceFile: titleSourceFile,
            description: "title initial delay"
        )
        let titleScreenDuration = try context.requiredInt(
            #"(?m)^#define\s+TITLE_SCREEN_DURATION\s+([0-9]+)\s*$"#,
            in: titleSourceText,
            sourceFile: titleSourceFile,
            description: "title screen duration"
        )
        let promptFlash = try lowerPromptFlash(
            animRunNode: animRunNode,
            titleSourceFile: titleSourceFile,
            titleSourceText: titleSourceText,
            context: context
        )
        let titleBGM = try context.requiredMatch(
            #"Sound_SetSceneAndPlayBGM\(\s*[0-9]+\s*,\s*([A-Z0-9_]+)\s*,\s*[0-9]+\s*\)"#,
            in: try context.snippet(for: mainNode),
            sourceFile: titleSourceFile,
            description: "title BGM cue"
        )
        let playCaseNode = try caseNode(named: "TITLESCREEN_MAIN_PLAY", from: caseNodes)
        let playCaseText = try context.snippet(for: playCaseNode)
        let fadeOutDuration = try context.requiredInt(
            #"BeginNormalPaletteFade\([^\n]*RGB_BLACK,\s*([0-9]+)\s*,\s*1\s*,\s*(?:data->heapID|HEAP_ID_TITLE_SCREEN)\s*\)"#,
            in: playCaseText,
            sourceFile: titleSourceFile,
            description: "title fade-out duration"
        )
        let whiteFlashDuration = try context.requiredInt(
            #"BeginNormalPaletteFade\([^\n]*RGB_WHITE,\s*([0-9]+)\s*,\s*1\s*,\s*HEAP_ID_TITLE_SCREEN\)"#,
            in: playCaseText,
            sourceFile: titleSourceFile,
            description: "title menu white flash duration"
        )
        let bgmFadeDuration = try context.requiredInt(
            #"GF_SndStartFadeOutBGM\(\s*0\s*,\s*([0-9]+)\s*\)"#,
            in: playCaseText,
            sourceFile: titleSourceFile,
            description: "title BGM fade duration"
        )
        let postFlashFadeDuration = max(1, bgmFadeDuration - whiteFlashDuration)

        let states = try stateNames.map { stateName -> HGSSOpeningProgramIR.State in
            let caseNode = try caseNode(named: stateName, from: caseNodes)
            let provenance = context.provenance(for: caseNode, symbolOverride: stateName)
            let hiddenPromptCommand = HGSSOpeningProgramIR.Command.setLayerVisibility(
                .init(layerID: "start_prompt", visible: false, provenance: provenance)
            )

            switch stateName {
            case "TITLESCREEN_MAIN_WAIT_FADE":
                return .init(
                    id: titleStateID(for: stateName),
                    duration: .indefinite,
                    commands: [],
                    transitions: [
                        .init(
                            trigger: .flagEquals(name: "title_anim_initialized", value: 1),
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_START_MUSIC"),
                            provenance: provenance
                        )
                    ],
                    provenance: provenance
                )
            case "TITLESCREEN_MAIN_START_MUSIC":
                return .init(
                    id: titleStateID(for: stateName),
                    duration: .fixedFrames(1),
                    commands: [
                        .dispatchAudio(
                            .init(action: .startBGM, cueName: titleBGM, provenance: provenance)
                        )
                    ],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: "title_play_delay",
                            provenance: provenance
                        )
                    ],
                    provenance: provenance
                )
            case "TITLESCREEN_MAIN_PLAY":
                return .init(
                    id: titleStateID(for: stateName),
                    duration: .fixedFrames(titleScreenDuration + 1),
                    commands: [
                        .setPromptFlash(promptFlash)
                    ],
                    transitions: [
                        .init(
                            trigger: .flagEquals(name: "title_menu_requested", value: 1),
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_FLASH"),
                            provenance: provenance
                        ),
                        .init(
                            trigger: .flagEquals(name: "title_clear_save_requested", value: 1),
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_FADEOUT"),
                            provenance: provenance
                        ),
                        .init(
                            trigger: .flagEquals(name: "title_mic_test_requested", value: 1),
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_FADEOUT"),
                            provenance: provenance
                        ),
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_NOFLASH"),
                            provenance: provenance
                        ),
                    ],
                    provenance: provenance
                )
            case "TITLESCREEN_MAIN_PROCEED_FLASH":
                return .init(
                    id: titleStateID(for: stateName),
                    duration: .fixedFrames(whiteFlashDuration),
                    commands: [
                        hiddenPromptCommand,
                        .fade(
                            .init(
                                target: .palette,
                                startLevel: 0,
                                endLevel: 31,
                                durationFrames: whiteFlashDuration,
                                colorHex: "#FFFFFF",
                                provenance: provenance
                            )
                        )
                    ],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_FLASH_2"),
                            provenance: provenance
                        ),
                    ],
                    provenance: provenance
                )
            case "TITLESCREEN_MAIN_PROCEED_FLASH_2":
                return .init(
                    id: titleStateID(for: stateName),
                    duration: .fixedFrames(postFlashFadeDuration),
                    commands: [hiddenPromptCommand],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_FADEOUT"),
                            provenance: provenance
                        )
                    ],
                    provenance: provenance
                )
            case "TITLESCREEN_MAIN_PROCEED_NOFLASH":
                return .init(
                    id: titleStateID(for: stateName),
                    duration: .fixedFrames(bgmFadeDuration),
                    commands: [hiddenPromptCommand],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: titleStateID(for: "TITLESCREEN_MAIN_FADEOUT"),
                            provenance: provenance
                        )
                    ],
                    provenance: provenance
                )
            case "TITLESCREEN_MAIN_FADEOUT":
                return .init(
                    id: titleStateID(for: stateName),
                    duration: .fixedFrames(fadeOutDuration),
                    commands: [
                        hiddenPromptCommand,
                        .dispatchAudio(
                            .init(action: .stopBGM, cueName: titleBGM, provenance: provenance)
                        ),
                        .fade(
                            .init(
                                target: .palette,
                                startLevel: 0,
                                endLevel: 31,
                                durationFrames: fadeOutDuration,
                                colorHex: "#000000",
                                provenance: provenance
                            )
                        )
                    ],
                    transitions: [],
                    provenance: provenance
                )
            default:
                throw OpeningIRLoweringError.missingCaseNode(stateName)
            }
        }

        let playDelayProvenance = context.provenance(
            for: try caseNode(named: "TITLESCREEN_MAIN_WAIT_FADE", from: caseNodes),
            symbolOverride: "TITLESCREEN_MAIN_WAIT_FADE"
        )
        let playDelayState = HGSSOpeningProgramIR.State(
            id: "title_play_delay",
            duration: .fixedFrames(initialDelayFrames),
            commands: [
                .setLayerVisibility(
                    .init(layerID: "start_prompt", visible: false, provenance: playDelayProvenance)
                )
            ],
            transitions: [
                .init(
                    trigger: .stateCompleted,
                    targetStateID: titleStateID(for: "TITLESCREEN_MAIN_PLAY"),
                    provenance: playDelayProvenance
                )
            ],
            provenance: playDelayProvenance
        )

        let orderedStates = [
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_WAIT_FADE"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_START_MUSIC"), in: states),
            playDelayState,
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PLAY"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_FLASH"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_FLASH_2"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_NOFLASH"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_FADEOUT"), in: states),
        ]

        return HGSSOpeningProgramIR.Scene(
            id: .titleScreen,
            initialStateID: titleStateID(for: "TITLESCREEN_MAIN_WAIT_FADE"),
            states: orderedStates,
            provenance: context.provenance(for: mainNode, symbolOverride: "TitleScreen_Main")
        )
    }

    private func lowerPromptFlash(
        animRunNode: ClangASTNode,
        titleSourceFile: String,
        titleSourceText: String,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.PromptFlashCommand {
        let animRunText = try context.snippet(for: animRunNode)
        let equalityMatches = try context.matchIntegers(
            #"startInstructionFlashTimer\s*==\s*([0-9]+)"#,
            in: animRunText,
            sourceFile: titleSourceFile,
            description: "title prompt flash thresholds"
        )
        let visibleFrames = equalityMatches.max() ?? 0
        let cycleFrames = try context.requiredInt(
            #"startInstructionFlashTimer\s*>=\s*([0-9]+)"#,
            in: animRunText,
            sourceFile: titleSourceFile,
            description: "title prompt flash cycle length"
        )
        guard visibleFrames > 0, cycleFrames > visibleFrames else {
            throw OpeningIRLoweringError.invalidPromptFlashCycle(
                visibleFrames: visibleFrames,
                cycleFrames: cycleFrames
            )
        }
        let promptRect = try titlePromptRect(
            sourceFile: titleSourceFile,
            titleSourceText: titleSourceText,
            context: context
        )
        let promptText = try titlePromptText(context: context)

        return .init(
            targetID: "start_prompt",
            visibleFrames: visibleFrames,
            hiddenFrames: cycleFrames - visibleFrames,
            screen: .top,
            rect: promptRect,
            text: promptText,
            initialPhase: .visible,
            provenance: context.provenance(for: animRunNode, symbolOverride: "TitleScreenAnim_Run")
        )
    }

    private func titlePromptRect(
        sourceFile: String,
        titleSourceText: String,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.ScreenRect {
        let rawFields = try context.requiredMatch(
            #"static\s+const\s+WindowTemplate\s+sTouchToStartWindow\s*=\s*\{\s*[^,]+,\s*([0-9]+\s*,\s*[0-9]+\s*,\s*[0-9]+\s*,\s*[0-9]+)\s*,"#,
            in: titleSourceText,
            sourceFile: sourceFile,
            description: "title prompt window template"
        )
        let values = rawFields
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard values.count == 4,
              let leftTiles = Int(values[0]),
              let topTiles = Int(values[1]),
              let widthTiles = Int(values[2]),
              let heightTiles = Int(values[3]) else {
            throw OpeningIRLoweringError.invalidPatternInteger(
                sourceFile: sourceFile,
                description: "title prompt window template",
                value: rawFields
            )
        }

        return .init(
            x: leftTiles * 8,
            y: topTiles * 8,
            width: widthTiles * 8,
            height: heightTiles * 8
        )
    }

    private func titlePromptText(
        context: OpeningIRLoweringContext
    ) throws -> String {
        let messageURL = context.rootURL
            .appendingPathComponent("files/msgdata/msg/msg_0719.gmm", isDirectory: false)
        let messageText = try String(contentsOf: messageURL, encoding: .utf8)
        let rawPrompt = try context.requiredMatch(
            #"<language\s+name=\"English\">([^<]+)</language>"#,
            in: messageText,
            sourceFile: "files/msgdata/msg/msg_0719.gmm",
            description: "title prompt text"
        )
        return rawPrompt
            .replacingOccurrences(of: "{ALN_CENTER}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func titleCaseNodes(
        from mainNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> [String: ClangASTNode] {
        var caseNodes: [String: ClangASTNode] = [:]
        for caseNode in mainNode.descendants(kind: "CaseStmt") {
            let snippet = try context.snippet(for: caseNode)
            guard let stateName = try context.optionalMatch(
                #"case\s+(TITLESCREEN_MAIN_[A-Z0-9_]+)\s*:"#,
                in: snippet
            ) else {
                continue
            }
            guard caseNodes[stateName] == nil else {
                throw OpeningIRLoweringError.duplicateCaseNode(stateName)
            }
            caseNodes[stateName] = caseNode
        }
        return caseNodes
    }

    private func caseNode(
        named stateName: String,
        from caseNodes: [String: ClangASTNode]
    ) throws -> ClangASTNode {
        guard let node = caseNodes[stateName] else {
            throw OpeningIRLoweringError.missingCaseNode(stateName)
        }
        return node
    }

    private func state(
        named stateID: String,
        in states: [HGSSOpeningProgramIR.State]
    ) throws -> HGSSOpeningProgramIR.State {
        guard let state = states.first(where: { $0.id == stateID }) else {
            throw OpeningIRLoweringError.missingCaseNode(stateID)
        }
        return state
    }

    private func sceneID(forSceneFunction symbol: String) throws -> HGSSOpeningProgramIR.SceneID {
        switch symbol {
        case "IntroMovie_Scene1":
            return .scene1
        case "IntroMovie_Scene2":
            return .scene2
        case "IntroMovie_Scene3":
            return .scene3
        case "IntroMovie_Scene4":
            return .scene4
        case "IntroMovie_Scene5":
            return .scene5
        default:
            throw OpeningIRLoweringError.unsupportedSceneFunction(symbol)
        }
    }

    private func titleStateID(for stateName: String) -> String {
        let trimmed = stateName.replacingOccurrences(of: "TITLESCREEN_MAIN_", with: "")
        return "title_" + trimmed.lowercased()
    }
}

private struct OpeningIRLoweringContext {
    private let translationUnits: [ClangTranslationUnit]
    private let sourceDocuments: [String: OpeningSourceDocument]
    private let pretRoot: URL

    var rootURL: URL {
        pretRoot
    }

    init(
        translationUnits: [ClangTranslationUnit],
        pretRoot: URL
    ) throws {
        self.translationUnits = translationUnits
        self.pretRoot = pretRoot.standardizedFileURL
        var sourceDocuments: [String: OpeningSourceDocument] = [:]
        for translationUnit in translationUnits {
            sourceDocuments[translationUnit.sourceFile] = try OpeningSourceDocument(path: translationUnit.sourceFile)
        }
        self.sourceDocuments = sourceDocuments
    }

    func translationUnit(matchingSuffix suffix: String) throws -> ClangTranslationUnit {
        guard let translationUnit = translationUnits.first(where: { $0.sourceFile.hasSuffix(suffix) }) else {
            throw OpeningIRLoweringError.missingTranslationUnit(suffix)
        }
        return translationUnit
    }

    func topLevelNode(
        named name: String,
        kind: String,
        in translationUnit: ClangTranslationUnit
    ) throws -> ClangASTNode {
        guard let node = translationUnit.topLevelNode(named: name, kind: kind) else {
            throw OpeningIRLoweringError.missingTopLevelNode(
                sourceFile: translationUnit.sourceFile,
                name: name,
                kind: kind
            )
        }
        return node
    }

    func snippet(for node: ClangASTNode) throws -> String {
        guard let file = node.location?.file ?? node.extent?.start.file else {
            throw OpeningIRLoweringError.unreadableSourceFile("<unknown>")
        }
        guard let document = sourceDocuments[file] else {
            throw OpeningIRLoweringError.unreadableSourceFile(file)
        }
        return document.snippet(for: node.extent)
    }

    func fullSourceText(for file: String) throws -> String {
        guard let document = sourceDocuments[file] else {
            throw OpeningIRLoweringError.unreadableSourceFile(file)
        }
        return document.text
    }

    func provenance(
        for node: ClangASTNode,
        symbolOverride: String? = nil
    ) -> HGSSOpeningProgramIR.Provenance {
        let file = node.location?.file ?? node.extent?.start.file ?? ""
        let span: HGSSOpeningProgramIR.SourceLocationSpan?
        if let extent = node.extent {
            span = .init(
                startLine: Int(extent.start.line),
                endLine: Int(extent.end.line),
                startColumn: Int(extent.start.column),
                endColumn: Int(extent.end.column)
            )
        } else if let location = node.location {
            span = .init(
                startLine: Int(location.line),
                endLine: Int(location.line),
                startColumn: Int(location.column),
                endColumn: Int(location.column)
            )
        } else {
            span = nil
        }

        return .init(
            sourceFile: relativePath(for: file),
            symbol: symbolOverride ?? (node.spelling.isEmpty ? nil : node.spelling),
            lineSpan: span
        )
    }

    func relativePath(for absolutePath: String) -> String {
        guard absolutePath.isEmpty == false else {
            return absolutePath
        }
        let normalizedURL = URL(fileURLWithPath: absolutePath).standardizedFileURL
        let normalizedComponents = normalizedURL.pathComponents
        let pretRootComponents = pretRoot.pathComponents
        guard normalizedComponents.starts(with: pretRootComponents) else {
            return normalizedURL.path()
        }
        return normalizedComponents
            .dropFirst(pretRootComponents.count)
            .joined(separator: "/")
    }

    func requiredMatch(
        _ pattern: String,
        in text: String,
        sourceFile: String,
        description: String
    ) throws -> String {
        guard let match = try optionalMatch(pattern, in: text) else {
            throw OpeningIRLoweringError.missingPattern(sourceFile: sourceFile, description: description)
        }
        return match
    }

    func optionalMatch(
        _ pattern: String,
        in text: String
    ) throws -> String? {
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }

    func requiredInt(
        _ pattern: String,
        in text: String,
        sourceFile: String,
        description: String
    ) throws -> Int {
        let rawValue = try requiredMatch(
            pattern,
            in: text,
            sourceFile: sourceFile,
            description: description
        )
        guard let value = Int(rawValue) else {
            throw OpeningIRLoweringError.invalidPatternInteger(
                sourceFile: sourceFile,
                description: description,
                value: rawValue
            )
        }
        return value
    }

    func matchIntegers(
        _ pattern: String,
        in text: String,
        sourceFile: String,
        description: String
    ) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard matches.isEmpty == false else {
            throw OpeningIRLoweringError.missingPattern(sourceFile: sourceFile, description: description)
        }

        return try matches.map { match in
            guard let captureRange = Range(match.range(at: 1), in: text) else {
                throw OpeningIRLoweringError.missingPattern(sourceFile: sourceFile, description: description)
            }
            let rawValue = String(text[captureRange])
            guard let value = Int(rawValue) else {
                throw OpeningIRLoweringError.invalidPatternInteger(
                    sourceFile: sourceFile,
                    description: description,
                    value: rawValue
                )
            }
            return value
        }
    }
}

private struct OpeningSourceDocument {
    let text: String
    private let lines: [String]

    init(path: String) throws {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw OpeningIRLoweringError.unreadableSourceFile(path)
        }
        self.text = text
        self.lines = text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map(String.init)
    }

    func snippet(for range: ClangSourceRange?) -> String {
        guard
            let range,
            range.start.line > 0,
            range.end.line >= range.start.line
        else {
            return text
        }
        let lowerBound = max(Int(range.start.line) - 1, 0)
        let upperBound = min(Int(range.end.line), lines.count)
        guard lowerBound < upperBound else {
            return text
        }
        return lines[lowerBound..<upperBound].joined(separator: "\n")
    }
}

private extension ClangTranslationUnit {
    func topLevelNode(named name: String, kind: String? = nil) -> ClangASTNode? {
        let matches = topLevelNodes.filter { node in
            let matchesName = node.spelling == name || node.displayName == name
            let matchesKind = kind.map { node.kind == $0 } ?? true
            return matchesName && matchesKind
        }
        guard matches.isEmpty == false else {
            return nil
        }
        if kind == "FunctionDecl" {
            return matches.first(where: { $0.children.contains(where: { $0.kind == "CompoundStmt" }) }) ?? matches.last
        }
        return matches.first
    }
}

private extension ClangASTNode {
    func descendants(kind: String) -> [ClangASTNode] {
        var nodes: [ClangASTNode] = []
        for child in children {
            if child.kind == kind {
                nodes.append(child)
            }
            nodes.append(contentsOf: child.descendants(kind: kind))
        }
        return nodes
    }
}
