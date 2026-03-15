import Foundation
import XCTest
import HGSSExtractSupport
import HGSSDataModel

final class HGSSExtractCLITests: XCTestCase {
    func testDefaultsToCommittedPretFixtures() throws {
        let repoRoot = repoRootURL()
        let config = ExtractConfiguration(
            input: repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true),
            output: repoRoot.appendingPathComponent("Content/Local/TestExtract", isDirectory: true),
            pretRoot: nil,
            dryRun: true
        )

        let result = try extractManifest(config: config, workingDirectory: repoRoot)

        XCTAssertEqual(result.mode, "pret-fixture-new-bark")
        XCTAssertEqual(
            result.upstreamRoot.resolvingSymlinksInPath(),
            fixturesRootURL().resolvingSymlinksInPath()
        )
        XCTAssertEqual(result.manifest, try expectedGeneratedManifest())
    }

    func testPrefersProvidedPretRoot() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
        }

        let mapHeadersURL = tempRoot.appendingPathComponent("src/data", isDirectory: true)
        let zoneEventURL = tempRoot.appendingPathComponent(
            "files/fielddata/eventdata/zone_event",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: mapHeadersURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: zoneEventURL, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: fixturesRootURL().appendingPathComponent("map_headers_new_bark.h", isDirectory: false),
            to: mapHeadersURL.appendingPathComponent("map_headers.h", isDirectory: false)
        )
        try FileManager.default.copyItem(
            at: fixturesRootURL().appendingPathComponent("057_T20.json", isDirectory: false),
            to: zoneEventURL.appendingPathComponent("057_T20.json", isDirectory: false)
        )

        let repoRoot = repoRootURL()
        let config = ExtractConfiguration(
            input: repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true),
            output: repoRoot.appendingPathComponent("Content/Local/TestExtract", isDirectory: true),
            pretRoot: tempRoot,
            dryRun: true
        )

        let result = try extractManifest(config: config, workingDirectory: repoRoot)

        XCTAssertEqual(result.mode, "pret-new-bark")
        XCTAssertEqual(result.upstreamRoot, tempRoot)
        XCTAssertEqual(result.manifest, try expectedGeneratedManifest())
    }

    private func expectedGeneratedManifest() throws -> HGSSManifest {
        let data = try Data(contentsOf: fixturesRootURL().appendingPathComponent("generated_new_bark_manifest.json"))
        return try JSONDecoder().decode(HGSSManifest.self, from: data)
    }

    private func fixturesRootURL() -> URL {
        repoRootURL().appendingPathComponent("Tests/Fixtures/PretNewBark", isDirectory: true)
    }

    private func repoRootURL() -> URL {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
