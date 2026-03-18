import Foundation

enum PokeheartgoldClangSupportError: Error, LocalizedError {
    case unableToResolveSDKRoot
    case missingExpectedTopLevelNode(sourceFile: String, name: String, kind: String)

    var errorDescription: String? {
        switch self {
        case .unableToResolveSDKRoot:
            return "Unable to resolve a macOS SDK path for clang parsing."
        case let .missingExpectedTopLevelNode(sourceFile, name, kind):
            return "clang parsed \(sourceFile) but did not expose expected \(kind) '\(name)'."
        }
    }
}

struct PokeheartgoldClangConfiguration {
    let pretRoot: URL
    let supportRoot: URL
    let sdkRoot: String

    static let openingSourceRelativePaths = [
        "src/intro_movie.c",
        "src/intro_movie_scene_1.c",
        "src/intro_movie_scene_2.c",
        "src/intro_movie_scene_3.c",
        "src/intro_movie_scene_4.c",
        "src/intro_movie_scene_5.c",
        "src/title_screen.c",
    ]

    func openingSourceFiles() -> [URL] {
        Self.openingSourceRelativePaths.map {
            pretRoot.appendingPathComponent($0, isDirectory: false)
        }
    }

    func arguments(for sourceFile: URL) -> [String] {
        [
            "-fsyntax-only",
            "-std=gnu99",
            "-isysroot", sdkRoot,
            "-I", supportRoot.path(),
            "-I", pretRoot.appendingPathComponent("src", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("include", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("include/library", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("files", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("lib/include", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("lib/include/cw", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("lib/include/nitro", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("lib/include/nnsys", isDirectory: true).path(),
            "-I", pretRoot.appendingPathComponent("lib/include/nitro/os", isDirectory: true).path(),
            "-DHEARTGOLD",
            "-DGAME_REMASTER=0",
            "-DENGLISH",
            "-DSDK_ARM9",
            "-DSDK_CW",
            "-DSDK_CODE_ARM",
            "-DSDK_TS",
            "-D_NITRO",
            "-D__arm",
            "-DPM_KEEP_ASSERTS",
            "-DPLATFORM_INTRINSIC_FUNCTION_BIT_CLZ32=__builtin_clz",
            "-Dwchar_t=__WCHAR_TYPE__",
            "-Wno-implicit-int",
            "-Wno-int-conversion",
        ]
    }

    static func resolve(
        pretRoot: URL,
        supportRoot: URL
    ) throws -> PokeheartgoldClangConfiguration {
        try .init(
            pretRoot: pretRoot,
            supportRoot: supportRoot,
            sdkRoot: resolveSDKRoot()
        )
    }
}

struct PokeheartgoldOpeningParseValidation {
    let translationUnits: [ClangTranslationUnit]
}

final class PokeheartgoldParseSupportBuilder {
    func prepare(pretRoot: URL, supportRoot: URL) throws {
        try FileManager.default.createDirectory(at: supportRoot, withIntermediateDirectories: true)

        try generateFXConstHeader(pretRoot: pretRoot, supportRoot: supportRoot)
        try generateNAIXHeader(
            makefileURL: pretRoot.appendingPathComponent("files/demo/opening/gs_opening.mk", isDirectory: false),
            outputURL: supportRoot.appendingPathComponent("demo/opening/gs_opening.naix", isDirectory: false),
            pathPrefix: "files/demo/opening/gs_opening/",
            symbolPrefix: "NARC_gs_opening_"
        )
        try generateNAIXHeader(
            makefileURL: pretRoot.appendingPathComponent("files/demo/title/titledemo.mk", isDirectory: false),
            outputURL: supportRoot.appendingPathComponent("demo/title/titledemo.naix", isDirectory: false),
            pathPrefix: "files/demo/title/titledemo/",
            symbolPrefix: "NARC_titledemo_"
        )
        try generateNAIXHeader(
            makefileURL: pretRoot.appendingPathComponent("files/msgdata/msg.mk", isDirectory: false),
            outputURL: supportRoot.appendingPathComponent("msgdata/msg.naix", isDirectory: false),
            pathPrefix: "files/msgdata/msg/",
            symbolPrefix: "NARC_msg_"
        )
        try generateMessageHeader(
            gmmURL: pretRoot.appendingPathComponent("files/msgdata/msg/msg_0719.gmm", isDirectory: false),
            outputURL: supportRoot.appendingPathComponent("msgdata/msg/msg_0719.h", isDirectory: false)
        )
    }

    private func generateFXConstHeader(pretRoot: URL, supportRoot: URL) throws {
        let generator = pretRoot.appendingPathComponent("tools/gen_fx_consts/gen_fx_consts", isDirectory: false)
        guard FileManager.default.fileExists(atPath: generator.path()) else {
            throw ExtractCLIError.missingTool(path: generator.path())
        }

        let outputURL = supportRoot.appendingPathComponent("nitro/fx/fx_const.h", isDirectory: false)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try runProcess(
            executable: generator,
            arguments: [outputURL.path()],
            commandLabel: "gen_fx_consts"
        )
        try normalizeGeneratedGuard(in: outputURL)
    }

    private func generateNAIXHeader(
        makefileURL: URL,
        outputURL: URL,
        pathPrefix: String,
        symbolPrefix: String
    ) throws {
        let makefile = try String(contentsOf: makefileURL, encoding: .utf8)
        let basenamePrefix = symbolPrefix
            .replacingOccurrences(of: "NARC_", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let relativePaths = extractAssetPaths(
            from: makefile,
            pathPrefix: pathPrefix,
            assetBasenamePrefix: basenamePrefix + "_"
        )
        let symbols = relativePaths.map { path -> String in
            let basename = URL(fileURLWithPath: path, isDirectory: false).lastPathComponent
            let normalized = basename.replacingOccurrences(of: ".", with: "_")
            return symbolPrefix + normalized
        }

        let body = renderHeader(
            outputURL: outputURL,
            lines: [ "enum {" ] +
                symbols.enumerated().map { index, symbol in
                    "    \(symbol) = \(index),"
                } +
                [
                    "};",
                ]
        )

        try writeGeneratedFile(body, to: outputURL)
    }

    private func generateMessageHeader(gmmURL: URL, outputURL: URL) throws {
        let gmm = try String(contentsOf: gmmURL, encoding: .utf8)
        let pattern = #"<row id=\"([A-Za-z0-9_]+)\" index=\"([0-9]+)\">"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(gmm.startIndex..<gmm.endIndex, in: gmm)
        let rows = regex.matches(in: gmm, range: range).compactMap { match -> (name: String, index: Int)? in
            guard
                let nameRange = Range(match.range(at: 1), in: gmm),
                let indexRange = Range(match.range(at: 2), in: gmm),
                let index = Int(gmm[indexRange])
            else {
                return nil
            }

            return (name: String(gmm[nameRange]), index: index)
        }
        .sorted { lhs, rhs in
            lhs.index < rhs.index
        }

        let body = renderHeader(
            outputURL: outputURL,
            lines: [
                "enum {",
            ] +
                rows.map { row in
                    "    \(row.name) = \(row.index),"
                } +
                [
                    "};",
                ]
        )

        try writeGeneratedFile(body, to: outputURL)
    }

    private func extractAssetPaths(
        from makefile: String,
        pathPrefix: String,
        assetBasenamePrefix: String
    ) -> [String] {
        let pattern = #"([A-Za-z0-9_./]+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(makefile.startIndex..<makefile.endIndex, in: makefile)
        let matches = regex?.matches(in: makefile, range: range) ?? []

        var seen = Set<String>()
        var paths: [String] = []
        for match in matches {
            guard let tokenRange = Range(match.range(at: 1), in: makefile) else {
                continue
            }
            let token = String(makefile[tokenRange])
            let basename = URL(fileURLWithPath: token, isDirectory: false).lastPathComponent

            guard
                basename.hasPrefix(assetBasenamePrefix),
                isSupportedNAIXAssetFilename(basename)
            else {
                continue
            }

            let relativePath = token.hasPrefix(pathPrefix) ? token : pathPrefix + basename
            if seen.insert(relativePath).inserted {
                paths.append(relativePath)
            }
        }

        return paths
    }

    private func isSupportedNAIXAssetFilename(_ basename: String) -> Bool {
        let allowedSuffixes = [
            ".NCGR",
            ".NCGR.lz",
            ".NSCR",
            ".NSCR.lz",
            ".NCLR",
            ".NCER",
            ".NCER.lz",
            ".NANR",
            ".NANR.lz",
            ".NSBMD",
            ".NSBCA",
            ".NSBTA",
            ".NSBTP",
            ".NSBMA",
            ".bin",
        ]
        return allowedSuffixes.contains(where: { basename.hasSuffix($0) })
    }

    private func renderHeader(outputURL: URL, lines: [String]) -> String {
        let guardName = outputURL.path()
            .uppercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "_"
            }
            .reduce(into: "") { partialResult, character in
                partialResult.append(character)
            }

        return ([ "#ifndef \(guardName)", "#define \(guardName)", "" ] +
            lines +
            [ "", "#endif", "" ]).joined(separator: "\n")
    }

    private func writeGeneratedFile(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if
            FileManager.default.fileExists(atPath: url.path()),
            let existingContents = try? String(contentsOf: url, encoding: .utf8),
            existingContents == contents
        {
            return
        }

        try Data(contents.utf8).write(to: url, options: .atomic)
    }

    private func normalizeGeneratedGuard(in url: URL) throws {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else {
            return
        }

        func sanitizeGuardLine(_ line: String, directive: String) -> String {
            guard line.hasPrefix(directive + " ") else {
                return line
            }

            let macroName = line.dropFirst(directive.count + 1)
            let sanitizedMacro = macroName.map { character -> Character in
                character.isLetter || character.isNumber || character == "_" ? character : "_"
            }
            return directive + " " + String(sanitizedMacro)
        }

        let normalizedLines = [
            sanitizeGuardLine(lines[0], directive: "#ifndef"),
            sanitizeGuardLine(lines[1], directive: "#define"),
        ] + lines.dropFirst(2)

        try writeGeneratedFile(normalizedLines.joined(separator: "\n"), to: url)
    }
}

struct PokeheartgoldOpeningSourceValidator {
    func validate(
        pretRoot: URL,
        supportRoot: URL
    ) throws -> PokeheartgoldOpeningParseValidation {
        try PokeheartgoldParseSupportBuilder().prepare(pretRoot: pretRoot, supportRoot: supportRoot)
        let configuration = try PokeheartgoldClangConfiguration.resolve(
            pretRoot: pretRoot,
            supportRoot: supportRoot
        )
        let parser = try ClangSourceParser()

        let translationUnits = try configuration.openingSourceFiles().map { sourceFile in
            try parser.parseChecked(
                sourceFile: sourceFile,
                arguments: configuration.arguments(for: sourceFile)
            )
        }

        try requireTopLevelNode(
            named: "sIntroMovieSceneFuncs",
            kind: "VarDecl",
            in: translationUnits,
            matchingSuffix: "/src/intro_movie.c"
        )
        try requireTopLevelNode(
            named: "IntroMovie_Main",
            kind: "FunctionDecl",
            in: translationUnits,
            matchingSuffix: "/src/intro_movie.c"
        )
        try requireTopLevelNode(
            named: "TitleScreen_Main",
            kind: "FunctionDecl",
            in: translationUnits,
            matchingSuffix: "/src/title_screen.c"
        )
        try requireTopLevelNode(
            named: "TitleScreenMainState",
            kind: "EnumDecl",
            in: translationUnits,
            matchingSuffix: "/src/title_screen.c"
        )

        return PokeheartgoldOpeningParseValidation(translationUnits: translationUnits)
    }

    static func defaultSupportRoot(repoRoot: URL) -> URL {
        repoRoot.appendingPathComponent("Content/Local/Tooling/pokeheartgold_parse_support", isDirectory: true)
    }

    private func requireTopLevelNode(
        named name: String,
        kind: String,
        in translationUnits: [ClangTranslationUnit],
        matchingSuffix suffix: String
    ) throws {
        guard let translationUnit = translationUnits.first(where: { $0.sourceFile.hasSuffix(suffix) }) else {
            throw PokeheartgoldClangSupportError.missingExpectedTopLevelNode(
                sourceFile: suffix,
                name: name,
                kind: kind
            )
        }

        guard translationUnit.containsTopLevelNode(named: name, kind: kind) else {
            throw PokeheartgoldClangSupportError.missingExpectedTopLevelNode(
                sourceFile: translationUnit.sourceFile,
                name: name,
                kind: kind
            )
        }
    }
}

private func resolveSDKRoot() throws -> String {
    if let sdkRoot = ProcessInfo.processInfo.environment["SDKROOT"], !sdkRoot.isEmpty {
        return sdkRoot
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun", isDirectory: false)
    process.arguments = ["--show-sdk-path"]

    let stdoutPipe = Pipe()
    process.standardOutput = stdoutPipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw PokeheartgoldClangSupportError.unableToResolveSDKRoot
    }

    let output = String(
        decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
    ).trimmingCharacters(in: .whitespacesAndNewlines)

    guard !output.isEmpty else {
        throw PokeheartgoldClangSupportError.unableToResolveSDKRoot
    }
    return output
}
