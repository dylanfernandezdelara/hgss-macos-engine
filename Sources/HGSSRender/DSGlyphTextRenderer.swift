import AppKit
import Foundation
import HGSSDataModel

public struct HGSSDSGlyphTextStyle: Hashable, Sendable {
    public let foregroundPaletteIndex: Int
    public let shadowPaletteIndex: Int
    public let backgroundPaletteIndex: Int
    public let letterSpacing: Int
    public let lineSpacing: Int

    public init(
        foregroundPaletteIndex: Int,
        shadowPaletteIndex: Int,
        backgroundPaletteIndex: Int,
        letterSpacing: Int = 0,
        lineSpacing: Int = 0
    ) {
        self.foregroundPaletteIndex = foregroundPaletteIndex
        self.shadowPaletteIndex = shadowPaletteIndex
        self.backgroundPaletteIndex = backgroundPaletteIndex
        self.letterSpacing = letterSpacing
        self.lineSpacing = lineSpacing
    }

    public static let titlePrompt = HGSSDSGlyphTextStyle(
        foregroundPaletteIndex: 1,
        shadowPaletteIndex: 1,
        backgroundPaletteIndex: 0,
        letterSpacing: 1
    )

    public static let body = HGSSDSGlyphTextStyle(
        foregroundPaletteIndex: 1,
        shadowPaletteIndex: 2,
        backgroundPaletteIndex: 15
    )
}

public enum HGSSDSGlyphRendererError: LocalizedError {
    case missingFontAsset(path: String)
    case invalidFontData(path: String)
    case invalidPaletteData(path: String)
    case invalidCharmap(path: String)

    public var errorDescription: String? {
        switch self {
        case let .missingFontAsset(path):
            return "Missing extracted font asset at \(path)."
        case let .invalidFontData(path):
            return "Unable to decode extracted font data at \(path)."
        case let .invalidPaletteData(path):
            return "Unable to decode extracted font palette at \(path)."
        case let .invalidCharmap(path):
            return "Unable to decode extracted charmap at \(path)."
        }
    }
}

public final class HGSSDSGlyphRenderer: @unchecked Sendable {
    public static let shared = HGSSDSGlyphRenderer()

    private struct ImageCacheKey: Hashable {
        let rootPath: String
        let text: String
        let style: HGSSDSGlyphTextStyle
    }

    fileprivate struct Glyph {
        let width: Int
        let height: Int
        let pixels: [UInt8]
    }

    fileprivate struct LoadedFont {
        let glyphHeight: Int
        let fallbackGlyphID: UInt16
        let glyphsByID: [UInt16: Glyph]
        let charmap: [String: UInt16]
        let palette: [RGBAColor]
    }

    fileprivate struct RGBAColor: Hashable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    private let lock = NSLock()
    private var loadedFonts: [String: LoadedFont] = [:]
    private var imageCache: [ImageCacheKey: NSImage] = [:]

    public init() {}

    public func renderImage(
        text: String,
        from rootURL: URL,
        style: HGSSDSGlyphTextStyle
    ) throws -> NSImage {
        let cacheKey = ImageCacheKey(rootPath: rootURL.path(), text: text, style: style)
        if let cached = cachedImage(for: cacheKey) {
            return cached
        }

        let font = try loadFont(from: rootURL)
        let image = try renderImage(text: text, font: font, style: style)

        lock.lock()
        imageCache[cacheKey] = image
        lock.unlock()
        return image
    }

    public func renderedSize(
        text: String,
        from rootURL: URL,
        style: HGSSDSGlyphTextStyle
    ) throws -> CGSize {
        let font = try loadFont(from: rootURL)
        let lines = text.components(separatedBy: "\n").map { encode(line: $0, using: font) }
        let width = lines.map { renderedLineWidth($0, font: font, style: style) }.max() ?? 0
        let height = max(font.glyphHeight, 1) * max(lines.count, 1) + max(lines.count - 1, 0) * style.lineSpacing
        return CGSize(width: max(width, 1), height: max(height, 1))
    }

