import Foundation
import Testing
import HGSSContent

struct HGSSContentSmokeTests {
    @Test("Loads checked-in stub manifest")
    func loadsStubManifest() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        let loader = StubContentLoader()
        let manifest = try loader.loadManifest(from: stubPath)

        #expect(manifest.schemaVersion == 1)
        #expect(!manifest.maps.isEmpty)
    }
}
