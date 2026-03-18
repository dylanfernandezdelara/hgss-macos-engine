import Foundation
@testable import HGSSExtractCLI
import Testing

struct ClangSourceParserTests {
    @Test("Clang parser summarizes top-level declarations and nested statements")
    func summarizesTopLevelDeclarations() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceFile = root.appendingPathComponent("sample.c", isDirectory: false)
        try Data(
            """
            enum SampleState {
                SAMPLE_INIT,
                SAMPLE_RUN,
            };

            static int kSceneTable[] = { 1, 2, 3 };

            static int SampleMain(int state) {
                switch (state) {
                case SAMPLE_INIT:
                    return 1;
                case SAMPLE_RUN:
                    return 2;
                default:
                    return 0;
                }
            }
            """.utf8
        ).write(to: sourceFile)

        let parser = try ClangSourceParser()
        let translationUnit = try parser.parseChecked(
            sourceFile: sourceFile,
            arguments: ["-fsyntax-only", "-std=c99"]
        )

        #expect(translationUnit.containsTopLevelNode(named: "SampleState", kind: "EnumDecl"))
        #expect(translationUnit.containsTopLevelNode(named: "kSceneTable", kind: "VarDecl"))
        #expect(translationUnit.containsTopLevelNode(named: "SampleMain", kind: "FunctionDecl"))

        let functionNode = try #require(translationUnit.topLevelNodes.first(where: {
            $0.spelling == "SampleMain" && $0.kind == "FunctionDecl"
        }))
        #expect(functionNode.children.contains(where: { $0.kind == "ParmDecl" && $0.spelling == "state" }))
        #expect(functionNode.children.contains(where: { $0.kind == "CompoundStmt" }))
    }

    @Test("Clang parser surfaces diagnostics for malformed sources")
    func capturesDiagnostics() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceFile = root.appendingPathComponent("broken.c", isDirectory: false)
        try Data("int broken( { return 0; }\n".utf8).write(to: sourceFile)

        let parser = try ClangSourceParser()
        let translationUnit = try parser.parse(
            sourceFile: sourceFile,
            arguments: ["-fsyntax-only", "-std=c99"]
        )

        #expect(translationUnit.hasErrorDiagnostics)
        #expect(translationUnit.diagnostics.contains(where: { $0.severity.isError }))
    }

    @Test("Pokeheartgold opening sources parse with generated local support headers")
    func validatesOpeningSources() throws {
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

        #expect(validation.translationUnits.count == PokeheartgoldClangConfiguration.openingSourceRelativePaths.count)

        let introMovie = try #require(validation.translationUnits.first(where: {
            $0.sourceFile.hasSuffix("/src/intro_movie.c")
        }))
        let titleScreen = try #require(validation.translationUnits.first(where: {
            $0.sourceFile.hasSuffix("/src/title_screen.c")
        }))
        let checkSavedata = try #require(validation.translationUnits.first(where: {
            $0.sourceFile.hasSuffix("/src/application/check_savedata.c")
        }))
        let mainMenu = try #require(validation.translationUnits.first(where: {
            $0.sourceFile.hasSuffix("/src/application/main_menu/main_menu.c")
        }))

        #expect(introMovie.containsTopLevelNode(named: "sIntroMovieSceneFuncs", kind: "VarDecl"))
        #expect(introMovie.containsTopLevelNode(named: "IntroMovie_Main", kind: "FunctionDecl"))
        #expect(titleScreen.containsTopLevelNode(named: "TitleScreen_Main", kind: "FunctionDecl"))
        #expect(titleScreen.containsTopLevelNode(named: "TitleScreenMainState", kind: "EnumDecl"))
        #expect(checkSavedata.containsTopLevelNode(named: "CheckSavedataApp_DoMainTask", kind: "FunctionDecl"))
        #expect(checkSavedata.containsTopLevelNode(named: "CheckSavedataApp_MainState", kind: "EnumDecl"))
        #expect(mainMenu.containsTopLevelNode(named: "MainMenuApp_Main", kind: "FunctionDecl"))
        #expect(mainMenu.containsTopLevelNode(named: "sMainMenuButtons", kind: "VarDecl"))
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-clang-parser-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
