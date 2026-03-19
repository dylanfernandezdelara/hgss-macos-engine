import CClangC
import Foundation

struct ClangSourceLocation: Codable, Equatable, Sendable {
    let file: String?
    let line: UInt32
    let column: UInt32
    let offset: UInt32
}

struct ClangSourceRange: Codable, Equatable, Sendable {
    let start: ClangSourceLocation
    let end: ClangSourceLocation
}

struct ClangDiagnostic: Codable, Equatable, Sendable {
    enum Severity: String, Codable, Equatable, Sendable {
        case ignored
        case note
        case warning
        case error
        case fatal

        var isError: Bool {
            self == .error || self == .fatal
        }
    }

    let severity: Severity
    let message: String
    let location: ClangSourceLocation?
}

struct ClangASTNode: Codable, Equatable, Sendable {
    let kind: String
    let spelling: String
    let displayName: String
    let typeSpelling: String?
    let location: ClangSourceLocation?
    let extent: ClangSourceRange?
    let children: [ClangASTNode]
}

struct ClangTranslationUnit: Codable, Equatable, Sendable {
    let sourceFile: String
    let arguments: [String]
    let diagnostics: [ClangDiagnostic]
    let topLevelNodes: [ClangASTNode]

    var hasErrorDiagnostics: Bool {
        diagnostics.contains(where: { $0.severity.isError })
    }

    func containsTopLevelNode(named name: String, kind: String? = nil) -> Bool {
        topLevelNodes.contains { node in
            let matchesName = node.spelling == name || node.displayName == name
            let matchesKind = kind.map { node.kind == $0 } ?? true
            return matchesName && matchesKind
        }
    }
}

enum ClangSourceParserError: Error, LocalizedError {
    case invalidSourceFilePath(String)
    case unableToCreateIndex
    case unableToCreateTranslationUnit(sourceFile: String)
    case translationUnitContainsErrors(sourceFile: String, diagnostics: [ClangDiagnostic])

    var errorDescription: String? {
        switch self {
        case let .invalidSourceFilePath(path):
            return "Unable to represent source file path as a file-system path: \(path)"
        case .unableToCreateIndex:
            return "Unable to create a clang parsing index."
        case let .unableToCreateTranslationUnit(sourceFile):
            return "Unable to create a clang translation unit for \(sourceFile)."
        case let .translationUnitContainsErrors(sourceFile, diagnostics):
            let summary = diagnostics
                .filter { $0.severity.isError }
                .map { diagnostic in
                    if let location = diagnostic.location, let file = location.file {
                        return "\(file):\(location.line):\(location.column): \(diagnostic.message)"
                    }
                    return diagnostic.message
                }
                .joined(separator: "\n")
            return "clang reported parse errors for \(sourceFile):\n\(summary)"
        }
    }
}

final class ClangSourceParser {
    private let index: CXIndex

    init(excludeDeclarationsFromPCH: Bool = true, displayDiagnostics: Bool = false) throws {
        guard let index = clang_createIndex(
            excludeDeclarationsFromPCH ? 1 : 0,
            displayDiagnostics ? 1 : 0
        ) else {
            throw ClangSourceParserError.unableToCreateIndex
        }
        self.index = index
    }

    deinit {
        clang_disposeIndex(index)
    }

    func parse(sourceFile: URL, arguments: [String]) throws -> ClangTranslationUnit {
        let mutableArguments = arguments.map { argument in
            strdup(argument)
        }
        defer {
            for argument in mutableArguments {
                free(argument)
            }
        }

        let constArguments: [UnsafePointer<CChar>?] = mutableArguments.map { argument in
            guard let argument else {
                return Optional<UnsafePointer<CChar>>.none
            }
            return UnsafePointer(argument)
        }

        let translationUnit: CXTranslationUnit? = try sourceFile.withUnsafeFileSystemRepresentation { sourcePath in
            guard let sourcePath else {
                throw ClangSourceParserError.invalidSourceFilePath(sourceFile.path())
            }

            let options = defaultTranslationUnitOptions()
            return constArguments.withUnsafeBufferPointer { buffer in
                clang_parseTranslationUnit(
                    index,
                    sourcePath,
                    buffer.baseAddress,
                    Int32(buffer.count),
                    nil,
                    0,
                    options
                )
            }
        }

        guard let translationUnit else {
            throw ClangSourceParserError.unableToCreateTranslationUnit(sourceFile: sourceFile.path())
        }
        defer {
            clang_disposeTranslationUnit(translationUnit)
        }

        return buildTranslationUnit(
            translationUnit,
            sourceFile: sourceFile.path(),
            arguments: arguments
        )
    }

    func parseChecked(sourceFile: URL, arguments: [String]) throws -> ClangTranslationUnit {
        let translationUnit = try parse(sourceFile: sourceFile, arguments: arguments)
        guard !translationUnit.hasErrorDiagnostics else {
            throw ClangSourceParserError.translationUnitContainsErrors(
                sourceFile: sourceFile.path(),
                diagnostics: translationUnit.diagnostics
            )
        }
        return translationUnit
    }

