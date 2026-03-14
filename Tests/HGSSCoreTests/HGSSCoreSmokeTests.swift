import Foundation
import Testing
import HGSSCore

struct HGSSCoreSmokeTests {
    @Test("Boots core runtime with stub content")
    func bootsCoreWithStubContent() async throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let runtime = try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubPath)
        #expect(runtime.statusLine.contains("HGSS Stub Content"))
    }
}
