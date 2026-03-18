import AppKit
import Foundation
import HGSSDataModel
import HGSSOpeningIR
@testable import HGSSRender
import Testing

@MainActor
struct HGSSOpeningScreenCompositorTests {
    @Test("Screen compositor respects layer and sprite ordering")
    func compositorRespectsOrdering() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidPNG(
            at: root,
            relativePath: "assets/red.png",
            color: NSColor(red: 1, green: 0, blue: 0, alpha: 1),
            size: .init(width: 256, height: 192)
        )
        try writeSolidPNG(
            at: root,
            relativePath: "assets/green.png",
            color: NSColor(red: 0, green: 1, blue: 0, alpha: 1),
            size: .init(width: 32, height: 32)
        )
        try writeBundle(makeOrderingBundle(), to: root)

        let loadedBundle = try OpeningBundleLoader().load(from: root)
        let controller = HGSSOpeningPlaybackController(loadedBundle: loadedBundle)
        let compositor = HGSSOpeningScreenCompositor(loadedBundle: loadedBundle)

        let image = compositor.render(
            screen: .top,
            size: loadedBundle.bundle.topScreen,
            controller: controller
        )

        #expect(samplePixel(in: image, x: 10, y: 10) == RGBA8(red: 255, green: 0, blue: 0, alpha: 255))
        #expect(samplePixel(in: image, x: 24, y: 24) == RGBA8(red: 0, green: 255, blue: 0, alpha: 255))
    }

    @Test("Screen compositor clips bundle content to the active window mask")
    func compositorClipsToWindowMask() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidPNG(
            at: root,
            relativePath: "assets/red.png",
            color: NSColor(red: 1, green: 0, blue: 0, alpha: 1),
            size: .init(width: 256, height: 192)
        )
        try writeBundle(makeMaskedBundle(), to: root)

        let loadedBundle = try OpeningBundleLoader().load(from: root)
        let controller = HGSSOpeningPlaybackController(loadedBundle: loadedBundle)
        let compositor = HGSSOpeningScreenCompositor(loadedBundle: loadedBundle)

        let image = compositor.render(
            screen: .top,
            size: loadedBundle.bundle.topScreen,
            controller: controller
        )

        #expect(samplePixel(in: image, x: 8, y: 8) == RGBA8(red: 0, green: 0, blue: 0, alpha: 255))
        #expect(samplePixel(in: image, x: 80, y: 80) == RGBA8(red: 255, green: 0, blue: 0, alpha: 255))
    }

    @Test("Screen compositor applies program fade overlays over solid fills")
    func compositorAppliesProgramFadeOverlay() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSolidPNG(
            at: root,
            relativePath: "assets/title.png",
            color: NSColor(red: 0, green: 0, blue: 1, alpha: 1),
            size: .init(width: 256, height: 192)
        )
        try writeBundle(makeTitleBundle(), to: root)
        try writeProgram(makeFadeOverlayProgram(), to: root)

        let loadedBundle = try OpeningBundleLoader().load(from: root)
        let loadedProgram = try OpeningProgramLoader().load(from: root)
        let controller = HGSSOpeningPlaybackController(
            loadedBundle: loadedBundle,
            loadedProgram: loadedProgram
        )
        let compositor = HGSSOpeningScreenCompositor(loadedBundle: loadedBundle)

        controller.requestSkip()

        let image = compositor.render(
            screen: .top,
            size: loadedBundle.bundle.topScreen,
            controller: controller
        )

        #expect(samplePixel(in: image, x: 64, y: 64) == RGBA8(red: 132, green: 0, blue: 0, alpha: 255))
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-opening-compositor-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeSolidPNG(
        at root: URL,
        relativePath: String,
        color: NSColor,
        size: CGSize
    ) throws {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let rgbaColor = color.usingColorSpace(.deviceRGB) ?? color
        let red = UInt8((rgbaColor.redComponent * 255).rounded())
        let green = UInt8((rgbaColor.greenComponent * 255).rounded())
        let blue = UInt8((rgbaColor.blueComponent * 255).rounded())
        let alpha = UInt8((rgbaColor.alphaComponent * 255).rounded())
        let pixelCount = Int(size.width * size.height)
        var pixels = [UInt8]()
        pixels.reserveCapacity(pixelCount * 4)
        for _ in 0..<pixelCount {
            pixels.append(contentsOf: [red, green, blue, alpha])
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                  width: Int(size.width),
                  height: Int(size.height),
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: Int(size.width) * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ),
              let bitmap = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try bitmap.write(to: url)
    }

    private func writeBundle(_ bundle: HGSSOpeningBundle, to root: URL) throws {
        try JSONEncoder().encode(bundle).write(
            to: root.appendingPathComponent("opening_bundle.json", isDirectory: false)
        )
    }

    private func writeProgram(_ program: HGSSOpeningProgramIR, to root: URL) throws {
        try JSONEncoder().encode(program).write(
            to: root.appendingPathComponent("opening_program_ir.json", isDirectory: false)
        )
    }

    private func makeOrderingBundle() -> HGSSOpeningBundle {
        HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: [
                .init(id: "red", kind: .image, relativePath: "assets/red.png", provenance: "test"),
                .init(id: "green", kind: .image, relativePath: "assets/green.png", provenance: "test"),
            ],
            scenes: [
                .init(
                    id: .scene1,
                    durationFrames: 1,
                    skipAllowedFromFrame: 0,
                    topLayers: [
                        .init(
                            id: "background",
                            assetID: "red",
                            screenRect: .init(x: 0, y: 0, width: 256, height: 192),
                            zIndex: 0
                        )
                    ],
                    bottomLayers: [],
                    spriteAnimations: [
                        .init(
                            id: "foreground",
                            screen: .top,
                            frameAssetIDs: ["green"],
                            screenRect: .init(x: 16, y: 16, width: 32, height: 32),
                            frameDurationFrames: 1,
                            loop: false,
                            zIndex: 1
                        )
                    ],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: []
                ),
                fillerScene(id: .scene2),
                fillerScene(id: .scene3),
                fillerScene(id: .scene4),
                fillerScene(id: .scene5),
                fillerScene(id: .titleHandoff, durationFrames: 1)
            ]
        )
    }

    private func makeMaskedBundle() -> HGSSOpeningBundle {
        HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: [
                .init(id: "red", kind: .image, relativePath: "assets/red.png", provenance: "test"),
            ],
            scenes: [
                .init(
                    id: .scene1,
                    durationFrames: 1,
                    skipAllowedFromFrame: 0,
                    topLayers: [
                        .init(
                            id: "masked",
                            assetID: "red",
                            screenRect: .init(x: 0, y: 0, width: 256, height: 192),
                            zIndex: 0
                        )
                    ],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [
                        .init(
                            id: "window",
                            kind: .window,
                            screen: .top,
                            startFrame: 0,
                            durationFrames: 1,
                            fromRect: .init(x: 64, y: 64, width: 96, height: 64),
                            toRect: .init(x: 64, y: 64, width: 96, height: 64)
                        )
                    ],
                    audioCues: []
                ),
                fillerScene(id: .scene2),
                fillerScene(id: .scene3),
                fillerScene(id: .scene4),
                fillerScene(id: .scene5),
                fillerScene(id: .titleHandoff, durationFrames: 1)
            ]
        )
    }

    private func makeTitleBundle() -> HGSSOpeningBundle {
        HGSSOpeningBundle(
            schemaVersion: 1,
            canonicalVariant: .heartGold,
            topScreen: .init(width: 256, height: 192),
            bottomScreen: .init(width: 256, height: 192),
            assets: [
                .init(id: "title_top", kind: .image, relativePath: "assets/title.png", provenance: "test"),
            ],
            scenes: [
                fillerScene(id: .scene1),
                fillerScene(id: .scene2),
                fillerScene(id: .scene3),
                fillerScene(id: .scene4),
                fillerScene(id: .scene5),
                .init(
                    id: .titleHandoff,
                    durationFrames: 1,
                    skipAllowedFromFrame: 0,
                    topLayers: [
                        .init(
                            id: "title_top",
                            assetID: "title_top",
                            screenRect: .init(x: 0, y: 0, width: 256, height: 192),
                            zIndex: 0
                        )
                    ],
                    bottomLayers: [],
                    spriteAnimations: [],
                    modelAnimations: [],
                    transitionCues: [],
                    audioCues: []
                ),
            ]
        )
    }

    private func makeFadeOverlayProgram() -> HGSSOpeningProgramIR {
        let provenance = HGSSOpeningProgramIR.Provenance(sourceFile: "title_screen.c", symbol: "TitleScreen_Main")
        return HGSSOpeningProgramIR(
            schemaVersion: 1,
            entrySceneID: .titleScreen,
            sourceFiles: ["title_screen.c"],
            scenes: [
                .init(
                    id: .titleScreen,
                    initialStateID: "title_fade",
                    states: [
                        .init(
                            id: "title_fade",
                            duration: .fixedFrames(1),
                            commands: [
                                .setSolidFill(
                                    .init(screen: .top, colorHex: "#FF0000", provenance: provenance)
                                ),
                                .fade(
                                    .init(
                                        target: .palette,
                                        startLevel: 15,
                                        endLevel: 15,
                                        durationFrames: 1,
                                        colorHex: "#000000",
                                        provenance: provenance
                                    )
                                )
                            ],
                            transitions: [],
                            provenance: provenance
                        )
                    ],
                    provenance: provenance
                )
            ]
        )
    }

    private func fillerScene(
        id: HGSSOpeningBundle.SceneID,
        durationFrames: Int = 1
    ) -> HGSSOpeningBundle.Scene {
        .init(
            id: id,
            durationFrames: durationFrames,
            skipAllowedFromFrame: 0,
            topLayers: [],
            bottomLayers: [],
            spriteAnimations: [],
            modelAnimations: [],
            transitionCues: [],
            audioCues: []
        )
    }

    private func samplePixel(in image: NSImage, x: Int, y: Int) -> RGBA8 {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let provider = cgImage.dataProvider,
              let bytes = provider.data else {
            return .init(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let data = bytes as Data
        let clampedX = min(max(x, 0), cgImage.width - 1)
        let clampedY = min(max(y, 0), cgImage.height - 1)
        let byteOffset = ((clampedY * cgImage.width) + clampedX) * 4
        return .init(
            red: data[byteOffset + 0],
            green: data[byteOffset + 1],
            blue: data[byteOffset + 2],
            alpha: data[byteOffset + 3]
        )
    }
}

private struct RGBA8: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}