    private func buildTranslationUnit(
        _ translationUnit: CXTranslationUnit,
        sourceFile: String,
        arguments: [String]
    ) -> ClangTranslationUnit {
        let diagnostics = collectDiagnostics(from: translationUnit)
        let rootCursor = clang_getTranslationUnitCursor(translationUnit)
        let builder = ClangCursorTreeBuilder()
        let topLevelNodes = builder.collectChildren(of: rootCursor)

        return ClangTranslationUnit(
            sourceFile: sourceFile,
            arguments: arguments,
            diagnostics: diagnostics,
            topLevelNodes: topLevelNodes
        )
    }

    private func collectDiagnostics(from translationUnit: CXTranslationUnit) -> [ClangDiagnostic] {
        let diagnosticCount = Int(clang_getNumDiagnostics(translationUnit))
        var diagnostics: [ClangDiagnostic] = []
        diagnostics.reserveCapacity(diagnosticCount)

        for index in 0..<diagnosticCount {
            guard let diagnostic = clang_getDiagnostic(translationUnit, UInt32(index)) else {
                continue
            }
            defer {
                clang_disposeDiagnostic(diagnostic)
            }

            diagnostics.append(
                ClangDiagnostic(
                    severity: diagnosticSeverity(for: clang_getDiagnosticSeverity(diagnostic)),
                    message: string(from: clang_formatDiagnostic(diagnostic, clang_defaultDiagnosticDisplayOptions())),
                    location: sourceLocation(from: clang_getDiagnosticLocation(diagnostic))
                )
            )
        }

        return diagnostics
    }

    private func defaultTranslationUnitOptions() -> UInt32 {
        UInt32(CXTranslationUnit_DetailedPreprocessingRecord.rawValue) |
            UInt32(CXTranslationUnit_KeepGoing.rawValue)
    }

    private func diagnosticSeverity(for severity: CXDiagnosticSeverity) -> ClangDiagnostic.Severity {
        switch severity {
        case CXDiagnostic_Ignored:
            return .ignored
        case CXDiagnostic_Note:
            return .note
        case CXDiagnostic_Warning:
            return .warning
        case CXDiagnostic_Error:
            return .error
        case CXDiagnostic_Fatal:
            return .fatal
        default:
            return .error
        }
    }
}

private final class ClangCursorTreeBuilder {
    func collectChildren(of cursor: CXCursor) -> [ClangASTNode] {
        let collector = ClangNodeCollector(builder: self)
        let collectorPointer = Unmanaged.passRetained(collector).toOpaque()
        clang_visitChildren(cursor, collectClangChildren, collectorPointer)
        return Unmanaged<ClangNodeCollector>.fromOpaque(collectorPointer).takeRetainedValue().nodes
    }

    func makeNode(from cursor: CXCursor) -> ClangASTNode {
        let type = clang_getCursorType(cursor)
        let typeSpelling = string(from: clang_getTypeSpelling(type))
        let normalizedTypeSpelling = typeSpelling.isEmpty ? nil : typeSpelling

        return ClangASTNode(
            kind: string(from: clang_getCursorKindSpelling(clang_getCursorKind(cursor))),
            spelling: string(from: clang_getCursorSpelling(cursor)),
            displayName: string(from: clang_getCursorDisplayName(cursor)),
            typeSpelling: normalizedTypeSpelling,
            location: sourceLocation(from: clang_getCursorLocation(cursor)),
            extent: sourceRange(from: clang_getCursorExtent(cursor)),
            children: collectChildren(of: cursor)
        )
    }
}

private final class ClangNodeCollector {
    let builder: ClangCursorTreeBuilder
    var nodes: [ClangASTNode] = []

    init(builder: ClangCursorTreeBuilder) {
        self.builder = builder
    }
}

private let collectClangChildren: CXCursorVisitor = { cursor, _, clientData in
    guard let clientData else {
        return CXChildVisit_Continue
    }

    if clang_Location_isFromMainFile(clang_getCursorLocation(cursor)) == 0 {
        return CXChildVisit_Continue
    }

    let collector = Unmanaged<ClangNodeCollector>.fromOpaque(clientData).takeUnretainedValue()
    collector.nodes.append(collector.builder.makeNode(from: cursor))
    return CXChildVisit_Continue
}

private func string(from cxString: CXString) -> String {
    defer {
        clang_disposeString(cxString)
    }

    guard let cString = clang_getCString(cxString) else {
        return ""
    }
    return String(cString: cString)
}

private func sourceLocation(from location: CXSourceLocation) -> ClangSourceLocation? {
    var file: CXFile?
    var line: UInt32 = 0
    var column: UInt32 = 0
    var offset: UInt32 = 0
    clang_getExpansionLocation(location, &file, &line, &column, &offset)

    if file == nil && line == 0 && column == 0 && offset == 0 {
        return nil
    }

    let path: String?
    if let file {
        path = string(from: clang_getFileName(file))
    } else {
        path = nil
    }

    return ClangSourceLocation(file: path, line: line, column: column, offset: offset)
}

private func sourceRange(from range: CXSourceRange) -> ClangSourceRange? {
    let start = sourceLocation(from: clang_getRangeStart(range))
    let end = sourceLocation(from: clang_getRangeEnd(range))

    guard let start, let end else {
        return nil
    }

    return ClangSourceRange(start: start, end: end)
}
