import Foundation
import HGSSCore
import HGSSDataModel
import HGSSRender
import Testing

struct HGSSRenderSmokeTests {
    @Test("Loads render bundle and resolves local asset URLs")
    func loadsRenderBundle() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let assetsRoot = root.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsRoot, withIntermediateDirectories: true)
        let topURL = assetsRoot.appendingPathComponent("top_boot_frame.png", isDirectory: false)
        let bottomURL = assetsRoot.appendingPathComponent("bottom_idle_overworld.png", isDirectory: false)
        let playerURL = assetsRoot.appendingPathComponent("ethan_overworld.png", isDirectory: false)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: topURL)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: bottomURL)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: playerURL)

        try writeBundle(
            makeBundle(
                assets: [
                    .init(
                        id: "top_boot_frame",
                        relativePath: "assets/top_boot_frame.png",
                        pixelWidth: 256,
                        pixelHeight: 192
                    ),
                    .init(
                        id: "bottom_idle_overworld",
                        relativePath: "assets/bottom_idle_overworld.png",
                        pixelWidth: 256,
                        pixelHeight: 192
                    ),
                    .init(
                        id: "ethan_overworld",
                        relativePath: "assets/ethan_overworld.png",
                        pixelWidth: 128,
                        pixelHeight: 128
                    ),
                ]
            ),
            to: root
        )

        let loaded = try RenderBundleLoader().load(from: root)

        #expect(loaded.bundle.initialMapID == "MAP_NEW_BARK")
        #expect(loaded.bundle.initialEntryPointID == "ENTRY_BOOT_DEFAULT")
        #expect(loaded.bundle.bootVariant.protagonistID == "ETHAN")
        #expect(loaded.bundle.topScreen.frameAssetID == "top_boot_frame")
        #expect(loaded.bundle.bottomScreen.frameAssetID == "bottom_idle_overworld")
        #expect(try loaded.assetURL(id: "top_boot_frame").path() == topURL.path())
    }

    @Test("Rejects duplicate render asset identifiers")
    func rejectsDuplicateAssetIDs() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeBundle(
            makeBundle(
                assets: [
                    .init(id: "dup", relativePath: "assets/first.png"),
                    .init(id: "dup", relativePath: "assets/second.png")
                ]
            ),
            to: root
        )

        do {
            _ = try RenderBundleLoader().load(from: root)
            Issue.record("Expected duplicate asset ids to fail decoding.")
        } catch let error as HGSSRenderError {
            if case let .duplicateAssetID(assetID) = error {
                #expect(assetID == "dup")
            } else {
                Issue.record("Expected duplicateAssetID error, got \(error.localizedDescription).")
            }
        }
    }

    @Test("Rejects bundles with missing referenced asset files")
    func rejectsMissingAssetFiles() throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("assets", isDirectory: true),
            withIntermediateDirectories: true
        )

        try writeBundle(
            makeBundle(
                assets: [
                    .init(id: "top_boot_frame", relativePath: "assets/top_boot_frame.png"),
                    .init(id: "bottom_idle_overworld", relativePath: "assets/bottom_idle_overworld.png"),
                    .init(id: "ethan_overworld", relativePath: "assets/ethan_overworld.png")
                ]
            ),
            to: root
        )

        do {
            _ = try RenderBundleLoader().load(from: root)
            Issue.record("Expected missing asset files to fail decoding.")
        } catch let error as HGSSRenderError {
            if case let .missingAssetFile(assetID, _) = error {
                #expect(assetID == "top_boot_frame")
            } else {
                Issue.record("Expected missingAssetFile error, got \(error.localizedDescription).")
            }
        }
    }

    @Test("Integer scale preserves DS-native stepping")
    func integerScaleUsesWholeNumbers() {
        #expect(
            HGSSDualScreenLayout.integerScale(
                containerWidth: 960,
                containerHeight: 1200,
                nativeWidth: 256,
                topHeight: 192,
                bottomHeight: 192,
                screenGap: 18
            ) == 2
        )

        #expect(
            HGSSDualScreenLayout.integerScale(
                containerWidth: 320,
                containerHeight: 700,
                nativeWidth: 256,
                topHeight: 192,
                bottomHeight: 192,
                screenGap: 18
            ) == 1
        )
    }

    @Test("Camera origin clamps to map bounds")
    func cameraClampsToMapBounds() async throws {
        let runtime = try await makeRuntime()
        let snapshot = await runtime.snapshot()
        let camera = HGSSRenderBundle.Camera(
            viewportTilesWide: 8,
            viewportTilesHigh: 6,
            tileSize: 32,
            stepDurationMilliseconds: 180
        )

        let topLeft = HGSSRenderCamera.clampedOrigin(
            for: HGSSRenderDisplayPoint(x: 1, y: 1),
            snapshot: snapshot,
            camera: camera
        )
        let bottomRight = HGSSRenderCamera.clampedOrigin(
            for: HGSSRenderDisplayPoint(x: 24, y: 17),
            snapshot: snapshot,
            camera: camera
        )

        #expect(topLeft == HGSSRenderDisplayPoint(x: 0, y: 0))
        #expect(bottomRight == HGSSRenderDisplayPoint(x: 17, y: 12))
        await runtime.stop()
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hgss-render-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeBundle(_ bundle: HGSSRenderBundle, to root: URL) throws {
        let data = try JSONEncoder().encode(bundle)
        try data.write(to: root.appendingPathComponent("render_bundle.json", isDirectory: false))
    }

    private func makeBundle(assets: [HGSSRenderBundle.Asset]) -> HGSSRenderBundle {
        HGSSRenderBundle(
            schemaVersion: 2,
            title: "Render Test Bundle",
            build: "test-build",
            initialMapID: "MAP_NEW_BARK",
            initialEntryPointID: "ENTRY_BOOT_DEFAULT",
            bootVariant: .init(
                protagonistID: "ETHAN",
                timeOfDay: "day",
                weather: 0,
                mapID: "MAP_NEW_BARK",
                entryPointID: "ENTRY_BOOT_DEFAULT"
            ),
            assets: assets,
            topScreen: .init(
                nativeScreen: .init(width: 256, height: 192),
                frameAssetID: "top_boot_frame",
                camera: .init(
                    viewportTilesWide: 8,
                    viewportTilesHigh: 6,
                    tileSize: 32,
                    stepDurationMilliseconds: 180
                )
            ),
            bottomScreen: .init(
                nativeScreen: .init(width: 256, height: 192),
                frameAssetID: "bottom_idle_overworld"
            ),
            playerSpriteSheet: .init(
                assetID: "ethan_overworld",
                frameWidth: 32,
                frameHeight: 32,
                columns: 4,
                rows: 4,
                defaultFacing: "down"
            ),
            developerOverlay: .init(
                palette: .init(
                    blockedFillHex: "#444444",
                    blockedStrokeHex: "#FFFFFF",
                    warpFillHex: "#0088CC",
                    warpStrokeHex: "#E6F7FF",
                    placementFillHex: "#CC9900",
                    placementStrokeHex: "#FFF3D8",
                    entryPointFillHex: "#CC5500",
                    entryPointStrokeHex: "#FFE7E1",
                    gridHex: "#FFFFFF"
                )
            )
        )
    }

    private func makeRuntime() async throws -> HGSSCoreRuntime {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stubPath = repoRoot.appendingPathComponent("DevContent/Stub", isDirectory: true)

        return try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubPath)
    }
}
