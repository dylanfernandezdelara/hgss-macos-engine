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
            return "Unable to locate switch case for \(stateName)."
        case let .duplicateCaseNode(stateName):
            return "Encountered duplicate switch cases for \(stateName)."
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
    private struct IntroSceneDescriptor {
        let id: HGSSOpeningProgramIR.SceneID
        let enumNode: ClangASTNode
        let mainNode: ClangASTNode
    }

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
        let introMovieScene1 = try context.translationUnit(matchingSuffix: "/src/intro_movie_scene_1.c")
        let introMovieScene2 = try context.translationUnit(matchingSuffix: "/src/intro_movie_scene_2.c")
        let introMovieScene3 = try context.translationUnit(matchingSuffix: "/src/intro_movie_scene_3.c")
        let introMovieScene4 = try context.translationUnit(matchingSuffix: "/src/intro_movie_scene_4.c")
        let introMovieScene5 = try context.translationUnit(matchingSuffix: "/src/intro_movie_scene_5.c")
        let checkSavedata = try context.translationUnit(matchingSuffix: "/src/application/check_savedata.c")
        let mainMenu = try context.translationUnit(matchingSuffix: "/src/application/main_menu/main_menu.c")

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
        let titleExit = try context.topLevelNode(
            named: "TitleScreen_Exit",
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
        let titlePromptWindow = try context.topLevelNode(
            named: "sTouchToStartWindow",
            kind: "VarDecl",
            in: titleScreen
        )
        let checkSaveStateEnum = try context.topLevelNode(
            named: "CheckSavedataApp_MainState",
            kind: "EnumDecl",
            in: checkSavedata
        )
        let checkSaveTask = try context.topLevelNode(
            named: "CheckSavedataApp_DoMainTask",
            kind: "FunctionDecl",
            in: checkSavedata
        )
        let mainMenuButtons = try context.topLevelNode(
            named: "sMainMenuButtons",
            kind: "VarDecl",
            in: mainMenu
        )
        let mainMenuMain = try context.topLevelNode(
            named: "MainMenuApp_Main",
            kind: "FunctionDecl",
            in: mainMenu
        )

        let introSceneDescriptors = try [
            IntroSceneDescriptor(
                id: .scene1,
                enumNode: context.topLevelNode(named: "IntroScene1State", kind: "EnumDecl", in: introMovieScene1),
                mainNode: context.topLevelNode(named: "IntroMovie_Scene1_Main", kind: "FunctionDecl", in: introMovieScene1)
            ),
            IntroSceneDescriptor(
                id: .scene2,
                enumNode: context.topLevelNode(named: "IntroScene2State", kind: "EnumDecl", in: introMovieScene2),
                mainNode: context.topLevelNode(named: "IntroMovie_Scene2_Main", kind: "FunctionDecl", in: introMovieScene2)
            ),
            IntroSceneDescriptor(
                id: .scene3,
                enumNode: context.topLevelNode(named: "IntroScene3State", kind: "EnumDecl", in: introMovieScene3),
                mainNode: context.topLevelNode(named: "IntroMovie_Scene3_Main", kind: "FunctionDecl", in: introMovieScene3)
            ),
            IntroSceneDescriptor(
                id: .scene4,
                enumNode: context.topLevelNode(named: "IntroScene4State", kind: "EnumDecl", in: introMovieScene4),
                mainNode: context.topLevelNode(named: "IntroMovie_Scene4_Main", kind: "FunctionDecl", in: introMovieScene4)
            ),
            IntroSceneDescriptor(
                id: .scene5,
                enumNode: context.topLevelNode(named: "IntroScene5State", kind: "EnumDecl", in: introMovieScene5),
                mainNode: context.topLevelNode(named: "IntroMovie_Scene5_Main", kind: "FunctionDecl", in: introMovieScene5)
            ),
        ]

        let introScenes = try lowerIntroScenes(
            tableNode: introSceneTable,
            initNode: introInit,
            mainNode: introMain,
            sceneDescriptors: introSceneDescriptors,
            context: context
        )
        let titleScene = try lowerTitleScene(
            mainNode: titleMain,
            exitNode: titleExit,
            stateEnumNode: titleStateEnum,
            animRunNode: titleAnimRun,
            promptWindowNode: titlePromptWindow,
            context: context
        )
        let deleteSaveScene = lowerTerminalTitleExitScene(
            id: .deleteSave,
            stateID: "delete_save_handoff",
            provenance: context.provenance(for: titleExit, symbolOverride: "TitleScreen_Exit")
        )
        let micTestScene = lowerTerminalTitleExitScene(
            id: .micTest,
            stateID: "mic_test_handoff",
            provenance: context.provenance(for: titleExit, symbolOverride: "TitleScreen_Exit")
        )
        let checkSaveScene = try lowerCheckSaveScene(
            stateEnumNode: checkSaveStateEnum,
            taskNode: checkSaveTask,
            context: context
        )
        let mainMenuScene = try lowerMainMenuScene(
            buttonsNode: mainMenuButtons,
            mainNode: mainMenuMain,
            context: context
        )

        let program = HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .scene1,
            sourceFiles: validation.translationUnits.map { context.relativePath(for: $0.sourceFile) },
            scenes: introScenes + [titleScene, deleteSaveScene, micTestScene, checkSaveScene, mainMenuScene]
        )
        try program.validate()
        return program
    }

    private func lowerIntroScenes(
        tableNode: ClangASTNode,
        initNode: ClangASTNode,
        mainNode: ClangASTNode,
        sceneDescriptors: [IntroSceneDescriptor],
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

        let descriptorsBySceneID = Dictionary(uniqueKeysWithValues: sceneDescriptors.map { ($0.id, $0) })

        return try orderedScenes.enumerated().map { index, entry in
            let stateID = "\(entry.id.rawValue)_run"
            let transitionTarget = index + 1 < orderedScenes.count
                ? (orderedScenes[index + 1].id, "\(orderedScenes[index + 1].id.rawValue)_run")
                : (.titleScreen, "title_wait_fade")

            guard let descriptor = descriptorsBySceneID[entry.id] else {
                throw OpeningIRLoweringError.missingCaseNode(entry.id.rawValue)
            }

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

            let enumStateNames = descriptor.enumNode.children
                .filter { $0.kind == "EnumConstantDecl" }
                .map(\.spelling)
            let caseNodes = try switchCaseNodes(
                from: descriptor.mainNode,
                casePattern: #"INTRO_SCENE[0-9]+_[A-Z0-9_]+"#,
                context: context
            )
            let sceneStates = try enumStateNames.compactMap { stateName -> HGSSOpeningProgramIR.State? in
                guard let caseNode = caseNodes[stateName] else {
                    return nil
                }
                return .init(
                    id: introSceneStateID(for: entry.id, stateName: stateName),
                    duration: .indefinite,
                    commands: [],
                    transitions: [],
                    provenance: context.provenance(for: caseNode, symbolOverride: stateName)
                )
            }

            let firstSceneStateID = sceneStates.first?.id ?? stateID
            let sceneRunState = HGSSOpeningProgramIR.State(
                id: stateID,
                duration: .fixedFrames(1),
                commands: commands,
                transitions: [
                    .init(
                        trigger: .stateCompleted,
                        targetStateID: firstSceneStateID,
                        provenance: entry.provenance
                    ),
                    .init(
                        trigger: .flagEquals(name: "\(entry.id.rawValue)_complete", value: 1),
                        targetSceneID: transitionTarget.0,
                        targetStateID: transitionTarget.1,
                        provenance: context.provenance(for: mainNode, symbolOverride: "IntroMovie_Main")
                    )
                ],
                provenance: entry.provenance
            )

            return HGSSOpeningProgramIR.Scene(
                id: entry.id,
                initialStateID: stateID,
                states: [sceneRunState] + sceneStates,
                provenance: entry.provenance
            )
        }
    }

    private func lowerTitleScene(
        mainNode: ClangASTNode,
        exitNode: ClangASTNode,
        stateEnumNode: ClangASTNode,
        animRunNode: ClangASTNode,
        promptWindowNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.Scene {
        let titleSourceFile = context.relativePath(for: mainNode.location?.file ?? "src/title_screen.c")
        let titleSourceText = try context.fullSourceText(for: mainNode.location?.file ?? "")
        let stateNames = stateEnumNode.children
            .filter { $0.kind == "EnumConstantDecl" }
            .map(\.spelling)
        let caseNodes = try switchCaseNodes(
            from: mainNode,
            casePattern: #"TITLESCREEN_MAIN_[A-Z0-9_]+"#,
            context: context
        )
        let waitFadeCaseNode = try caseNode(named: "TITLESCREEN_MAIN_WAIT_FADE", from: caseNodes)
        let initialDelayFrames = try context.requiredInt(
            #"initialDelay\s*=\s*([0-9]+)\s*;"#,
            in: try context.snippet(for: waitFadeCaseNode),
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
            promptWindowNode: promptWindowNode,
            titleSourceFile: titleSourceFile,
            context: context
        )
        _ = try caseNode(named: "TITLESCREEN_MAIN_START_MUSIC", from: caseNodes)
        let titleBGM = try context.requiredMatch(
            #"Sound_SetSceneAndPlayBGM\(\s*[0-9]+\s*,\s*([A-Z0-9_]+)\s*,\s*[0-9]+\s*\)"#,
            in: try context.snippet(for: mainNode),
            sourceFile: titleSourceFile,
            description: "title BGM cue"
        )
        let playCaseNode = try caseNode(named: "TITLESCREEN_MAIN_PLAY", from: caseNodes)
        let playCaseText = try context.snippet(for: playCaseNode)
        let exitRoutes = try titleExitRoutes(
            from: exitNode,
            context: context
        )
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
                            targetStateID: titleFadeoutStateID(for: "TITLESCREEN_EXIT_CLEARSAVE"),
                            provenance: provenance
                        ),
                        .init(
                            trigger: .flagEquals(name: "title_mic_test_requested", value: 1),
                            targetStateID: titleFadeoutStateID(for: "TITLESCREEN_EXIT_MIC_TEST"),
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
                            targetStateID: titleFadeoutStateID(for: "TITLESCREEN_EXIT_MENU"),
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
                            targetStateID: titleFadeoutStateID(for: "TITLESCREEN_EXIT_TIMEOUT"),
                            provenance: provenance
                        )
                    ],
                    provenance: provenance
                )
            case "TITLESCREEN_MAIN_FADEOUT":
                return try makeTitleFadeoutState(
                    id: titleFadeoutStateID(for: "TITLESCREEN_EXIT_MENU"),
                    includeStopBGM: true,
                    titleBGM: titleBGM,
                    fadeOutDuration: fadeOutDuration,
                    target: route(for: "TITLESCREEN_EXIT_MENU", in: exitRoutes),
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
        let clearSaveFadeout = try makeTitleFadeoutState(
            id: titleFadeoutStateID(for: "TITLESCREEN_EXIT_CLEARSAVE"),
            includeStopBGM: false,
            titleBGM: titleBGM,
            fadeOutDuration: fadeOutDuration,
            target: route(for: "TITLESCREEN_EXIT_CLEARSAVE", in: exitRoutes),
            provenance: context.provenance(for: playCaseNode, symbolOverride: "TITLESCREEN_EXIT_CLEARSAVE")
        )
        let timeoutFadeout = try makeTitleFadeoutState(
            id: titleFadeoutStateID(for: "TITLESCREEN_EXIT_TIMEOUT"),
            includeStopBGM: true,
            titleBGM: titleBGM,
            fadeOutDuration: fadeOutDuration,
            target: route(for: "TITLESCREEN_EXIT_TIMEOUT", in: exitRoutes),
            provenance: context.provenance(for: playCaseNode, symbolOverride: "TITLESCREEN_EXIT_TIMEOUT")
        )
        let micTestFadeout = try makeTitleFadeoutState(
            id: titleFadeoutStateID(for: "TITLESCREEN_EXIT_MIC_TEST"),
            includeStopBGM: false,
            titleBGM: titleBGM,
            fadeOutDuration: fadeOutDuration,
            target: route(for: "TITLESCREEN_EXIT_MIC_TEST", in: exitRoutes),
            provenance: context.provenance(for: playCaseNode, symbolOverride: "TITLESCREEN_EXIT_MIC_TEST")
        )

        let orderedStates = [
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_WAIT_FADE"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_START_MUSIC"), in: states),
            playDelayState,
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PLAY"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_FLASH"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_FLASH_2"), in: states),
            try state(named: titleStateID(for: "TITLESCREEN_MAIN_PROCEED_NOFLASH"), in: states),
            try state(named: titleFadeoutStateID(for: "TITLESCREEN_EXIT_MENU"), in: states),
            clearSaveFadeout,
            timeoutFadeout,
            micTestFadeout,
        ]

        return HGSSOpeningProgramIR.Scene(
            id: .titleScreen,
            initialStateID: titleStateID(for: "TITLESCREEN_MAIN_WAIT_FADE"),
            states: orderedStates,
            provenance: context.provenance(for: mainNode, symbolOverride: "TitleScreen_Main")
        )
    }

    private func lowerCheckSaveScene(
        stateEnumNode: ClangASTNode,
        taskNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.Scene {
        let sourceFile = context.relativePath(for: taskNode.location?.file ?? "src/application/check_savedata.c")
        let sourceText = try context.fullSourceText(for: taskNode.location?.file ?? "")
        let routeProvenance = context.provenance(for: taskNode, symbolOverride: "CheckSavedataApp_DoMainTask")
        let fadeInColor = try context.requiredRGBHex(
            #"BG_SetMaskColor\(\s*GF_BG_LYR_MAIN_0\s*,\s*RGB\(\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*([0-9]+)\s*\)\s*\)"#,
            in: try context.snippet(for: taskNode),
            sourceFile: sourceFile,
            description: "CheckSave fade-in mask color"
        )
        let fadeDuration = try context.requiredInt(
            #"BeginNormalPaletteFade\(\s*0\s*,\s*1\s*,\s*1\s*,\s*RGB_BLACK\s*,\s*([0-9]+)\s*,\s*1\s*,\s*data->heapID\s*\)"#,
            in: try context.snippet(for: taskNode),
            sourceFile: sourceFile,
            description: "CheckSave fade-in duration"
        )
        let rawWindowFields = try context.requiredMatch(
            #"static\s+const\s+WindowTemplate\s+sCheckSave_WindowTemplate\s*=\s*\{\s*[^}]*\.left\s*=\s*([0-9]+\s*,\s*\.top\s*=\s*[0-9]+\s*,\s*\.width\s*=\s*[0-9]+\s*,\s*\.height\s*=\s*[0-9]+)"#,
            in: sourceText,
            sourceFile: sourceFile,
            description: "CheckSave window template"
        )
        let windowValues = rawWindowFields
            .components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
            .compactMap { Int($0) }
        let windowRect = HGSSOpeningProgramIR.ScreenRect(
            x: (windowValues.indices.contains(0) ? windowValues[0] : 2) * 8,
            y: (windowValues.indices.contains(1) ? windowValues[1] : 19) * 8,
            width: (windowValues.indices.contains(2) ? windowValues[2] : 27) * 8,
            height: (windowValues.indices.contains(3) ? windowValues[3] : 4) * 8
        )

        struct CheckSaveMessageRoute {
            let idSuffix: String
            let rowID: String
            let triggerBit: Int
            let clearMask: Int
        }

        let messageRoutes: [CheckSaveMessageRoute] = [
            .init(idSuffix: "save_erase", rowID: "msg_0229_00001", triggerBit: 1 << 1, clearMask: (1 << 1) | (1 << 0)),
            .init(idSuffix: "save_corrupted", rowID: "msg_0229_00000", triggerBit: 1 << 0, clearMask: 1 << 0),
            .init(idSuffix: "battle_hall_erased", rowID: "msg_0229_00005", triggerBit: 1 << 3, clearMask: (1 << 3) | (1 << 2)),
            .init(idSuffix: "battle_hall_corrupted", rowID: "msg_0229_00004", triggerBit: 1 << 2, clearMask: 1 << 2),
            .init(idSuffix: "battle_video_erased", rowID: "msg_0229_00003", triggerBit: 1 << 5, clearMask: (1 << 5) | (1 << 4)),
            .init(idSuffix: "battle_video_corrupted", rowID: "msg_0229_00002", triggerBit: 1 << 4, clearMask: 1 << 4),
        ]

        let routeTransitions = [
            HGSSOpeningProgramIR.Transition(
                trigger: .flagEquals(name: "check_save_status_flags", value: 0),
                targetSceneID: .mainMenu,
                targetStateID: "main_menu_route",
                provenance: routeProvenance
            ),
        ] + messageRoutes.map { entry in
            HGSSOpeningProgramIR.Transition(
                trigger: .flagBitSet(name: "check_save_status_flags", mask: entry.triggerBit),
                targetStateID: "check_save_prepare_\(entry.idSuffix)",
                provenance: routeProvenance
            )
        }

        let messageStates = try messageRoutes.flatMap { entry -> [HGSSOpeningProgramIR.State] in
            let text = try context.messageText(
                relativePath: "files/msgdata/msg/msg_0229.gmm",
                rowID: entry.rowID
            )
            let messageProvenance = HGSSOpeningProgramIR.Provenance(
                sourceFile: "files/msgdata/msg/msg_0229.gmm",
                symbol: entry.rowID
            )
            let prepareStateID = "check_save_prepare_\(entry.idSuffix)"
            let fadeInStateID = "check_save_fade_in_\(entry.idSuffix)"
            let messageStateID = "check_save_message_\(entry.idSuffix)"
            let fadeOutStateID = "check_save_fade_out_\(entry.idSuffix)"

            return [
                .init(
                    id: prepareStateID,
                    duration: .fixedFrames(1),
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: "#000000", provenance: routeProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: "#000000", provenance: routeProvenance)
                        ),
                        .mutateFlag(
                            .init(
                                flagName: "program_confirm_requested",
                                operation: .assign,
                                value: 0,
                                provenance: routeProvenance
                            )
                        ),
                        .mutateFlag(
                            .init(
                                flagName: "check_save_status_flags",
                                operation: .clearBits,
                                value: entry.clearMask,
                                provenance: routeProvenance
                            )
                        ),
                    ],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: fadeInStateID,
                            provenance: routeProvenance
                        )
                    ],
                    provenance: routeProvenance
                ),
                .init(
                    id: fadeInStateID,
                    duration: .fixedFrames(fadeDuration),
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: fadeInColor, provenance: routeProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: fadeInColor, provenance: routeProvenance)
                        ),
                        .fade(
                            .init(
                                target: .palette,
                                startLevel: 31,
                                endLevel: 0,
                                durationFrames: fadeDuration,
                                colorHex: "#000000",
                                provenance: routeProvenance
                            )
                        ),
                    ],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: messageStateID,
                            provenance: routeProvenance
                        )
                    ],
                    provenance: routeProvenance
                ),
                .init(
                    id: messageStateID,
                    duration: .indefinite,
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: fadeInColor, provenance: routeProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: fadeInColor, provenance: routeProvenance)
                        ),
                        .setMessageBox(
                            .init(
                                id: "check_save_message",
                                screen: .top,
                                rect: windowRect,
                                text: text,
                                provenance: messageProvenance
                            )
                        )
                    ],
                    transitions: [
                        .init(
                            trigger: .flagEquals(name: "program_confirm_requested", value: 1),
                            targetStateID: fadeOutStateID,
                            provenance: messageProvenance
                        )
                    ],
                    provenance: messageProvenance
                ),
                .init(
                    id: fadeOutStateID,
                    duration: .fixedFrames(fadeDuration),
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: fadeInColor, provenance: routeProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: fadeInColor, provenance: routeProvenance)
                        ),
                        .setMessageBox(
                            .init(
                                id: "check_save_message",
                                screen: .top,
                                rect: windowRect,
                                text: text,
                                provenance: messageProvenance
                            )
                        ),
                        .mutateFlag(
                            .init(
                                flagName: "program_confirm_requested",
                                operation: .assign,
                                value: 0,
                                provenance: routeProvenance
                            )
                        ),
                        .fade(
                            .init(
                                target: .palette,
                                startLevel: 0,
                                endLevel: 31,
                                durationFrames: fadeDuration,
                                colorHex: "#000000",
                                provenance: routeProvenance
                            )
                        ),
                    ],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: "check_save_route",
                            provenance: routeProvenance
                        )
                    ],
                    provenance: routeProvenance
                ),
            ]
        }

        return HGSSOpeningProgramIR.Scene(
            id: .checkSave,
            initialStateID: "check_save_route",
            states: [
                .init(
                    id: "check_save_route",
                    duration: .indefinite,
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: "#000000", provenance: routeProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: "#000000", provenance: routeProvenance)
                        ),
                        .mutateFlag(
                            .init(
                                flagName: "program_confirm_requested",
                                operation: .assign,
                                value: 0,
                                provenance: routeProvenance
                            )
                        ),
                        .fade(
                            .init(
                                target: .palette,
                                startLevel: 31,
                                endLevel: 0,
                                durationFrames: fadeDuration,
                                colorHex: "#000000",
                                provenance: routeProvenance
                            )
                        )
                    ],
                    transitions: routeTransitions,
                    provenance: routeProvenance
                )
            ] + messageStates,
            provenance: context.provenance(for: stateEnumNode, symbolOverride: "CheckSavedataApp_MainState")
        )
    }

    private func lowerMainMenuScene(
        buttonsNode: ClangASTNode,
        mainNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.Scene {
        let sourceFile = context.relativePath(for: mainNode.location?.file ?? "src/application/main_menu/main_menu.c")
        let sourceText = try context.fullSourceText(for: mainNode.location?.file ?? "")
        let buttonsText = try context.snippet(for: buttonsNode)
        let backgroundColor = try context.requiredRGBHex(
            #"(?m)^#define\s+MAIN_MENU_BACKGROUND_COLOR\s+RGB\(\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*([0-9]+)\s*\)\s*$"#,
            in: sourceText,
            sourceFile: sourceFile,
            description: "MainMenu background color"
        )
        let messageTextByRow: [String: String] = try [
            "msg_0442_00000",
            "msg_0442_00001",
            "msg_0442_00002",
            "msg_0442_00003",
            "msg_0442_00004",
            "msg_0442_00005",
            "msg_0442_00006",
            "msg_0442_00007",
            "msg_0442_00008",
            "msg_0442_00009",
            "msg_0442_00010",
            "msg_0442_00011",
            "msg_0442_00012",
        ].reduce(into: [:]) { result, rowID in
            result[rowID] = try context.messageText(
                relativePath: "files/msgdata/msg/msg_0442.gmm",
                rowID: rowID
            )
        }

        func requires(_ flags: (String, Int)...) -> [HGSSOpeningProgramIR.MenuOption.FlagRequirement] {
            flags.map { name, value in
                .init(name: name, value: value)
            }
        }

        var continueMenuOptions: [HGSSOpeningProgramIR.MenuOption] = []
        continueMenuOptions.append(
            .init(
                id: "continue",
                text: messageTextByRow["msg_0442_00000"] ?? "CONTINUE",
                requiredFlags: requires(("main_menu_has_save_data", 1)),
                destinationID: "ov36_App_MainMenu_SelectOption_Continue"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "new_game",
                text: messageTextByRow["msg_0442_00001"] ?? "NEW GAME",
                destinationID: "ov36_App_MainMenu_SelectOption_NewGame"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "pokewalker",
                text: messageTextByRow["msg_0442_00009"] ?? "POKEWALKER",
                destinationID: "ov112_App_MainMenu_SelectOption_ConnectToPokewalker"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "mystery_gift",
                text: messageTextByRow["msg_0442_00002"] ?? "MYSTERY GIFT",
                requiredFlags: requires(
                    ("main_menu_draw_mystery_gift", 1),
                    ("main_menu_has_pokedex", 1)
                ),
                destinationID: "gApp_MainMenu_SelectOption_MysteryGift"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "ranger",
                text: messageTextByRow["msg_0442_00003"] ?? "CONNECT TO RANGER",
                requiredFlags: requires(
                    ("main_menu_draw_ranger", 1),
                    ("main_menu_has_pokedex", 1)
                ),
                destinationID: "gApp_MainMenu_SelectOption_ConnectToRanger"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "migrate_ruby",
                text: messageTextByRow["msg_0442_00004"] ?? "MIGRATE FROM RUBY",
                requiredFlags: requires(("main_menu_connected_agb_game", 1)),
                destinationID: "gApp_MainMenu_SelectOption_MigrateFromAgb"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "migrate_sapphire",
                text: messageTextByRow["msg_0442_00005"] ?? "MIGRATE FROM SAPPHIRE",
                requiredFlags: requires(("main_menu_connected_agb_game", 2)),
                destinationID: "gApp_MainMenu_SelectOption_MigrateFromAgb"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "migrate_leafgreen",
                text: messageTextByRow["msg_0442_00006"] ?? "MIGRATE FROM LEAFGREEN",
                requiredFlags: requires(("main_menu_connected_agb_game", 3)),
                destinationID: "gApp_MainMenu_SelectOption_MigrateFromAgb"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "migrate_firered",
                text: messageTextByRow["msg_0442_00007"] ?? "MIGRATE FROM FIRERED",
                requiredFlags: requires(("main_menu_connected_agb_game", 4)),
                destinationID: "gApp_MainMenu_SelectOption_MigrateFromAgb"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "migrate_emerald",
                text: messageTextByRow["msg_0442_00008"] ?? "MIGRATE FROM EMERALD",
                requiredFlags: requires(("main_menu_connected_agb_game", 5)),
                destinationID: "gApp_MainMenu_SelectOption_MigrateFromAgb"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "connect_to_wii",
                text: messageTextByRow["msg_0442_00011"] ?? "CONNECT TO Wii",
                requiredFlags: requires(("main_menu_draw_connect_to_wii", 1)),
                destinationID: "sub_02027098:data/eoo.dat"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "wfc",
                text: messageTextByRow["msg_0442_00012"] ?? "NINTENDO WFC SETTINGS",
                destinationID: "gApp_MainMenu_SelectOption_NintendoWFCSetup"
            )
        )
        continueMenuOptions.append(
            .init(
                id: "wii_settings",
                text: messageTextByRow["msg_0442_00010"] ?? "Wii MESSAGE SETTINGS",
                destinationID: "ov75_App_MainMenu_SelectOption_WiiMessageSettings"
            )
        )
        continueMenuOptions = continueMenuOptions.filter { option in
            let appOptionSymbol = mainMenuAppOptionSymbol(for: option.id)
            return buttonsText.contains(appOptionSymbol)
        }
        let newGameOnly = continueMenuOptions.filter { $0.id == "new_game" }
        let menuProvenance = context.provenance(for: mainNode, symbolOverride: "MainMenuApp_Main")

        return HGSSOpeningProgramIR.Scene(
            id: .mainMenu,
            initialStateID: "main_menu_route",
            states: [
                .init(
                    id: "main_menu_route",
                    duration: .indefinite,
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: backgroundColor, provenance: menuProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: backgroundColor, provenance: menuProvenance)
                        )
                    ],
                    transitions: [
                        .init(
                            trigger: .flagEquals(name: "main_menu_has_save_data", value: 1),
                            targetStateID: "main_menu_continue",
                            provenance: menuProvenance
                        ),
                        .init(
                            trigger: .flagEquals(name: "main_menu_has_save_data", value: 0),
                            targetStateID: "main_menu_new_game",
                            provenance: menuProvenance
                        ),
                    ],
                    provenance: menuProvenance
                ),
                .init(
                    id: "main_menu_continue",
                    duration: .indefinite,
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: backgroundColor, provenance: menuProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: backgroundColor, provenance: menuProvenance)
                        ),
                        .setMenu(
                            .init(
                                screen: .bottom,
                                options: continueMenuOptions,
                                selectedOptionID: "continue",
                                provenance: menuProvenance
                            )
                        )
                    ],
                    transitions: [],
                    provenance: menuProvenance
                ),
                .init(
                    id: "main_menu_new_game",
                    duration: .indefinite,
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: backgroundColor, provenance: menuProvenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: backgroundColor, provenance: menuProvenance)
                        ),
                        .setMenu(
                            .init(
                                screen: .bottom,
                                options: newGameOnly,
                                selectedOptionID: "new_game",
                                provenance: menuProvenance
                            )
                        )
                    ],
                    transitions: [],
                    provenance: menuProvenance
                ),
            ],
            provenance: menuProvenance
        )
    }

    private func lowerTerminalTitleExitScene(
        id: HGSSOpeningProgramIR.SceneID,
        stateID: String,
        provenance: HGSSOpeningProgramIR.Provenance
    ) -> HGSSOpeningProgramIR.Scene {
        HGSSOpeningProgramIR.Scene(
            id: id,
            initialStateID: stateID,
            states: [
                .init(
                    id: stateID,
                    duration: .indefinite,
                    commands: [
                        .setSolidFill(
                            .init(screen: .top, colorHex: "#000000", provenance: provenance)
                        ),
                        .setSolidFill(
                            .init(screen: .bottom, colorHex: "#000000", provenance: provenance)
                        )
                    ],
                    transitions: [],
                    provenance: provenance
                )
            ],
            provenance: provenance
        )
    }

    private func mainMenuAppOptionSymbol(
        for optionID: String
    ) -> String {
        switch optionID {
        case "continue":
            return "APPOPTION_CONTINUE"
        case "new_game":
            return "APPOPTION_NEW_GAME"
        case "pokewalker":
            return "APPOPTION_POKEWALKER"
        case "mystery_gift":
            return "APPOPTION_MYSTERY_GIFT"
        case "ranger":
            return "APPOPTION_RANGER"
        case "migrate_ruby", "migrate_sapphire", "migrate_leafgreen", "migrate_firered", "migrate_emerald":
            return "APPOPTION_MIGRATE_AGB"
        case "connect_to_wii":
            return "APPOPTION_CONNECT_TO_WII"
        case "wfc":
            return "APPOPTION_WFC"
        case "wii_settings":
            return "APPOPTION_WII_SETTINGS"
        default:
            return ""
        }
    }

    private func makeTitleFadeoutState(
        id: String,
        includeStopBGM: Bool,
        titleBGM: String,
        fadeOutDuration: Int,
        target: TitleExitRoute,
        provenance: HGSSOpeningProgramIR.Provenance
    ) throws -> HGSSOpeningProgramIR.State {
        var commands: [HGSSOpeningProgramIR.Command] = [
            .setLayerVisibility(
                .init(layerID: "start_prompt", visible: false, provenance: provenance)
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
        ]
        if includeStopBGM {
            commands.insert(
                .dispatchAudio(
                    .init(action: .stopBGM, cueName: titleBGM, provenance: provenance)
                ),
                at: 1
            )
        }

        return .init(
            id: id,
            duration: .fixedFrames(fadeOutDuration),
            commands: commands,
            transitions: [
                .init(
                    trigger: .stateCompleted,
                    targetSceneID: target.sceneID,
                    targetStateID: target.stateID,
                    provenance: provenance
                )
            ],
            provenance: provenance
        )
    }

    private func titleExitRoutes(
        from exitNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> [String: TitleExitRoute] {
        let exitText = try context.snippet(for: exitNode)
        let exitCases = try switchCaseNodes(
            from: exitNode,
            casePattern: #"TITLESCREEN_EXIT_[A-Z0-9_]+"#,
            context: context
        )
        return [
            "TITLESCREEN_EXIT_MENU": try route(
                for: "TITLESCREEN_EXIT_MENU",
                overlaySymbol: "gApplication_CheckSave",
                defaultRoute: .init(sceneID: .checkSave, stateID: "check_save_route"),
                caseNode: try caseNode(named: "TITLESCREEN_EXIT_MENU", from: exitCases),
                exitText: exitText,
                sourceFile: context.relativePath(for: exitNode.location?.file ?? "src/title_screen.c"),
                context: context
            ),
            "TITLESCREEN_EXIT_CLEARSAVE": try route(
                for: "TITLESCREEN_EXIT_CLEARSAVE",
                overlaySymbol: "gApplication_DeleteSave",
                defaultRoute: .init(sceneID: .deleteSave, stateID: "delete_save_handoff"),
                caseNode: try caseNode(named: "TITLESCREEN_EXIT_CLEARSAVE", from: exitCases),
                exitText: exitText,
                sourceFile: context.relativePath(for: exitNode.location?.file ?? "src/title_screen.c"),
                context: context
            ),
            "TITLESCREEN_EXIT_TIMEOUT": try route(
                for: "TITLESCREEN_EXIT_TIMEOUT",
                overlaySymbol: "gApplication_IntroMovie",
                defaultRoute: .init(sceneID: .scene1, stateID: "scene1_run"),
                caseNode: try caseNode(named: "TITLESCREEN_EXIT_TIMEOUT", from: exitCases),
                exitText: exitText,
                sourceFile: context.relativePath(for: exitNode.location?.file ?? "src/title_screen.c"),
                context: context
            ),
            "TITLESCREEN_EXIT_MIC_TEST": try route(
                for: "TITLESCREEN_EXIT_MIC_TEST",
                overlaySymbol: "gApplication_MicTest",
                defaultRoute: .init(sceneID: .micTest, stateID: "mic_test_handoff"),
                caseNode: try caseNode(named: "TITLESCREEN_EXIT_MIC_TEST", from: exitCases),
                exitText: exitText,
                sourceFile: context.relativePath(for: exitNode.location?.file ?? "src/title_screen.c"),
                context: context
            ),
        ]
    }

    private func route(
        for exitMode: String,
        in routes: [String: TitleExitRoute]
    ) throws -> TitleExitRoute {
        guard let route = routes[exitMode] else {
            throw OpeningIRLoweringError.missingCaseNode(exitMode)
        }
        return route
    }

    private func route(
        for exitMode: String,
        overlaySymbol: String,
        defaultRoute: TitleExitRoute,
        caseNode: ClangASTNode,
        exitText: String,
        sourceFile: String,
        context: OpeningIRLoweringContext
    ) throws -> TitleExitRoute {
        _ = caseNode
        guard try context.optionalMatch(
            #"(case\s+\#(exitMode)\s*:[\s\S]*?RegisterMainOverlay\([^\n]*&\#(overlaySymbol)\))"#,
            in: exitText
        ) != nil else {
            throw OpeningIRLoweringError.missingPattern(
                sourceFile: sourceFile,
                description: "\(exitMode) overlay handoff"
            )
        }
        return defaultRoute
    }

    private func lowerPromptFlash(
        animRunNode: ClangASTNode,
        promptWindowNode: ClangASTNode,
        titleSourceFile: String,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.PromptFlashCommand {
        let animCaseNodes = try switchCaseNodes(
            from: animRunNode,
            casePattern: #"TITLESCREEN_ANIM_[A-Z0-9_]+"#,
            context: context
        )
        _ = try caseNode(named: "TITLESCREEN_ANIM_RUN", from: animCaseNodes)
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
            promptWindowNode: promptWindowNode,
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
        promptWindowNode: ClangASTNode,
        context: OpeningIRLoweringContext
    ) throws -> HGSSOpeningProgramIR.ScreenRect {
        let titlePromptWindowText = try context.snippet(for: promptWindowNode)
        let rawFields = try context.requiredMatch(
            #"static\s+const\s+WindowTemplate\s+sTouchToStartWindow\s*=\s*\{\s*[^,]+,\s*([0-9]+\s*,\s*[0-9]+\s*,\s*[0-9]+\s*,\s*[0-9]+)\s*,"#,
            in: titlePromptWindowText,
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

    private func switchCaseNodes(
        from functionNode: ClangASTNode,
        casePattern: String,
        context: OpeningIRLoweringContext
    ) throws -> [String: ClangASTNode] {
        var caseNodes: [String: ClangASTNode] = [:]
        for caseNode in functionNode.descendants(kind: "CaseStmt") {
            let snippet = try context.snippet(for: caseNode)
            guard let stateName = try context.optionalMatch(
                #"case\s+(\#(casePattern))\s*:"#,
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

    private func introSceneStateID(
        for sceneID: HGSSOpeningProgramIR.SceneID,
        stateName: String
    ) -> String {
        let prefix = "INTRO_SCENE\(sceneID.rawValue.replacingOccurrences(of: "scene", with: ""))_"
        let trimmed = stateName.replacingOccurrences(of: prefix, with: "")
        return sceneID.rawValue + "_" + trimmed.lowercased()
    }

    private func titleStateID(for stateName: String) -> String {
        let trimmed = stateName.replacingOccurrences(of: "TITLESCREEN_MAIN_", with: "")
        return "title_" + trimmed.lowercased()
    }

    private func titleFadeoutStateID(for exitMode: String) -> String {
        let trimmed = exitMode.replacingOccurrences(of: "TITLESCREEN_EXIT_", with: "")
        return "title_fadeout_" + trimmed.lowercased()
    }
}

private struct TitleExitRoute {
    let sceneID: HGSSOpeningProgramIR.SceneID
    let stateID: String
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

    func requiredRGBHex(
        _ pattern: String,
        in text: String,
        sourceFile: String,
        description: String
    ) throws -> String {
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            throw OpeningIRLoweringError.missingPattern(sourceFile: sourceFile, description: description)
        }

        let components = try (1...3).map { index -> Int in
            guard let componentRange = Range(match.range(at: index), in: text) else {
                throw OpeningIRLoweringError.missingPattern(sourceFile: sourceFile, description: description)
            }
            let rawValue = String(text[componentRange])
            guard let value = Int(rawValue) else {
                throw OpeningIRLoweringError.invalidPatternInteger(
                    sourceFile: sourceFile,
                    description: description,
                    value: rawValue
                )
            }
            return value
        }

        return rgb5Hex(red: components[0], green: components[1], blue: components[2])
    }

    func messageText(
        relativePath: String,
        rowID: String
    ) throws -> String {
        let fileURL = pretRoot.appendingPathComponent(relativePath, isDirectory: false)
        let sourceFile = relativePath
        let gmmText = try String(contentsOf: fileURL, encoding: .utf8)
        let regex = try NSRegularExpression(
            pattern: #"<row id=\""# + NSRegularExpression.escapedPattern(for: rowID) + #"\"[^>]*>.*?<language name=\"English\">(.*?)</language>"#,
            options: [.dotMatchesLineSeparators]
        )
        let range = NSRange(gmmText.startIndex..<gmmText.endIndex, in: gmmText)
        guard
            let match = regex.firstMatch(in: gmmText, range: range),
            let captureRange = Range(match.range(at: 1), in: gmmText)
        else {
            throw OpeningIRLoweringError.missingPattern(sourceFile: sourceFile, description: "message row \(rowID)")
        }

        return String(gmmText[captureRange])
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func rgb5Hex(red: Int, green: Int, blue: Int) -> String {
        func expand(_ component: Int) -> Int {
            let clamped = max(0, min(component, 31))
            return Int(round((Double(clamped) / 31.0) * 255.0))
        }

        return String(
            format: "#%02X%02X%02X",
            expand(red),
            expand(green),
            expand(blue)
        )
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
