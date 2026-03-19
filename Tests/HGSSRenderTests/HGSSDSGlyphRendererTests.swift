import AppKit
import Foundation
import HGSSDataModel
import HGSSRender
import Testing

struct HGSSDSGlyphRendererTests {
    @Test("DS glyph renderer draws the extracted title prompt font")
    func rendersTitlePromptGlyphs() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        guard try copyExtractedFontAssetsIfAvailable(to: root) else {
            return
        }

        let image = try HGSSDSGlyphRenderer.shared.renderImage(
            text: "TOUCH TO START",
            from: root,
            style: .titlePrompt
        )

        #expect(Int(image.size.height) == 16)
        #expect(Int(image.size.width) > 80)
        #expect(opaquePixelCount(in: image) > 150)
    }

    @Test("DS glyph renderer preserves multiline message layout with extracted glyphs")
    func rendersMultilineMessageGlyphs() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        guard try copyExtractedFontAssetsIfAvailable(to: root) else {
            return
        }

        let image = try HGSSDSGlyphRenderer.shared.renderImage(
            text: "The save file is corrupted.\nThe previous save file will be loaded.",
            from: root,
            style: .body
        )

        #expect(Int(image.size.height) == 32)
        #expect(Int(image.size.width) > 160)
        #expect(opaquePixelCount(in: image) > 400)
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func copyExtractedFontAssetsIfAvailable(to root: URL) throws -> Bool {
        let fontDirectory = root.appendingPathComponent(HGSSOpeningTextAssetPaths.directory, isDirectory: true)
        try FileManager.default.createDirectory(at: fontDirectory, withIntermediateDirectories: true)

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let pretRoot = repoRoot.appendingPathComponent("External/pokeheartgold", isDirectory: true)

        let copies: [(source: URL, destination: URL)] = [
            (
                pretRoot.appendingPathComponent("files/graphic/font/font_00000000.bin", isDirectory: false),
                root.appendingPathComponent(HGSSOpeningTextAssetPaths.fontData, isDirectory: false)
            ),
            (
                pretRoot.appendingPathComponent("files/graphic/font/font_00000007.bin", isDirectory: false),
                root.appendingPathComponent(HGSSOpeningTextAssetPaths.fontPalette, isDirectory: false)
            ),
            (
                pretRoot.appendingPathComponent("charmap.txt", isDirectory: false),
                root.appendingPathComponent(HGSSOpeningTextAssetPaths.charmap, isDirectory: false)
            ),
        ]

        for copy in copies {
            guard FileManager.default.fileExists(atPath: copy.source.path()) else {
                return false
            }
            try FileManager.default.copyItem(at: copy.source, to: copy.destination)
        }

        return true
    }

    private func opaquePixelCount(in image: NSImage) -> Int {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0 {
                    count += 1
                }
            }
        }
        return count
    }
}
