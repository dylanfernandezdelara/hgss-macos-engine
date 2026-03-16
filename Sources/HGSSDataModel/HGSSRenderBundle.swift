import Foundation

public struct HGSSRenderBundle: Codable, Equatable, Sendable {
    public struct NativeScreen: Codable, Equatable, Sendable {
        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    public struct Asset: Codable, Equatable, Sendable {
        public let id: String
        public let relativePath: String
        public let pixelWidth: Int?
        public let pixelHeight: Int?
        public let provenance: String?

        public init(
            id: String,
            relativePath: String,
            pixelWidth: Int? = nil,
            pixelHeight: Int? = nil,
            provenance: String? = nil
        ) {
            self.id = id
            self.relativePath = relativePath
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.provenance = provenance
        }
    }

    public struct ScreenRect: Codable, Equatable, Sendable {
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int

        public init(x: Int, y: Int, width: Int, height: Int) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    public struct Camera: Codable, Equatable, Sendable {
        public let viewportTilesWide: Int
        public let viewportTilesHigh: Int
        public let tileSize: Int
        public let stepDurationMilliseconds: Int

        public init(
            viewportTilesWide: Int,
            viewportTilesHigh: Int,
            tileSize: Int,
            stepDurationMilliseconds: Int
        ) {
            self.viewportTilesWide = viewportTilesWide
            self.viewportTilesHigh = viewportTilesHigh
            self.tileSize = tileSize
            self.stepDurationMilliseconds = stepDurationMilliseconds
        }
    }

    public struct BootVariant: Codable, Equatable, Sendable {
        public let protagonistID: String
        public let timeOfDay: String
        public let weather: Int
        public let mapID: String
        public let entryPointID: String

        public init(
            protagonistID: String,
            timeOfDay: String,
            weather: Int,
            mapID: String,
            entryPointID: String
        ) {
            self.protagonistID = protagonistID
            self.timeOfDay = timeOfDay
            self.weather = weather
            self.mapID = mapID
            self.entryPointID = entryPointID
        }
    }

    public struct TopScreen: Codable, Equatable, Sendable {
        public let nativeScreen: NativeScreen
        public let frameAssetID: String
        public let camera: Camera

        public init(nativeScreen: NativeScreen, frameAssetID: String, camera: Camera) {
            self.nativeScreen = nativeScreen
            self.frameAssetID = frameAssetID
            self.camera = camera
        }
    }

    public struct BottomScreen: Codable, Equatable, Sendable {
        public let nativeScreen: NativeScreen
        public let frameAssetID: String

        public init(nativeScreen: NativeScreen, frameAssetID: String) {
            self.nativeScreen = nativeScreen
            self.frameAssetID = frameAssetID
        }
    }

    public struct PlayerSpriteSheet: Codable, Equatable, Sendable {
        public let assetID: String
        public let frameWidth: Int
        public let frameHeight: Int
        public let columns: Int
        public let rows: Int
        public let defaultFacing: String

        public init(
            assetID: String,
            frameWidth: Int,
            frameHeight: Int,
            columns: Int,
            rows: Int,
            defaultFacing: String
        ) {
            self.assetID = assetID
            self.frameWidth = frameWidth
            self.frameHeight = frameHeight
            self.columns = columns
            self.rows = rows
            self.defaultFacing = defaultFacing
        }
    }

    public struct OverlayPalette: Codable, Equatable, Sendable {
        public let blockedFillHex: String
        public let blockedStrokeHex: String
        public let warpFillHex: String
        public let warpStrokeHex: String
        public let placementFillHex: String
        public let placementStrokeHex: String
        public let entryPointFillHex: String
        public let entryPointStrokeHex: String
        public let gridHex: String

        public init(
            blockedFillHex: String,
            blockedStrokeHex: String,
            warpFillHex: String,
            warpStrokeHex: String,
            placementFillHex: String,
            placementStrokeHex: String,
            entryPointFillHex: String,
            entryPointStrokeHex: String,
            gridHex: String
        ) {
            self.blockedFillHex = blockedFillHex
            self.blockedStrokeHex = blockedStrokeHex
            self.warpFillHex = warpFillHex
            self.warpStrokeHex = warpStrokeHex
            self.placementFillHex = placementFillHex
            self.placementStrokeHex = placementStrokeHex
            self.entryPointFillHex = entryPointFillHex
            self.entryPointStrokeHex = entryPointStrokeHex
            self.gridHex = gridHex
        }
    }

    public struct DeveloperOverlay: Codable, Equatable, Sendable {
        public let palette: OverlayPalette

        public init(palette: OverlayPalette) {
            self.palette = palette
        }
    }

    public let schemaVersion: Int
    public let title: String
    public let build: String
    public let initialMapID: String
    public let initialEntryPointID: String
    public let bootVariant: BootVariant
    public let assets: [Asset]
    public let topScreen: TopScreen
    public let bottomScreen: BottomScreen
    public let playerSpriteSheet: PlayerSpriteSheet
    public let developerOverlay: DeveloperOverlay

    public init(
        schemaVersion: Int,
        title: String,
        build: String,
        initialMapID: String,
        initialEntryPointID: String,
        bootVariant: BootVariant,
        assets: [Asset],
        topScreen: TopScreen,
        bottomScreen: BottomScreen,
        playerSpriteSheet: PlayerSpriteSheet,
        developerOverlay: DeveloperOverlay
    ) {
        self.schemaVersion = schemaVersion
        self.title = title
        self.build = build
        self.initialMapID = initialMapID
        self.initialEntryPointID = initialEntryPointID
        self.bootVariant = bootVariant
        self.assets = assets
        self.topScreen = topScreen
        self.bottomScreen = bottomScreen
        self.playerSpriteSheet = playerSpriteSheet
        self.developerOverlay = developerOverlay
    }
}
