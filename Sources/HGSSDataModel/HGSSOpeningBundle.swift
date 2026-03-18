import Foundation

public struct HGSSOpeningBundle: Codable, Equatable, Sendable {
    public enum CanonicalVariant: String, Codable, Equatable, Sendable {
        case heartGold = "HEARTGOLD"
    }

    public enum SceneID: String, Codable, Equatable, Sendable, CaseIterable {
        case scene1
        case scene2
        case scene3
        case scene4
        case scene5
        case titleHandoff = "title_handoff"
    }

    public enum ScreenID: String, Codable, Equatable, Sendable {
        case top
        case bottom
    }

    public enum AssetKind: String, Codable, Equatable, Sendable {
        case image
        case modelScene = "model_scene"
        case audioFile = "audio_file"
        case audioMetadata = "audio_metadata"
    }

    public enum TransitionCueKind: String, Codable, Equatable, Sendable {
        case fade
        case brightness
        case scroll
        case circleWipe = "circle_wipe"
        case viewport
        case window
    }

    public enum AudioCueAction: String, Codable, Equatable, Sendable {
        case startBGM = "start_bgm"
        case stopBGM = "stop_bgm"
        case triggerCry = "trigger_cry"
    }

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
        public let kind: AssetKind
        public let relativePath: String
        public let pixelWidth: Int?
        public let pixelHeight: Int?
        public let provenance: String

