import Foundation

// Source-backed opening/title behavior that sits between parsed C and the native runtime.
public struct HGSSOpeningProgramIR: Codable, Equatable, Sendable {
    public enum SceneID: String, Codable, Equatable, Sendable, CaseIterable {
        case scene1
        case scene2
        case scene3
        case scene4
        case scene5
        case titleHandoff = "title_handoff"
        case titleScreen = "title_screen"
    }

    public enum ScreenID: String, Codable, Equatable, Sendable {
        case top
        case bottom
    }

    public struct SourceLocationSpan: Codable, Equatable, Sendable {
        public let startLine: Int
        public let endLine: Int
        public let startColumn: Int?
        public let endColumn: Int?

        public init(
            startLine: Int,
            endLine: Int,
            startColumn: Int? = nil,
            endColumn: Int? = nil
        ) {
            self.startLine = startLine
            self.endLine = endLine
            self.startColumn = startColumn
            self.endColumn = endColumn
        }
    }

    public struct Provenance: Codable, Equatable, Sendable {
        public let sourceFile: String
        public let symbol: String?
        public let lineSpan: SourceLocationSpan?

        public init(
            sourceFile: String,
            symbol: String? = nil,
            lineSpan: SourceLocationSpan? = nil
        ) {
            self.sourceFile = sourceFile
            self.symbol = symbol
            self.lineSpan = lineSpan
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

    public struct Scene: Codable, Equatable, Sendable {
        public let id: SceneID
        public let initialStateID: String
        public let states: [State]
        public let provenance: Provenance

        public init(
            id: SceneID,
            initialStateID: String,
            states: [State],
            provenance: Provenance
        ) {
            self.id = id
            self.initialStateID = initialStateID
            self.states = states
            self.provenance = provenance
        }
    }

    public struct State: Codable, Equatable, Sendable {
        public let id: String
        public let duration: Duration
        public let commands: [Command]
        public let transitions: [Transition]
        public let provenance: Provenance

        public init(
            id: String,
            duration: Duration,
            commands: [Command],
            transitions: [Transition],
            provenance: Provenance
        ) {
            self.id = id
            self.duration = duration
            self.commands = commands
            self.transitions = transitions
            self.provenance = provenance
        }
    }

    public enum Duration: Codable, Equatable, Sendable {
        case fixedFrames(Int)
        case indefinite

        private enum CodingKeys: String, CodingKey {
            case kind
            case frames
        }

        private enum Kind: String, Codable {
            case fixedFrames = "fixed_frames"
            case indefinite
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(Kind.self, forKey: .kind) {
            case .fixedFrames:
                self = .fixedFrames(try container.decode(Int.self, forKey: .frames))
            case .indefinite:
                self = .indefinite
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .fixedFrames(frames):
                try container.encode(Kind.fixedFrames, forKey: .kind)
                try container.encode(frames, forKey: .frames)
            case .indefinite:
                try container.encode(Kind.indefinite, forKey: .kind)
            }
        }
    }

    public struct Transition: Codable, Equatable, Sendable {
        public let trigger: Trigger
        public let targetStateID: String
        public let provenance: Provenance

        public init(
            trigger: Trigger,
            targetStateID: String,
            provenance: Provenance
        ) {
            self.trigger = trigger
            self.targetStateID = targetStateID
            self.provenance = provenance
        }
    }

    public enum Trigger: Codable, Equatable, Sendable {
        case stateCompleted
        case frameEquals(Int)
        case frameAtLeast(Int)
        case flagEquals(name: String, value: Int)

        private enum CodingKeys: String, CodingKey {
            case kind
            case frame
            case flagName
            case flagValue
        }

        private enum Kind: String, Codable {
            case stateCompleted = "state_completed"
            case frameEquals = "frame_equals"
            case frameAtLeast = "frame_at_least"
            case flagEquals = "flag_equals"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(Kind.self, forKey: .kind) {
            case .stateCompleted:
                self = .stateCompleted
            case .frameEquals:
                self = .frameEquals(try container.decode(Int.self, forKey: .frame))
            case .frameAtLeast:
                self = .frameAtLeast(try container.decode(Int.self, forKey: .frame))
            case .flagEquals:
                self = .flagEquals(
                    name: try container.decode(String.self, forKey: .flagName),
                    value: try container.decode(Int.self, forKey: .flagValue)
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .stateCompleted:
                try container.encode(Kind.stateCompleted, forKey: .kind)
            case let .frameEquals(frame):
                try container.encode(Kind.frameEquals, forKey: .kind)
                try container.encode(frame, forKey: .frame)
            case let .frameAtLeast(frame):
                try container.encode(Kind.frameAtLeast, forKey: .kind)
                try container.encode(frame, forKey: .frame)
            case let .flagEquals(name, value):
                try container.encode(Kind.flagEquals, forKey: .kind)
                try container.encode(name, forKey: .flagName)
                try container.encode(value, forKey: .flagValue)
            }
        }
    }

    public struct LayerVisibilityCommand: Codable, Equatable, Sendable {
        public let layerID: String
        public let visible: Bool
        public let provenance: Provenance

        public init(layerID: String, visible: Bool, provenance: Provenance) {
            self.layerID = layerID
            self.visible = visible
            self.provenance = provenance
        }
    }

    public struct ScrollCommand: Codable, Equatable, Sendable {
        public let targetID: String
        public let deltaX: Int
        public let deltaY: Int
        public let durationFrames: Int
        public let provenance: Provenance

        public init(
            targetID: String,
            deltaX: Int,
            deltaY: Int,
            durationFrames: Int,
            provenance: Provenance
        ) {
            self.targetID = targetID
            self.deltaX = deltaX
            self.deltaY = deltaY
            self.durationFrames = durationFrames
            self.provenance = provenance
        }
    }

    public struct WindowMaskCommand: Codable, Equatable, Sendable {
        public let screen: ScreenID
        public let rect: ScreenRect?
        public let provenance: Provenance

        public init(screen: ScreenID, rect: ScreenRect?, provenance: Provenance) {
            self.screen = screen
            self.rect = rect
            self.provenance = provenance
        }
    }

    public struct FadeCommand: Codable, Equatable, Sendable {
        public enum Target: String, Codable, Equatable, Sendable {
            case palette
            case alphaBlend = "alpha_blend"
        }

        public let target: Target
        public let startLevel: Int
        public let endLevel: Int
        public let durationFrames: Int
        public let provenance: Provenance

        public init(
            target: Target,
            startLevel: Int,
            endLevel: Int,
            durationFrames: Int,
            provenance: Provenance
        ) {
            self.target = target
            self.startLevel = startLevel
            self.endLevel = endLevel
            self.durationFrames = durationFrames
            self.provenance = provenance
        }
    }

    public struct BrightnessCommand: Codable, Equatable, Sendable {
        public let screen: ScreenID
        public let startLevel: Int
        public let endLevel: Int
        public let durationFrames: Int
        public let provenance: Provenance

        public init(
            screen: ScreenID,
            startLevel: Int,
            endLevel: Int,
            durationFrames: Int,
            provenance: Provenance
        ) {
            self.screen = screen
            self.startLevel = startLevel
            self.endLevel = endLevel
            self.durationFrames = durationFrames
            self.provenance = provenance
        }
    }

    public struct AudioCommand: Codable, Equatable, Sendable {
        public enum Action: String, Codable, Equatable, Sendable {
            case startBGM = "start_bgm"
            case stopBGM = "stop_bgm"
            case triggerSFX = "trigger_sfx"
        }

        public let action: Action
        public let cueName: String
        public let provenance: Provenance

        public init(action: Action, cueName: String, provenance: Provenance) {
            self.action = action
            self.cueName = cueName
            self.provenance = provenance
        }
    }

    public struct ScreenSwapCommand: Codable, Equatable, Sendable {
        public let enabled: Bool
        public let provenance: Provenance

        public init(enabled: Bool, provenance: Provenance) {
            self.enabled = enabled
            self.provenance = provenance
        }
    }

    public struct PromptFlashCommand: Codable, Equatable, Sendable {
        public enum InitialPhase: String, Codable, Equatable, Sendable {
            case visible
            case hidden
        }

        public let targetID: String
        public let visibleFrames: Int
        public let hiddenFrames: Int
        public let initialPhase: InitialPhase
        public let provenance: Provenance

        public init(
            targetID: String,
            visibleFrames: Int,
            hiddenFrames: Int,
            initialPhase: InitialPhase,
            provenance: Provenance
        ) {
            self.targetID = targetID
            self.visibleFrames = visibleFrames
            self.hiddenFrames = hiddenFrames
            self.initialPhase = initialPhase
            self.provenance = provenance
        }
    }

    public enum Command: Codable, Equatable, Sendable {
        case setLayerVisibility(LayerVisibilityCommand)
        case scroll(ScrollCommand)
        case setWindowMask(WindowMaskCommand)
        case fade(FadeCommand)
        case setBrightness(BrightnessCommand)
        case dispatchAudio(AudioCommand)
        case setScreenSwap(ScreenSwapCommand)
        case setPromptFlash(PromptFlashCommand)

        private enum CodingKeys: String, CodingKey {
            case kind
            case layerVisibility
            case scroll
            case windowMask
            case fade
            case brightness
            case audio
            case screenSwap
            case promptFlash
        }

        private enum Kind: String, Codable {
            case setLayerVisibility = "set_layer_visibility"
            case scroll
            case setWindowMask = "set_window_mask"
            case fade
            case setBrightness = "set_brightness"
            case dispatchAudio = "dispatch_audio"
            case setScreenSwap = "set_screen_swap"
            case setPromptFlash = "set_prompt_flash"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(Kind.self, forKey: .kind) {
            case .setLayerVisibility:
                self = .setLayerVisibility(
                    try container.decode(LayerVisibilityCommand.self, forKey: .layerVisibility)
                )
            case .scroll:
                self = .scroll(try container.decode(ScrollCommand.self, forKey: .scroll))
            case .setWindowMask:
                self = .setWindowMask(try container.decode(WindowMaskCommand.self, forKey: .windowMask))
            case .fade:
                self = .fade(try container.decode(FadeCommand.self, forKey: .fade))
            case .setBrightness:
                self = .setBrightness(try container.decode(BrightnessCommand.self, forKey: .brightness))
            case .dispatchAudio:
                self = .dispatchAudio(try container.decode(AudioCommand.self, forKey: .audio))
            case .setScreenSwap:
                self = .setScreenSwap(try container.decode(ScreenSwapCommand.self, forKey: .screenSwap))
            case .setPromptFlash:
                self = .setPromptFlash(try container.decode(PromptFlashCommand.self, forKey: .promptFlash))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .setLayerVisibility(command):
                try container.encode(Kind.setLayerVisibility, forKey: .kind)
                try container.encode(command, forKey: .layerVisibility)
            case let .scroll(command):
                try container.encode(Kind.scroll, forKey: .kind)
                try container.encode(command, forKey: .scroll)
            case let .setWindowMask(command):
                try container.encode(Kind.setWindowMask, forKey: .kind)
                try container.encode(command, forKey: .windowMask)
            case let .fade(command):
                try container.encode(Kind.fade, forKey: .kind)
                try container.encode(command, forKey: .fade)
            case let .setBrightness(command):
                try container.encode(Kind.setBrightness, forKey: .kind)
                try container.encode(command, forKey: .brightness)
            case let .dispatchAudio(command):
                try container.encode(Kind.dispatchAudio, forKey: .kind)
                try container.encode(command, forKey: .audio)
            case let .setScreenSwap(command):
                try container.encode(Kind.setScreenSwap, forKey: .kind)
                try container.encode(command, forKey: .screenSwap)
            case let .setPromptFlash(command):
                try container.encode(Kind.setPromptFlash, forKey: .kind)
                try container.encode(command, forKey: .promptFlash)
            }
        }
    }

    public let schemaVersion: Int
    public let entrySceneID: SceneID
    public let sourceFiles: [String]
    public let scenes: [Scene]

    public init(
        schemaVersion: Int,
        entrySceneID: SceneID,
        sourceFiles: [String],
        scenes: [Scene]
    ) {
        self.schemaVersion = schemaVersion
        self.entrySceneID = entrySceneID
        self.sourceFiles = sourceFiles
        self.scenes = scenes
    }

    public func validate() throws {
        guard schemaVersion > 0 else {
            throw HGSSOpeningIRValidationError.invalidSchemaVersion(schemaVersion)
        }
        guard sourceFiles.isEmpty == false else {
            throw HGSSOpeningIRValidationError.missingSourceFiles
        }

        var seenSceneIDs = Set<SceneID>()
        for scene in scenes {
            guard seenSceneIDs.insert(scene.id).inserted else {
                throw HGSSOpeningIRValidationError.duplicateSceneID(scene.id)
            }
            try validate(scene: scene)
        }

        guard seenSceneIDs.contains(entrySceneID) else {
            throw HGSSOpeningIRValidationError.missingEntryScene(entrySceneID)
        }
    }

    private func validate(scene: Scene) throws {
        guard scene.initialStateID.isEmpty == false else {
            throw HGSSOpeningIRValidationError.emptyInitialState(scene.id)
        }
        guard scene.states.isEmpty == false else {
            throw HGSSOpeningIRValidationError.emptyStates(scene.id)
        }

        try validate(provenance: scene.provenance)

        var stateIDs = Set<String>()
        for state in scene.states {
            guard state.id.isEmpty == false else {
                throw HGSSOpeningIRValidationError.emptyStateID(scene.id)
            }
            guard stateIDs.insert(state.id).inserted else {
                throw HGSSOpeningIRValidationError.duplicateStateID(scene.id, state.id)
            }
        }

        guard stateIDs.contains(scene.initialStateID) else {
            throw HGSSOpeningIRValidationError.missingInitialState(scene.id, scene.initialStateID)
        }

        for state in scene.states {
            try validate(state: state, sceneID: scene.id, validStateIDs: stateIDs)
        }
    }

    private func validate(
        state: State,
        sceneID: SceneID,
        validStateIDs: Set<String>
    ) throws {
        try validate(provenance: state.provenance)

        switch state.duration {
        case let .fixedFrames(frames):
            guard frames > 0 else {
                throw HGSSOpeningIRValidationError.invalidFixedDuration(sceneID, state.id, frames)
            }
        case .indefinite:
            break
        }

        for transition in state.transitions {
            guard validStateIDs.contains(transition.targetStateID) else {
                throw HGSSOpeningIRValidationError.missingTransitionTarget(
                    sceneID,
                    state.id,
                    transition.targetStateID
                )
            }
            try validate(provenance: transition.provenance)
            try validate(trigger: transition.trigger, sceneID: sceneID, stateID: state.id)
        }

        for command in state.commands {
            try validate(command: command, sceneID: sceneID, stateID: state.id)
        }
    }

    private func validate(
        trigger: Trigger,
        sceneID: SceneID,
        stateID: String
    ) throws {
        switch trigger {
        case .stateCompleted:
            return
        case let .frameEquals(frame), let .frameAtLeast(frame):
            guard frame >= 0 else {
                throw HGSSOpeningIRValidationError.negativeTriggerFrame(sceneID, stateID, frame)
            }
        case let .flagEquals(name, _):
            guard name.isEmpty == false else {
                throw HGSSOpeningIRValidationError.emptyTriggerFlagName(sceneID, stateID)
            }
        }
    }

    private func validate(
        command: Command,
        sceneID: SceneID,
        stateID: String
    ) throws {
        switch command {
        case let .setLayerVisibility(payload):
            guard payload.layerID.isEmpty == false else {
                throw HGSSOpeningIRValidationError.emptyCommandIdentifier(sceneID, stateID, "layerID")
            }
            try validate(provenance: payload.provenance)
        case let .scroll(payload):
            guard payload.targetID.isEmpty == false else {
                throw HGSSOpeningIRValidationError.emptyCommandIdentifier(sceneID, stateID, "targetID")
            }
            guard payload.durationFrames > 0 else {
                throw HGSSOpeningIRValidationError.invalidCommandDuration(
                    sceneID,
                    stateID,
                    "scroll",
                    payload.durationFrames
                )
            }
            try validate(provenance: payload.provenance)
        case let .setWindowMask(payload):
            if let rect = payload.rect {
                guard rect.width > 0, rect.height > 0 else {
                    throw HGSSOpeningIRValidationError.invalidWindowMaskRect(sceneID, stateID)
                }
            }
            try validate(provenance: payload.provenance)
        case let .fade(payload):
            guard payload.durationFrames > 0 else {
                throw HGSSOpeningIRValidationError.invalidCommandDuration(
                    sceneID,
                    stateID,
                    "fade",
                    payload.durationFrames
                )
            }
            try validate(provenance: payload.provenance)
        case let .setBrightness(payload):
            guard payload.durationFrames > 0 else {
                throw HGSSOpeningIRValidationError.invalidCommandDuration(
                    sceneID,
                    stateID,
                    "brightness",
                    payload.durationFrames
                )
            }
            try validate(provenance: payload.provenance)
        case let .dispatchAudio(payload):
            guard payload.cueName.isEmpty == false else {
                throw HGSSOpeningIRValidationError.emptyCommandIdentifier(sceneID, stateID, "cueName")
            }
            try validate(provenance: payload.provenance)
        case let .setScreenSwap(payload):
            try validate(provenance: payload.provenance)
        case let .setPromptFlash(payload):
            guard payload.targetID.isEmpty == false else {
                throw HGSSOpeningIRValidationError.emptyCommandIdentifier(sceneID, stateID, "targetID")
            }
            guard payload.visibleFrames > 0 else {
                throw HGSSOpeningIRValidationError.invalidCommandDuration(
                    sceneID,
                    stateID,
                    "promptFlash.visible",
                    payload.visibleFrames
                )
            }
            guard payload.hiddenFrames > 0 else {
                throw HGSSOpeningIRValidationError.invalidCommandDuration(
                    sceneID,
                    stateID,
                    "promptFlash.hidden",
                    payload.hiddenFrames
                )
            }
            try validate(provenance: payload.provenance)
        }
    }

    private func validate(provenance: Provenance) throws {
        guard provenance.sourceFile.isEmpty == false else {
            throw HGSSOpeningIRValidationError.emptyProvenanceFile
        }
        if let lineSpan = provenance.lineSpan {
            guard lineSpan.startLine > 0, lineSpan.endLine > 0, lineSpan.endLine >= lineSpan.startLine else {
                throw HGSSOpeningIRValidationError.invalidLineSpan(provenance.sourceFile)
            }
            if let startColumn = lineSpan.startColumn, startColumn <= 0 {
                throw HGSSOpeningIRValidationError.invalidLineSpan(provenance.sourceFile)
            }
            if let endColumn = lineSpan.endColumn, endColumn <= 0 {
                throw HGSSOpeningIRValidationError.invalidLineSpan(provenance.sourceFile)
            }
        }
    }
}

public enum HGSSOpeningIRValidationError: Error, LocalizedError, Equatable, Sendable {
    case invalidSchemaVersion(Int)
    case missingSourceFiles
    case missingEntryScene(HGSSOpeningProgramIR.SceneID)
    case duplicateSceneID(HGSSOpeningProgramIR.SceneID)
    case emptyInitialState(HGSSOpeningProgramIR.SceneID)
    case emptyStates(HGSSOpeningProgramIR.SceneID)
    case emptyStateID(HGSSOpeningProgramIR.SceneID)
    case duplicateStateID(HGSSOpeningProgramIR.SceneID, String)
    case missingInitialState(HGSSOpeningProgramIR.SceneID, String)
    case invalidFixedDuration(HGSSOpeningProgramIR.SceneID, String, Int)
    case missingTransitionTarget(HGSSOpeningProgramIR.SceneID, String, String)
    case negativeTriggerFrame(HGSSOpeningProgramIR.SceneID, String, Int)
    case emptyTriggerFlagName(HGSSOpeningProgramIR.SceneID, String)
    case emptyCommandIdentifier(HGSSOpeningProgramIR.SceneID, String, String)
    case invalidCommandDuration(HGSSOpeningProgramIR.SceneID, String, String, Int)
    case invalidWindowMaskRect(HGSSOpeningProgramIR.SceneID, String)
    case emptyProvenanceFile
    case invalidLineSpan(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidSchemaVersion(version):
            return "Opening IR schemaVersion must be positive, got \(version)."
        case .missingSourceFiles:
            return "Opening IR must record at least one source file."
        case let .missingEntryScene(sceneID):
            return "Opening IR entry scene \(sceneID.rawValue) is missing from the scene set."
        case let .duplicateSceneID(sceneID):
            return "Opening IR contains duplicate scene id \(sceneID.rawValue)."
        case let .emptyInitialState(sceneID):
            return "Opening IR scene \(sceneID.rawValue) is missing an initial state id."
        case let .emptyStates(sceneID):
            return "Opening IR scene \(sceneID.rawValue) must contain at least one state."
        case let .emptyStateID(sceneID):
            return "Opening IR scene \(sceneID.rawValue) contains an empty state id."
        case let .duplicateStateID(sceneID, stateID):
            return "Opening IR scene \(sceneID.rawValue) contains duplicate state id \(stateID)."
        case let .missingInitialState(sceneID, stateID):
            return "Opening IR scene \(sceneID.rawValue) initial state \(stateID) is missing."
        case let .invalidFixedDuration(sceneID, stateID, frames):
            return "Opening IR scene \(sceneID.rawValue) state \(stateID) has invalid fixed duration \(frames)."
        case let .missingTransitionTarget(sceneID, stateID, targetStateID):
            return "Opening IR scene \(sceneID.rawValue) state \(stateID) transitions to missing state \(targetStateID)."
        case let .negativeTriggerFrame(sceneID, stateID, frame):
            return "Opening IR scene \(sceneID.rawValue) state \(stateID) uses negative trigger frame \(frame)."
        case let .emptyTriggerFlagName(sceneID, stateID):
            return "Opening IR scene \(sceneID.rawValue) state \(stateID) uses an empty trigger flag name."
        case let .emptyCommandIdentifier(sceneID, stateID, field):
            return "Opening IR scene \(sceneID.rawValue) state \(stateID) uses an empty \(field) command field."
        case let .invalidCommandDuration(sceneID, stateID, kind, frames):
            return "Opening IR scene \(sceneID.rawValue) state \(stateID) uses invalid \(kind) duration \(frames)."
        case let .invalidWindowMaskRect(sceneID, stateID):
            return "Opening IR scene \(sceneID.rawValue) state \(stateID) uses a non-positive window mask rect."
        case .emptyProvenanceFile:
            return "Opening IR provenance sourceFile must not be empty."
        case let .invalidLineSpan(path):
            return "Opening IR provenance line span is invalid for \(path)."
        }
    }
}
