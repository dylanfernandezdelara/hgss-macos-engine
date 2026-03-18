import Foundation
import HGSSDataModel
import HGSSOpeningIR
@testable import HGSSExtractCLI
import Testing

struct OpeningHeartGoldArtifactWriterTests {
    @Test("Opening artifact writer emits the canonical scene set and local asset refs")
    func emitsCanonicalOpeningOutputs() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let artifacts = try makeArtifacts(in: root)
        try OpeningHeartGoldArtifactWriter().write(
            bundle: artifacts.bundle,
            programIR: artifacts.programIR,
            provenance: artifacts.provenance,
            reference: artifacts.reference,
            report: artifacts.report,
            outputRoot: root
        )

        let bundleURL = root.appendingPathComponent("opening_bundle.json", isDirectory: false)
        let bundleData = try Data(contentsOf: bundleURL)
        let decodedBundle = try JSONDecoder().decode(HGSSOpeningBundle.self, from: bundleData)
        let programIRURL = root.appendingPathComponent("opening_program_ir.json", isDirectory: false)
        let decodedProgramIR = try JSONDecoder().decode(
            HGSSOpeningProgramIR.self,
            from: Data(contentsOf: programIRURL)
        )
        let referenceURL = root.appendingPathComponent("opening_reference.json", isDirectory: false)
        let decodedReference = try JSONDecoder().decode(
            OpeningReferenceDocument.self,
            from: Data(contentsOf: referenceURL)
        )

