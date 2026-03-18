import Foundation
import Testing

struct OpeningReferenceDiffTests {
    @Test("Reference diff fails when rendered wav bytes drift")
    func failsOnWavMismatch() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-reference-diff-\(UUID().uuidString)", isDirectory: true)
        let expectedRoot = root.appendingPathComponent("expected", isDirectory: true)
        let actualRoot = root.appendingPathComponent("actual", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: expectedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: actualRoot, withIntermediateDirectories: true)

        try writeReferenceArtifacts(root: expectedRoot, wavBytes: Data([0x52, 0x49, 0x46, 0x46, 0x00]))
        try writeReferenceArtifacts(root: actualRoot, wavBytes: Data([0x52, 0x49, 0x46, 0x46, 0x01]))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3", isDirectory: false)
        let scriptURL = URL(fileURLWithPath: #filePath, isDirectory: false)
            .deletingLastPathComponent() // HGSSExtractCLITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("scripts/opening_reference_diff.py", isDirectory: false)
        process.arguments = [
            scriptURL.path(),
            "--expected", expectedRoot.path(),
            "--actual", actualRoot.path(),
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let combinedOutput = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self) +
            String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        #expect(process.terminationStatus == 1)
        #expect(combinedOutput.contains("audioWav[scene1:SEQ_GS_TITLE]"))
    }

    private func writeReferenceArtifacts(root: URL, wavBytes: Data) throws {
        let wavRelativePath = "audio/scene1/seq_gs_title.wav"
        let traceRelativePath = "intermediate/audio/scene1/seq_gs_title.json"

        let wavURL = root.appendingPathComponent(wavRelativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: wavURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try wavBytes.write(to: wavURL)

        let traceURL = root.appendingPathComponent(traceRelativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: traceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"tickCount\":1}".utf8).write(to: traceURL)

        let referenceJSON = """
        {
          "schemaVersion": 1,
          "mode": "opening-heartgold",
          "canonicalVariant": "HEARTGOLD",
          "sourceFiles": ["External/pokeheartgold/src/intro_movie.c"],
          "scenes": [
            {
              "sceneID": "scene1",
              "durationFrames": 10,
              "skipAllowedFromFrame": 5,
              "transitionCueIDs": [],
              "audioCueIDs": ["scene1_bgm"]
            }
          ],
          "audioTraces": [
            {
              "cueName": "SEQ_GS_TITLE",
              "sceneID": "scene1",
              "wavRelativePath": "\(wavRelativePath)",
              "traceRelativePath": "\(traceRelativePath)",
              "provenance": ["External/pokeheartgold/src/intro_movie.c"]
            }
          ]
        }
        """

        try Data(referenceJSON.utf8).write(to: root.appendingPathComponent("opening_reference.json", isDirectory: false))
    }
}
