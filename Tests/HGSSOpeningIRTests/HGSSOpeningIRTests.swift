import Foundation
import HGSSOpeningIR
import Testing

struct HGSSOpeningIRTests {
    @Test("Valid opening IR passes schema validation")
    func validatesWellFormedProgram() throws {
        try makeValidProgram().validate()
    }

    @Test("Opening IR round-trips command-rich programs through JSON")
    func roundTripsCodableProgram() throws {
        let program = try makeValidProgram()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        let data = try encoder.encode(program)
        let decoded = try JSONDecoder().decode(HGSSOpeningProgramIR.self, from: data)

        #expect(decoded == program)
    }

    @Test("Opening IR rejects duplicate scene identifiers")
    func rejectsDuplicateScenes() throws {
        let scene = try makeScene(id: .scene1)
        let program = HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .scene1,
            sourceFiles: ["/tmp/src/intro_movie.c"],
            scenes: [scene, scene]
        )

        do {
            try program.validate()
            Issue.record("Expected duplicate scene id validation to fail.")
        } catch let error as HGSSOpeningIRValidationError {
            #expect(error == .duplicateSceneID(.scene1))
        }
    }

    @Test("Opening IR rejects transitions to missing states")
    func rejectsMissingTransitionTargets() throws {
        let provenance = makeProvenance(file: "/tmp/src/intro_movie_scene_1.c", startLine: 10, endLine: 16)
        let brokenState = HGSSOpeningProgramIR.State(
            id: "scene1_intro",
            duration: .fixedFrames(60),
            commands: [],
            transitions: [
                .init(
                    trigger: .stateCompleted,
                    targetStateID: "missing_state",
                    provenance: provenance
                )
            ],
            provenance: provenance
        )
        let scene = HGSSOpeningProgramIR.Scene(
            id: .scene1,
            initialStateID: "scene1_intro",
            states: [brokenState],
            provenance: provenance
        )
        let program = HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .scene1,
            sourceFiles: ["/tmp/src/intro_movie_scene_1.c"],
            scenes: [scene]
        )

        do {
            try program.validate()
            Issue.record("Expected missing transition target validation to fail.")
        } catch let error as HGSSOpeningIRValidationError {
            #expect(error == .missingTransitionTarget(.scene1, "scene1_intro", "missing_state"))
        }
    }

    @Test("Opening IR rejects invalid prompt flash durations")
    func rejectsInvalidPromptFlashCommand() throws {
        let provenance = makeProvenance(file: "/tmp/src/title_screen.c", startLine: 120, endLine: 134)
        let state = HGSSOpeningProgramIR.State(
            id: "title_idle",
            duration: .indefinite,
            commands: [
                .setPromptFlash(
                    .init(
                        targetID: "start_prompt",
                        visibleFrames: 8,
                        hiddenFrames: 0,
                        initialPhase: .visible,
                        provenance: provenance
                    )
                )
            ],
            transitions: [],
            provenance: provenance
        )
        let scene = HGSSOpeningProgramIR.Scene(
            id: .titleScreen,
            initialStateID: "title_idle",
            states: [state],
            provenance: provenance
        )
        let program = HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .titleScreen,
            sourceFiles: ["/tmp/src/title_screen.c"],
            scenes: [scene]
        )

        do {
            try program.validate()
            Issue.record("Expected prompt flash validation to fail.")
        } catch let error as HGSSOpeningIRValidationError {
            #expect(error == .invalidCommandDuration(.titleScreen, "title_idle", "promptFlash.hidden", 0))
        }
    }

    private func makeValidProgram() throws -> HGSSOpeningProgramIR {
        HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .scene1,
            sourceFiles: [
                "/tmp/src/intro_movie.c",
                "/tmp/src/intro_movie_scene_1.c",
                "/tmp/src/title_screen.c",
            ],
            scenes: [
                try makeScene(id: .scene1),
                makeTitleScene(),
            ]
        )
    }

    private func makeScene(id: HGSSOpeningProgramIR.SceneID) throws -> HGSSOpeningProgramIR.Scene {
        let sceneProvenance = makeProvenance(
            file: "/tmp/src/intro_movie_scene_1.c",
            startLine: 1,
            endLine: 72
        )
        let introStateProvenance = makeProvenance(
            file: "/tmp/src/intro_movie_scene_1.c",
            startLine: 12,
            endLine: 44
        )
        let scrollStateProvenance = makeProvenance(
            file: "/tmp/src/intro_movie_scene_1.c",
            startLine: 45,
            endLine: 72
        )

        return HGSSOpeningProgramIR.Scene(
            id: id,
            initialStateID: "scene1_intro",
            states: [
                .init(
                    id: "scene1_intro",
                    duration: .fixedFrames(90),
                    commands: [
                        .setLayerVisibility(
                            .init(
                                layerID: "scene1_top_bg",
                                visible: true,
                                provenance: introStateProvenance
                            )
                        ),
                        .dispatchAudio(
                            .init(
                                action: .startBGM,
                                cueName: "SEQ_GS_TITLE",
                                provenance: makeProvenance(
                                    file: "/tmp/src/intro_movie.c",
                                    startLine: 88,
                                    endLine: 92
                                )
                            )
                        ),
                    ],
                    transitions: [
                        .init(
                            trigger: .stateCompleted,
                            targetStateID: "scene1_scroll",
                            provenance: introStateProvenance
                        )
                    ],
                    provenance: introStateProvenance
                ),
                .init(
                    id: "scene1_scroll",
                    duration: .fixedFrames(48),
                    commands: [
                        .scroll(
                            .init(
                                targetID: "scene1_top_bg",
                                deltaX: 0,
                                deltaY: -32,
                                durationFrames: 48,
                                provenance: scrollStateProvenance
                            )
                        ),
                        .fade(
                            .init(
                                target: .palette,
                                startLevel: 0,
                                endLevel: 16,
                                durationFrames: 48,
                                provenance: scrollStateProvenance
                            )
                        ),
                    ],
                    transitions: [],
                    provenance: scrollStateProvenance
                ),
            ],
            provenance: sceneProvenance
        )
    }

    private func makeTitleScene() -> HGSSOpeningProgramIR.Scene {
        let provenance = makeProvenance(file: "/tmp/src/title_screen.c", startLine: 100, endLine: 180)
        return HGSSOpeningProgramIR.Scene(
            id: .titleScreen,
            initialStateID: "title_idle",
            states: [
                .init(
                    id: "title_idle",
                    duration: .indefinite,
                    commands: [
                        .setWindowMask(
                            .init(
                                screen: .top,
                                rect: .init(x: 0, y: 0, width: 256, height: 192),
                                provenance: provenance
                            )
                        ),
                        .setBrightness(
                            .init(
                                screen: .top,
                                startLevel: 0,
                                endLevel: 8,
                                durationFrames: 16,
                                provenance: provenance
                            )
                        ),
                        .setScreenSwap(
                            .init(enabled: false, provenance: provenance)
                        ),
                        .setPromptFlash(
                            .init(
                                targetID: "start_prompt",
                                visibleFrames: 30,
                                hiddenFrames: 30,
                                initialPhase: .visible,
                                provenance: provenance
                            )
                        ),
                    ],
                    transitions: [
                        .init(
                            trigger: .flagEquals(name: "title_prompt_enabled", value: 1),
                            targetStateID: "title_idle",
                            provenance: provenance
                        )
                    ],
                    provenance: provenance
                )
            ],
            provenance: provenance
        )
    }

    private func makeProvenance(
        file: String,
        startLine: Int,
        endLine: Int
    ) -> HGSSOpeningProgramIR.Provenance {
        HGSSOpeningProgramIR.Provenance(
            sourceFile: file,
            symbol: nil,
            lineSpan: .init(startLine: startLine, endLine: endLine)
        )
    }
}