        #expect(decodedBundle.scenes.map(\.id) == HGSSOpeningBundle.SceneID.allCases)
        try decodedProgramIR.validate()
        for asset in decodedBundle.assets {
            let assetURL = root.appendingPathComponent(asset.relativePath, isDirectory: false)
            #expect(FileManager.default.fileExists(atPath: assetURL.path()))
        }
        #expect(decodedReference.scenes.map(\.sceneID) == HGSSOpeningBundle.SceneID.allCases.map(\.rawValue))
        for trace in decodedReference.audioTraces {
            let traceURL = root.appendingPathComponent(trace.traceRelativePath, isDirectory: false)
            #expect(FileManager.default.fileExists(atPath: traceURL.path()))
        }
    }

    @Test("Opening provenance preserves upstream visual and audio sources without placeholders")
    func preservesOpeningProvenance() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let artifacts = try makeArtifacts(in: root)
        try OpeningHeartGoldArtifactWriter().write(
            bundle: artifacts.bundle,
            programIR: artifacts.programIR,
            provenance: artifacts.provenance,
            reference: artifacts.reference,
            report: artifacts.report,
            outputRoot: root
        )

        let provenanceURL = root.appendingPathComponent("opening_provenance.json", isDirectory: false)
        let provenance = try JSONDecoder().decode(
            OpeningProvenanceDocument.self,
            from: Data(contentsOf: provenanceURL)
        )

        #expect(provenance.sourceFiles.contains(where: { $0.hasSuffix("src/intro_movie.c") }))
        #expect(provenance.sourceFiles.contains(where: { $0.hasSuffix("src/title_screen.c") }))
        #expect(provenance.audioArchive.hasSuffix("files/data/sound/gs_sound_data.sdat"))

        let encodedText = String(decoding: try Data(contentsOf: provenanceURL), as: UTF8.self).lowercased()
        for forbiddenTerm in OpeningHeartGoldArtifactWriter.forbiddenPlaceholderTerms {
            #expect(encodedText.contains(forbiddenTerm) == false)
        }
    }

    @Test("Opening artifact writer is byte-stable across repeated writes")
    func isByteStableAcrossRepeatedWrites() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let artifacts = try makeArtifacts(in: root)
        let writer = OpeningHeartGoldArtifactWriter()

        try writer.write(
            bundle: artifacts.bundle,
            programIR: artifacts.programIR,
            provenance: artifacts.provenance,
            reference: artifacts.reference,
            report: artifacts.report,
            outputRoot: root
        )

        let bundleURL = root.appendingPathComponent("opening_bundle.json", isDirectory: false)
        let programIRURL = root.appendingPathComponent("opening_program_ir.json", isDirectory: false)
        let provenanceURL = root.appendingPathComponent("opening_provenance.json", isDirectory: false)
        let referenceURL = root.appendingPathComponent("opening_reference.json", isDirectory: false)
        let reportURL = root.appendingPathComponent("opening_extract_report.json", isDirectory: false)
        let assetURL = root.appendingPathComponent("assets/scene3/scene3_top.png", isDirectory: false)

        let firstBundleBytes = try Data(contentsOf: bundleURL)
        let firstProgramIRBytes = try Data(contentsOf: programIRURL)
        let firstProvenanceBytes = try Data(contentsOf: provenanceURL)
        let firstReferenceBytes = try Data(contentsOf: referenceURL)
        let firstReportBytes = try Data(contentsOf: reportURL)
        let firstAssetBytes = try Data(contentsOf: assetURL)

        try writer.write(
            bundle: artifacts.bundle,
            programIR: artifacts.programIR,
            provenance: artifacts.provenance,
            reference: artifacts.reference,
            report: artifacts.report,
            outputRoot: root
        )

        #expect(try Data(contentsOf: bundleURL) == firstBundleBytes)
        #expect(try Data(contentsOf: programIRURL) == firstProgramIRBytes)
        #expect(try Data(contentsOf: provenanceURL) == firstProvenanceBytes)
        #expect(try Data(contentsOf: referenceURL) == firstReferenceBytes)
        #expect(try Data(contentsOf: reportURL) == firstReportBytes)
        #expect(try Data(contentsOf: assetURL) == firstAssetBytes)
    }

    @Test("Opening artifact writer rejects placeholder provenance terms")
    func rejectsPlaceholderProvenanceTerms() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        var artifacts = try makeArtifacts(in: root)
        artifacts.provenance = OpeningProvenanceDocument(
            mode: artifacts.provenance.mode,
            canonicalVariant: artifacts.provenance.canonicalVariant,
            pretRoot: artifacts.provenance.pretRoot,
            sourceFiles: artifacts.provenance.sourceFiles,
            assetSources: [
                .init(
                    assetID: "scene1_top",
                    upstreamFiles: [
                        artifacts.provenance.assetSources[0].upstreamFiles[0],
                        "Tests/Fixtures/PretOpening/src/stand-in_scene.c",
                    ]
                )
            ] + Array(artifacts.provenance.assetSources.dropFirst()),
            audioArchive: artifacts.provenance.audioArchive
        )

        do {
            try OpeningHeartGoldArtifactWriter().write(
                bundle: artifacts.bundle,
                programIR: artifacts.programIR,
                provenance: artifacts.provenance,
                reference: artifacts.reference,
                report: artifacts.report,
                outputRoot: root
            )
            Issue.record("Expected placeholder provenance to fail validation.")
        } catch let error as OpeningHeartGoldArtifactError {
            if case let .forbiddenPlaceholder(term, field) = error {
                #expect(term == "stand-in")
                #expect(field.contains("assetSources[scene1_top]"))
            } else {
                Issue.record("Expected forbiddenPlaceholder error, got \(error.localizedDescription).")
            }
        }
    }

    @Test("Opening artifact writer rejects missing reference trace files")
    func rejectsMissingReferenceTraceFiles() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let artifacts = try makeArtifacts(in: root)
        let missingTrace = root.appendingPathComponent("intermediate/audio/scene1/seq_gs_title.json", isDirectory: false)
        try FileManager.default.removeItem(at: missingTrace)

        do {
            try OpeningHeartGoldArtifactWriter().write(
                bundle: artifacts.bundle,
                programIR: artifacts.programIR,
                provenance: artifacts.provenance,
                reference: artifacts.reference,
                report: artifacts.report,
                outputRoot: root
            )
            Issue.record("Expected missing reference trace to fail validation.")
        } catch let error as OpeningHeartGoldArtifactError {
            if case let .missingReferenceFile(path) = error {
                #expect(path.hasSuffix("intermediate/audio/scene1/seq_gs_title.json"))
            } else {
                Issue.record("Expected missingReferenceFile error, got \(error.localizedDescription).")
            }
        }
    }

    private func makeArtifacts(in root: URL) throws -> (
        bundle: HGSSOpeningBundle,
        programIR: HGSSOpeningProgramIR,
        provenance: OpeningProvenanceDocument,
        reference: OpeningReferenceDocument,
        report: OpeningExtractReport
    ) {
        let fixtureRoot = try fixtureRoot()
        let assetPaths = [
            "assets/scene1/scene1_top.png",
            "assets/scene2/scene2_top.png",
            "assets/scene3/scene3_top.png",
            "assets/scene4/scene4_top.png",
            "assets/scene5/scene5_top.png",
            "assets/title_handoff/title_top.png",
            "audio/scene1/seq_gs_title.wav",
            "audio/title_handoff/seq_gs_pokemon_theme.wav",
            "intermediate/audio/scene1/seq_gs_title.json",
            "intermediate/audio/title_handoff/seq_gs_pokemon_theme.json",
        ]
        for path in assetPaths {
            try writeSyntheticAsset(at: root.appendingPathComponent(path, isDirectory: false))
        }

        let sceneAssetIDs = [
            "scene1_top",
            "scene2_top",
            "scene3_top",
            "scene4_top",
            "scene5_top",
            "title_top",
        ]
        let sceneRelativePaths = [
            "assets/scene1/scene1_top.png",
            "assets/scene2/scene2_top.png",
            "assets/scene3/scene3_top.png",
            "assets/scene4/scene4_top.png",
            "assets/scene5/scene5_top.png",
            "assets/title_handoff/title_top.png",
        ]
        let sceneIDs = HGSSOpeningBundle.SceneID.allCases

        let visualSources = [
            fixtureRoot.appendingPathComponent("src/intro_movie_scene_1.c", isDirectory: false).path(),
            fixtureRoot.appendingPathComponent("src/intro_movie_scene_2.c", isDirectory: false).path(),
            fixtureRoot.appendingPathComponent("src/intro_movie_scene_3.c", isDirectory: false).path(),
            fixtureRoot.appendingPathComponent("src/intro_movie_scene_4.c", isDirectory: false).path(),
            fixtureRoot.appendingPathComponent("src/intro_movie_scene_5.c", isDirectory: false).path(),
            fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path(),
        ]

        let bundle = HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: zip(sceneAssetIDs, sceneRelativePaths).enumerated().map { index, pair in
                HGSSOpeningBundle.Asset(
                    id: pair.0,
                    kind: .image,
                    relativePath: pair.1,
                    pixelWidth: 256,
                    pixelHeight: 192,
                    provenance: visualSources[index]
                )
            } + [
                .init(
                    id: "scene1_seq_gs_title_audio",
                    kind: .audioFile,
                    relativePath: "audio/scene1/seq_gs_title.wav",
                    provenance: fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path()
                ),
                .init(
                    id: "title_handoff_seq_gs_pokemon_theme_audio",
                    kind: .audioFile,
                    relativePath: "audio/title_handoff/seq_gs_pokemon_theme.wav",
                    provenance: fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path()
                ),
            ],
            scenes: sceneIDs.enumerated().map { index, sceneID in
                HGSSOpeningBundle.Scene(
                    id: sceneID,
                    durationFrames: sceneID == .titleHandoff ? 1 : 12,
                    skipAllowedFromFrame: sceneID == .scene1 ? 4 : 0,
                    topLayers: [.init(
                        id: "\(sceneID.rawValue)_top_layer",
                        assetID: sceneAssetIDs[index],
                        screenRect: .init(x: 0, y: 0, width: 256, height: 192),
                        zIndex: 1
                    )],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: sceneID == .scene1 ? [
                        .init(
                            id: "scene1_bgm",
                            action: .startBGM,
                            cueName: "SEQ_GS_TITLE",
                            frame: 0,
                            playableAssetID: "scene1_seq_gs_title_audio",
                            provenance: fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path()
                        )
                    ] : sceneID == .titleHandoff ? [
                        .init(
                            id: "title_handoff_bgm",
                            action: .startBGM,
                            cueName: "SEQ_GS_POKEMON_THEME",
                            frame: 0,
                            playableAssetID: "title_handoff_seq_gs_pokemon_theme_audio",
                            provenance: fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path()
                        )
                    ] : []
                )
            }
        )

        let programIR = HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .scene1,
            sourceFiles: [
                fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path(),
                fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path(),
            ],
            scenes: [
                .init(
                    id: .scene1,
                    initialStateID: "scene1_run",
                    states: [
                        .init(
                            id: "scene1_run",
                            duration: .indefinite,
                            commands: [
                                .setScreenSwap(
                                    .init(
                                        enabled: true,
                                        provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path())
                                    )
                                )
                            ],
                            transitions: [
                                .init(
                                    trigger: .flagEquals(name: "scene1_complete", value: 1),
                                    targetSceneID: .titleScreen,
                                    targetStateID: "title_wait_fade",
                                    provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path())
                                )
                            ],
                            provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path())
                        )
                    ],
                    provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path())
                ),
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
                                    targetStateID: "title_play",
                                    provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path())
                                )
                            ],
                            provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path())
                        ),
                        .init(
                            id: "title_play",
                            duration: .fixedFrames(45),
                            commands: [
                                .setPromptFlash(
                                    .init(
                                        targetID: "start_prompt",
                                        visibleFrames: 30,
                                        hiddenFrames: 15,
                                        initialPhase: .visible,
                                        provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path())
                                    )
                                )
                            ],
                            transitions: [],
                            provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path())
                        ),
                    ],
                    provenance: .init(sourceFile: fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path())
                )
            ]
        )

        let provenance = OpeningProvenanceDocument(
            mode: "opening-heartgold",
            canonicalVariant: HGSSOpeningBundle.CanonicalVariant.heartGold.rawValue,
            pretRoot: fixtureRoot.path(),
            sourceFiles: [
                fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path(),
                fixtureRoot.appendingPathComponent("src/intro_movie_scene_1.c", isDirectory: false).path(),
                fixtureRoot.appendingPathComponent("src/intro_movie_scene_2.c", isDirectory: false).path(),
                fixtureRoot.appendingPathComponent("src/intro_movie_scene_3.c", isDirectory: false).path(),
                fixtureRoot.appendingPathComponent("src/intro_movie_scene_4.c", isDirectory: false).path(),
                fixtureRoot.appendingPathComponent("src/intro_movie_scene_5.c", isDirectory: false).path(),
                fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path(),
            ],
            assetSources: zip(sceneAssetIDs, visualSources).map { assetID, source in
                .init(assetID: assetID, upstreamFiles: [source])
            } + [
                .init(
                    assetID: "scene1_seq_gs_title_audio",
                    upstreamFiles: [
                        fixtureRoot.appendingPathComponent("files/data/sound/gs_sound_data.sdat", isDirectory: false).path(),
                        fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path(),
                    ]
                ),
                .init(
                    assetID: "title_handoff_seq_gs_pokemon_theme_audio",
                    upstreamFiles: [
                        fixtureRoot.appendingPathComponent("files/data/sound/gs_sound_data.sdat", isDirectory: false).path(),
                        fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path(),
                    ]
                ),
            ],
            audioArchive: fixtureRoot.appendingPathComponent("files/data/sound/gs_sound_data.sdat", isDirectory: false).path()
        )

        let reference = OpeningReferenceDocument(
            schemaVersion: 1,
            mode: "opening-heartgold",
            canonicalVariant: HGSSOpeningBundle.CanonicalVariant.heartGold.rawValue,
            sourceFiles: provenance.sourceFiles + [provenance.audioArchive],
            scenes: sceneIDs.enumerated().map { index, sceneID in
                .init(
                    sceneID: sceneID.rawValue,
                    durationFrames: sceneID == .titleHandoff ? 1 : 12,
                    skipAllowedFromFrame: sceneID == .scene1 ? 4 : 0,
                    transitionCueIDs: [],
                    audioCueIDs: sceneID == .scene1 ? ["scene1_bgm"] : sceneID == .titleHandoff ? ["title_handoff_bgm"] : []
                )
            },
            audioTraces: [
                .init(
                    cueName: "SEQ_GS_TITLE",
                    sceneID: "scene1",
                    wavRelativePath: "audio/scene1/seq_gs_title.wav",
                    traceRelativePath: "intermediate/audio/scene1/seq_gs_title.json",
                    provenance: [
                        fixtureRoot.appendingPathComponent("files/data/sound/gs_sound_data.sdat", isDirectory: false).path(),
                        fixtureRoot.appendingPathComponent("src/intro_movie.c", isDirectory: false).path(),
                    ]
                ),
                .init(
                    cueName: "SEQ_GS_POKEMON_THEME",
                    sceneID: "title_handoff",
                    wavRelativePath: "audio/title_handoff/seq_gs_pokemon_theme.wav",
                    traceRelativePath: "intermediate/audio/title_handoff/seq_gs_pokemon_theme.json",
                    provenance: [
                        fixtureRoot.appendingPathComponent("files/data/sound/gs_sound_data.sdat", isDirectory: false).path(),
                        fixtureRoot.appendingPathComponent("src/title_screen.c", isDirectory: false).path(),
                    ]
                ),
            ]
        )

        let report = OpeningExtractReport(
            mode: "opening-heartgold",
            canonicalVariant: HGSSOpeningBundle.CanonicalVariant.heartGold.rawValue,
            sceneCount: bundle.scenes.count,
            assetCount: bundle.assets.count,
            audioCueCount: bundle.scenes.flatMap(\.audioCues).count,
            referenceTraceCount: reference.audioTraces.count,
            outputRoot: root.path(),
            pretRoot: fixtureRoot.path()
        )

        return (bundle, programIR, provenance, reference, report)
    }

    private func fixtureRoot() throws -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repositoryRoot.appendingPathComponent("Tests/Fixtures/PretOpening", isDirectory: true)
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-extract-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeSyntheticAsset(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("fixture-\(url.lastPathComponent)".utf8)
        try data.write(to: url)
    }
}