        public init(
            id: String,
            kind: AssetKind,
            relativePath: String,
            pixelWidth: Int? = nil,
            pixelHeight: Int? = nil,
            provenance: String
        ) {
            self.id = id
            self.kind = kind
            self.relativePath = relativePath
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.provenance = provenance
        }
    }

    public struct ScreenRect: Codable, Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    public struct Vector3: Codable, Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let z: Double

        public init(x: Double, y: Double, z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    public struct LayerRef: Codable, Equatable, Sendable {
        public let id: String
        public let assetID: String
        public let screenRect: ScreenRect
        public let opacity: Double
        public let wraps: Bool
        public let zIndex: Int
        public let startFrame: Int
        public let endFrame: Int?

        private enum CodingKeys: String, CodingKey {
            case id
            case assetID
            case screenRect
            case opacity
            case wraps
            case zIndex
            case startFrame
            case endFrame
        }

        public init(
            id: String,
            assetID: String,
            screenRect: ScreenRect,
            opacity: Double = 1.0,
            wraps: Bool = false,
            zIndex: Int,
            startFrame: Int = 0,
            endFrame: Int? = nil
        ) {
            self.id = id
            self.assetID = assetID
            self.screenRect = screenRect
            self.opacity = opacity
            self.wraps = wraps
            self.zIndex = zIndex
            self.startFrame = startFrame
            self.endFrame = endFrame
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            assetID = try container.decode(String.self, forKey: .assetID)
            screenRect = try container.decode(ScreenRect.self, forKey: .screenRect)
            opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
            wraps = try container.decodeIfPresent(Bool.self, forKey: .wraps) ?? false
            zIndex = try container.decode(Int.self, forKey: .zIndex)
            startFrame = try container.decodeIfPresent(Int.self, forKey: .startFrame) ?? 0
            endFrame = try container.decodeIfPresent(Int.self, forKey: .endFrame)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(assetID, forKey: .assetID)
            try container.encode(screenRect, forKey: .screenRect)
            try container.encode(opacity, forKey: .opacity)
            if wraps {
                try container.encode(wraps, forKey: .wraps)
            }
            try container.encode(zIndex, forKey: .zIndex)
            try container.encode(startFrame, forKey: .startFrame)
            try container.encodeIfPresent(endFrame, forKey: .endFrame)
        }
    }

    public struct SpriteAnimationRef: Codable, Equatable, Sendable {
        public let id: String
        public let screen: ScreenID
        public let frameAssetIDs: [String]
        public let screenRect: ScreenRect
        public let frameDurationFrames: Int
        public let startFrame: Int
        public let endFrame: Int?
        public let loop: Bool
        public let zIndex: Int

        public init(
            id: String,
            screen: ScreenID,
            frameAssetIDs: [String],
            screenRect: ScreenRect,
            frameDurationFrames: Int,
            startFrame: Int = 0,
            endFrame: Int? = nil,
            loop: Bool = true,
            zIndex: Int
        ) {
            self.id = id
            self.screen = screen
            self.frameAssetIDs = frameAssetIDs
            self.screenRect = screenRect
            self.frameDurationFrames = frameDurationFrames
            self.startFrame = startFrame
            self.endFrame = endFrame
            self.loop = loop
            self.zIndex = zIndex
        }
    }

    public struct ModelAnimationRef: Codable, Equatable, Sendable {
        public struct MaterialState: Codable, Equatable, Sendable {
            public let diffuseHex: String?
            public let ambientHex: String?
            public let specularHex: String?
            public let emissionHex: String?

            public init(
                diffuseHex: String? = nil,
                ambientHex: String? = nil,
                specularHex: String? = nil,
                emissionHex: String? = nil
            ) {
                self.diffuseHex = diffuseHex
                self.ambientHex = ambientHex
                self.specularHex = specularHex
                self.emissionHex = emissionHex
            }
        }

        public struct CameraState: Codable, Equatable, Sendable {
            public let position: Vector3
            public let target: Vector3
            public let fieldOfViewDegrees: Double?
            public let nearClipDistance: Double?
            public let farClipDistance: Double?

            public init(
                position: Vector3,
                target: Vector3,
                fieldOfViewDegrees: Double? = nil,
                nearClipDistance: Double? = nil,
                farClipDistance: Double? = nil
            ) {
                self.position = position
                self.target = target
                self.fieldOfViewDegrees = fieldOfViewDegrees
                self.nearClipDistance = nearClipDistance
                self.farClipDistance = farClipDistance
            }
        }

        public struct LightState: Codable, Equatable, Sendable {
            public let direction: Vector3
            public let colorHex: String

            public init(direction: Vector3, colorHex: String) {
                self.direction = direction
                self.colorHex = colorHex
            }
        }

        public let id: String
        public let screen: ScreenID
        public let assetID: String
        public let screenRect: ScreenRect
        public let startFrame: Int
        public let endFrame: Int?
        public let loop: Bool
        public let zIndex: Int
        public let translation: Vector3?
        public let freezeAtFrame: Double?
        public let camera: CameraState?
        public let lights: [LightState]
        public let material: MaterialState?

        public init(
            id: String,
            screen: ScreenID,
            assetID: String,
            screenRect: ScreenRect,
            startFrame: Int = 0,
            endFrame: Int? = nil,
            loop: Bool = true,
            zIndex: Int,
            translation: Vector3? = nil,
            freezeAtFrame: Double? = nil,
            camera: CameraState? = nil,
            lights: [LightState] = [],
            material: MaterialState? = nil
        ) {
            self.id = id
            self.screen = screen
            self.assetID = assetID
            self.screenRect = screenRect
            self.startFrame = startFrame
            self.endFrame = endFrame
            self.loop = loop
            self.zIndex = zIndex
            self.translation = translation
            self.freezeAtFrame = freezeAtFrame
            self.camera = camera
            self.lights = lights
            self.material = material
        }
    }

    public struct TransitionCue: Codable, Equatable, Sendable {
        public let id: String
        public let kind: TransitionCueKind
        public let screen: ScreenID?
        public let targetID: String?
        public let startFrame: Int
        public let durationFrames: Int
        public let fromValue: Double?
        public let toValue: Double?
        public let fromRect: ScreenRect?
        public let toRect: ScreenRect?
        public let auxiliaryFromRect: ScreenRect?
        public let auxiliaryToRect: ScreenRect?
        public let offsetX: Double?
        public let offsetY: Double?
        public let colorHex: String?
        public let mode: Int?
        public let revealsInside: Bool?

        public init(
            id: String,
            kind: TransitionCueKind,
            screen: ScreenID? = nil,
            targetID: String? = nil,
            startFrame: Int,
            durationFrames: Int,
            fromValue: Double? = nil,
            toValue: Double? = nil,
            fromRect: ScreenRect? = nil,
            toRect: ScreenRect? = nil,
            auxiliaryFromRect: ScreenRect? = nil,
            auxiliaryToRect: ScreenRect? = nil,
            offsetX: Double? = nil,
            offsetY: Double? = nil,
            colorHex: String? = nil,
            mode: Int? = nil,
            revealsInside: Bool? = nil
        ) {
            self.id = id
            self.kind = kind
            self.screen = screen
            self.targetID = targetID
            self.startFrame = startFrame
            self.durationFrames = durationFrames
            self.fromValue = fromValue
            self.toValue = toValue
            self.fromRect = fromRect
            self.toRect = toRect
            self.auxiliaryFromRect = auxiliaryFromRect
            self.auxiliaryToRect = auxiliaryToRect
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.colorHex = colorHex
            self.mode = mode
            self.revealsInside = revealsInside
        }
    }

    public struct AudioCue: Codable, Equatable, Sendable {
        public let id: String
        public let action: AudioCueAction
        public let cueName: String
        public let frame: Int
        public let playableAssetID: String?
        public let provenance: String

        public init(
            id: String,
            action: AudioCueAction,
            cueName: String,
            frame: Int,
            playableAssetID: String? = nil,
            provenance: String
        ) {
            self.id = id
            self.action = action
            self.cueName = cueName
            self.frame = frame
            self.playableAssetID = playableAssetID
            self.provenance = provenance
        }
    }

    public struct Scene: Codable, Equatable, Sendable {
        public let id: SceneID
        public let durationFrames: Int
        public let skipAllowedFromFrame: Int?
        public let topLayers: [LayerRef]
        public let bottomLayers: [LayerRef]
        public let spriteAnimations: [SpriteAnimationRef]
        public let modelAnimations: [ModelAnimationRef]
        public let transitionCues: [TransitionCue]
        public let audioCues: [AudioCue]

        public init(
            id: SceneID,
            durationFrames: Int,
            skipAllowedFromFrame: Int? = nil,
            topLayers: [LayerRef],
            bottomLayers: [LayerRef],
            spriteAnimations: [SpriteAnimationRef],
            modelAnimations: [ModelAnimationRef],
            transitionCues: [TransitionCue],
            audioCues: [AudioCue]
        ) {
            self.id = id
            self.durationFrames = durationFrames
            self.skipAllowedFromFrame = skipAllowedFromFrame
            self.topLayers = topLayers
            self.bottomLayers = bottomLayers
            self.spriteAnimations = spriteAnimations
            self.modelAnimations = modelAnimations
            self.transitionCues = transitionCues
            self.audioCues = audioCues
        }
    }

    public let schemaVersion: Int
    public let canonicalVariant: CanonicalVariant
    public let topScreen: NativeScreen
    public let bottomScreen: NativeScreen
    public let assets: [Asset]
    public let scenes: [Scene]

    public init(
        schemaVersion: Int,
        canonicalVariant: CanonicalVariant,
        topScreen: NativeScreen,
        bottomScreen: NativeScreen,
        assets: [Asset],
        scenes: [Scene]
    ) {
        self.schemaVersion = schemaVersion
        self.canonicalVariant = canonicalVariant
        self.topScreen = topScreen
        self.bottomScreen = bottomScreen
        self.assets = assets
        self.scenes = scenes
    }
}