    private func cachedImage(for key: ImageCacheKey) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        return imageCache[key]
    }

    private func loadFont(from rootURL: URL) throws -> LoadedFont {
        let cacheKey = rootURL.path()
        lock.lock()
        if let cached = loadedFonts[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let fontURL = rootURL.appendingPathComponent(HGSSOpeningTextAssetPaths.fontData, isDirectory: false)
        let paletteURL = rootURL.appendingPathComponent(HGSSOpeningTextAssetPaths.fontPalette, isDirectory: false)
        let charmapURL = rootURL.appendingPathComponent(HGSSOpeningTextAssetPaths.charmap, isDirectory: false)

        guard FileManager.default.fileExists(atPath: fontURL.path()) else {
            throw HGSSDSGlyphRendererError.missingFontAsset(path: fontURL.path())
        }
        guard FileManager.default.fileExists(atPath: paletteURL.path()) else {
            throw HGSSDSGlyphRendererError.missingFontAsset(path: paletteURL.path())
        }
        guard FileManager.default.fileExists(atPath: charmapURL.path()) else {
            throw HGSSDSGlyphRendererError.missingFontAsset(path: charmapURL.path())
        }

        let loaded = try LoadedFont(
            glyphHeight: 0,
            fallbackGlyphID: 0,
            glyphsByID: [:],
            charmap: [:],
            palette: []
        ).decoding(
            fontData: try Data(contentsOf: fontURL),
            fontPath: fontURL.path(),
            paletteData: try Data(contentsOf: paletteURL),
            palettePath: paletteURL.path(),
            charmapText: try String(contentsOf: charmapURL),
            charmapPath: charmapURL.path()
        )

        lock.lock()
        loadedFonts[cacheKey] = loaded
        lock.unlock()
        return loaded
    }

    private func renderImage(
        text: String,
        font: LoadedFont,
        style: HGSSDSGlyphTextStyle
    ) throws -> NSImage {
        let encodedLines = text.components(separatedBy: "\n").map { encode(line: $0, using: font) }
        let width = max(encodedLines.map { renderedLineWidth($0, font: font, style: style) }.max() ?? 0, 1)
        let height = max(font.glyphHeight, 1) * max(encodedLines.count, 1) + max(encodedLines.count - 1, 0) * style.lineSpacing
        var pixels = Array(repeating: UInt8(0), count: width * max(height, 1) * 4)

        let foreground = resolvedColor(index: style.foregroundPaletteIndex, palette: font.palette)
        let shadow = resolvedColor(index: style.shadowPaletteIndex, palette: font.palette)
        let background = resolvedColor(index: style.backgroundPaletteIndex, palette: font.palette)

        for (lineIndex, encodedLine) in encodedLines.enumerated() {
            var cursorX = 0
            let cursorY = lineIndex * (font.glyphHeight + style.lineSpacing)
            for (glyphPosition, glyphID) in encodedLine.enumerated() {
                let glyph = font.glyphsByID[glyphID] ?? font.glyphsByID[font.fallbackGlyphID]
                guard let glyph else {
                    continue
                }

                for row in 0..<glyph.height {
                    for column in 0..<glyph.width {
                        let pixel = glyph.pixels[(row * max(glyph.width, 1)) + column]
                        let color: RGBAColor
                        switch pixel {
                        case 1:
                            color = foreground
                        case 2:
                            color = shadow
                        case 3:
                            color = background
                        default:
                            continue
                        }
                        guard color.alpha > 0 else {
                            continue
                        }

                        let destinationX = cursorX + column
                        let destinationY = cursorY + row
                        guard destinationX >= 0,
                              destinationX < width,
                              destinationY >= 0,
                              destinationY < height else {
                            continue
                        }

                        let pixelOffset = ((destinationY * width) + destinationX) * 4
                        pixels[pixelOffset + 0] = color.red
                        pixels[pixelOffset + 1] = color.green
                        pixels[pixelOffset + 2] = color.blue
                        pixels[pixelOffset + 3] = color.alpha
                    }
                }

                cursorX += glyph.width
                if glyphPosition < encodedLine.count - 1 {
                    cursorX += style.letterSpacing
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: max(height, 1),
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            throw HGSSDSGlyphRendererError.invalidFontData(path: "in-memory glyph surface")
        }

        return NSImage(cgImage: cgImage, size: .init(width: width, height: max(height, 1)))
    }

    private func encode(line: String, using font: LoadedFont) -> [UInt16] {
        line.map { character in
            let key = String(character)
            if let glyphID = font.charmap[key] {
                return glyphID
            }
            if let questionMark = font.charmap["?"] {
                return questionMark
            }
            return font.fallbackGlyphID
        }
    }

    private func renderedLineWidth(
        _ glyphIDs: [UInt16],
        font: LoadedFont,
        style: HGSSDSGlyphTextStyle
    ) -> Int {
        guard !glyphIDs.isEmpty else {
            return 0
        }
        var totalWidth = 0
        for (index, glyphID) in glyphIDs.enumerated() {
            let glyph = font.glyphsByID[glyphID] ?? font.glyphsByID[font.fallbackGlyphID]
            totalWidth += glyph?.width ?? 0
            if index < glyphIDs.count - 1 {
                totalWidth += style.letterSpacing
            }
        }
        return totalWidth
    }

    private func resolvedColor(index: Int, palette: [RGBAColor]) -> RGBAColor {
        guard index > 0, index < palette.count else {
            return .init(red: 0, green: 0, blue: 0, alpha: 0)
        }
        return palette[index]
    }
}

fileprivate extension HGSSDSGlyphRenderer.LoadedFont {
    func decoding(
        fontData: Data,
        fontPath: String,
        paletteData: Data,
        palettePath: String,
        charmapText: String,
        charmapPath: String
    ) throws -> Self {
        guard fontData.count >= 16 else {
            throw HGSSDSGlyphRendererError.invalidFontData(path: fontPath)
        }

        let headerSize = Int(fontData.readUInt32LE(at: 0))
        let widthDataStart = Int(fontData.readUInt32LE(at: 4))
        let numGlyphs = Int(fontData.readUInt32LE(at: 8))
        let fixedHeight = Int(fontData[13])
        let glyphWidthTiles = Int(fontData[14])
        let glyphHeightTiles = Int(fontData[15])
        let glyphSize = 16 * glyphWidthTiles * glyphHeightTiles

        guard headerSize > 0,
              widthDataStart + numGlyphs <= fontData.count,
              headerSize + (glyphSize * numGlyphs) <= fontData.count,
              glyphWidthTiles > 0,
              glyphHeightTiles > 0 else {
            throw HGSSDSGlyphRendererError.invalidFontData(path: fontPath)
        }

        let widths = Array(fontData[widthDataStart..<(widthDataStart + numGlyphs)])
        var glyphsByID: [UInt16: HGSSDSGlyphRenderer.Glyph] = [:]
        glyphsByID.reserveCapacity(numGlyphs)

        for glyphIndex in 0..<numGlyphs {
            let glyphOffset = headerSize + (glyphIndex * glyphSize)
            let glyphData = fontData[glyphOffset..<(glyphOffset + glyphSize)]
            let width = Int(widths[glyphIndex])
            let height = fixedHeight
            let pixels = decodeGlyph(
                data: glyphData,
                tileColumns: glyphWidthTiles,
                tileRows: glyphHeightTiles
            )
            glyphsByID[UInt16(glyphIndex + 1)] = .init(
                width: max(width, 1),
                height: max(height, 1),
                pixels: pixels
            )
        }

        let charmap = try decodeCharmap(text: charmapText, path: charmapPath)
        let palette = try decodePalette(data: paletteData, path: palettePath)
        let fallbackGlyphID = charmap["?"] ?? 1

        return Self(
            glyphHeight: max(fixedHeight, 1),
            fallbackGlyphID: fallbackGlyphID,
            glyphsByID: glyphsByID,
            charmap: charmap,
            palette: palette
        )
    }

    private func decodeGlyph(
        data: Data.SubSequence,
        tileColumns: Int,
        tileRows: Int
    ) -> [UInt8] {
        let pixelWidth = tileColumns * 8
        let pixelHeight = tileRows * 8
        var pixels = Array(repeating: UInt8(0), count: pixelWidth * pixelHeight)

        for tileRow in 0..<tileRows {
            for tileColumn in 0..<tileColumns {
                let tileIndex = (tileRow * tileColumns) + tileColumn
                let tileOffset = tileIndex * 16
                for tilePixelRow in 0..<8 {
                    let rowByteOffset = tileOffset + (tilePixelRow * 2)
                    let lowByte = data[data.index(data.startIndex, offsetBy: rowByteOffset)]
                    let highByte = data[data.index(data.startIndex, offsetBy: rowByteOffset + 1)]
                    let bytes = [highByte, lowByte]
                    for (byteIndex, byte) in bytes.enumerated() {
                        for nibbleIndex in 0..<4 {
                            let pixelValue = (byte >> (nibbleIndex * 2)) & 0x03
                            let destinationX = (tileColumn * 8) + (byteIndex * 4) + nibbleIndex
                            let destinationY = (tileRow * 8) + tilePixelRow
                            pixels[(destinationY * pixelWidth) + destinationX] = pixelValue
                        }
                    }
                }
            }
        }

        return pixels
    }

    private func decodeCharmap(text: String, path: String) throws -> [String: UInt16] {
        var charmap: [String: UInt16] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("//") else {
                continue
            }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let glyphID = UInt16(parts[0], radix: 16) else {
                throw HGSSDSGlyphRendererError.invalidCharmap(path: path)
            }

            let token = String(parts[1])
            guard !token.hasPrefix("{") else {
                continue
            }
            if let decoded = decodeCharmapToken(token) {
                charmap[decoded] = glyphID
            }
        }

        guard !charmap.isEmpty else {
            throw HGSSDSGlyphRendererError.invalidCharmap(path: path)
        }
        return charmap
    }

    private func decodeCharmapToken(_ token: String) -> String? {
        if token.hasPrefix("\\x"), token.count == 6 {
            let hex = String(token.dropFirst(2))
            guard let scalar = UInt32(hex, radix: 16).flatMap(UnicodeScalar.init) else {
                return nil
            }
            return String(scalar)
        }
        return token
    }

    private func decodePalette(data: Data, path: String) throws -> [HGSSDSGlyphRenderer.RGBAColor] {
        guard let ttlpRange = data.range(of: Data("TTLP".utf8)) else {
            throw HGSSDSGlyphRendererError.invalidPaletteData(path: path)
        }

        let chunkOffset = ttlpRange.lowerBound
        guard data.count >= chunkOffset + 24 else {
            throw HGSSDSGlyphRendererError.invalidPaletteData(path: path)
        }

        let paletteDataSize = Int(data.readUInt32LE(at: chunkOffset + 16))
        let colorCount = Int(data.readUInt32LE(at: chunkOffset + 20))
        let paletteOffset = chunkOffset + 24
        guard paletteDataSize >= colorCount * 2,
              data.count >= paletteOffset + paletteDataSize else {
            throw HGSSDSGlyphRendererError.invalidPaletteData(path: path)
        }

        return (0..<colorCount).map { index in
            let raw = data.readUInt16LE(at: paletteOffset + (index * 2))
            let red = UInt8((raw & 0x1F) * 255 / 31)
            let green = UInt8(((raw >> 5) & 0x1F) * 255 / 31)
            let blue = UInt8(((raw >> 10) & 0x1F) * 255 / 31)
            return HGSSDSGlyphRenderer.RGBAColor(red: red, green: green, blue: blue, alpha: 255)
        }
    }
}

private extension Data {
    func readUInt32LE(at offset: Int) -> UInt32 {
        let b0 = UInt32(self[offset + 0])
        let b1 = UInt32(self[offset + 1]) << 8
        let b2 = UInt32(self[offset + 2]) << 16
        let b3 = UInt32(self[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    func readUInt16LE(at offset: Int) -> UInt16 {
        let b0 = UInt16(self[offset + 0])
        let b1 = UInt16(self[offset + 1]) << 8
        return b0 | b1
    }
}
