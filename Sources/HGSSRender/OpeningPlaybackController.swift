import Foundation
import HGSSDataModel
import HGSSOpeningIR
import SwiftUI

public struct HGSSOpeningDispatchedAudioCue: Equatable, Sendable {
    public let sceneID: HGSSOpeningBundle.SceneID
    public let cue: HGSSOpeningBundle.AudioCue

    public init(sceneID: HGSSOpeningBundle.SceneID, cue: HGSSOpeningBundle.AudioCue) {
        self.sceneID = sceneID
        self.cue = cue
    }
}

public struct HGSSOpeningPlaybackState: Equatable, Sendable {
    public let sceneIndex: Int
    public let frameInScene: Int
    public let hasReachedTitleHandoff: Bool
    public let programSceneID: HGSSOpeningProgramIR.SceneID?
    public let programStateID: String?
    public let frameInProgramState: Int
    public let hasReachedOpeningMenuHandoff: Bool

    public init(
        sceneIndex: Int,
        frameInScene: Int,
        hasReachedTitleHandoff: Bool,
        programSceneID: HGSSOpeningProgramIR.SceneID? = nil,
        programStateID: String? = nil,
        frameInProgramState: Int = 0,
        hasReachedOpeningMenuHandoff: Bool = false
    ) {
        self.sceneIndex = sceneIndex
        self.frameInScene = frameInScene
        self.hasReachedTitleHandoff = hasReachedTitleHandoff
        self.programSceneID = programSceneID
        self.programStateID = programStateID
        self.frameInProgramState = frameInProgramState
        self.hasReachedOpeningMenuHandoff = hasReachedOpeningMenuHandoff
    }
}

@MainActor
public final class HGSSOpeningPlaybackController: ObservableObject {
    public static let framesPerSecond: Double = 60.0
    private static let frameDurationNanoseconds: UInt64 = 16_666_667
    private static let titlePromptLayerID = "start_prompt"

    public private(set) var loadedBundle: LoadedOpeningBundle
    public private(set) var loadedProgram: LoadedOpeningProgram?
    public var onAudioCue: ((HGSSOpeningDispatchedAudioCue) -> Void)?

    @Published public private(set) var state: HGSSOpeningPlaybackState
    @Published public private(set) var audioCueLog: [HGSSOpeningDispatchedAudioCue]

    private var playbackTask: Task<Void, Never>?
    private var dispatchedCueKeys: Set<String>
    private var pendingTitleMenuRequest = false
    private var programFlags: [String: Int]

    public init(
        loadedBundle: LoadedOpeningBundle,
        loadedProgram: LoadedOpeningProgram? = nil
    ) {
        self.loadedBundle = loadedBundle
        self.loadedProgram = loadedProgram
        self.state = HGSSOpeningPlaybackState(sceneIndex: 0, frameInScene: 0, hasReachedTitleHandoff: false)
        self.audioCueLog = []
        self.dispatchedCueKeys = []
        self.programFlags = Self.defaultProgramFlags()
        dispatchBundleAudioCuesForCurrentFrameIfNeeded()
    }

    deinit {
        playbackTask?.cancel()
    }

    public var currentScene: HGSSOpeningBundle.Scene {
        loadedBundle.bundle.scenes[state.sceneIndex]
    }

    public var currentProgramScene: HGSSOpeningProgramIR.Scene? {
        guard let sceneID = state.programSceneID else {
            return nil
        }
        return loadedProgram?.program.scenes.first(where: { $0.id == sceneID })
    }

    public var currentProgramState: HGSSOpeningProgramIR.State? {
        guard let programStateID = state.programStateID else {
            return nil
        }
        return currentProgramScene?.states.first(where: { $0.id == programStateID })
    }

    public func start() {
        guard playbackTask == nil else {
            return
        }

        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.frameDurationNanoseconds)
                self?.advanceFrame()
            }
        }
    }

    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil
    }

    public func reset() {
        stop()
        dispatchedCueKeys.removeAll()
        audioCueLog = []
        pendingTitleMenuRequest = false
        programFlags = Self.defaultProgramFlags()
        state = HGSSOpeningPlaybackState(sceneIndex: 0, frameInScene: 0, hasReachedTitleHandoff: false)
        dispatchBundleAudioCuesForCurrentFrameIfNeeded()
    }

    public func advanceFrame() {
        guard state.hasReachedOpeningMenuHandoff == false else {
            return
        }

        if currentProgramScene != nil {
            advanceProgramFrame()
            return
        }

        let scene = currentScene
        if state.frameInScene + 1 < scene.durationFrames {
            state = HGSSOpeningPlaybackState(
                sceneIndex: state.sceneIndex,
                frameInScene: state.frameInScene + 1,
                hasReachedTitleHandoff: state.hasReachedTitleHandoff,
                hasReachedOpeningMenuHandoff: state.hasReachedOpeningMenuHandoff
            )
            dispatchBundleAudioCuesForCurrentFrameIfNeeded()
            return
        }

        if state.sceneIndex == loadedBundle.bundle.scenes.count - 1 {
            return
        }

        let nextSceneIndex = min(state.sceneIndex + 1, loadedBundle.bundle.scenes.count - 1)
        enterBundleScene(sceneIndex: nextSceneIndex)
    }

    public func requestSkip() {
        if currentProgramScene?.id == .titleScreen {
            guard currentProgramState?.id == "title_play" else {
                return
            }
            pendingTitleMenuRequest = true
            return
        }

        let scene = currentScene
        guard let skipAllowedFromFrame = scene.skipAllowedFromFrame,
              state.frameInScene >= skipAllowedFromFrame else {
            return
        }

        let titleSceneIndex = loadedBundle.bundle.scenes.firstIndex(where: { $0.id == .titleHandoff }) ?? loadedBundle.bundle.scenes.count - 1
        enterBundleScene(sceneIndex: titleSceneIndex)
    }

    public func isProgramLayerVisible(_ layerID: String) -> Bool? {
        guard let programState = currentProgramState else {
            return nil
        }

        for command in programState.commands.reversed() {
            switch command {
            case let .setLayerVisibility(payload) where payload.layerID == layerID:
                return payload.visible
            case let .setPromptFlash(payload) where payload.targetID == layerID:
                return isPromptVisible(payload)
            default:
                continue
            }
        }

        return nil
    }

    public func activePromptFlashCommand(
        targetID: String = "start_prompt"
    ) -> HGSSOpeningProgramIR.PromptFlashCommand? {
        currentProgramState?.commands.compactMap { command in
            guard case let .setPromptFlash(payload) = command, payload.targetID == targetID else {
                return nil
            }
            return payload
        }.first
    }

    public func activeSolidFill(
        screen: HGSSOpeningProgramIR.ScreenID
    ) -> HGSSOpeningProgramIR.SolidFillCommand? {
        currentProgramState?.commands.compactMap { command in
            guard case let .setSolidFill(payload) = command, payload.screen == screen else {
                return nil
            }
            return payload
        }.last
    }

    public func activeMessageBox(
        screen: HGSSOpeningProgramIR.ScreenID
    ) -> HGSSOpeningProgramIR.MessageBoxCommand? {
        currentProgramState?.commands.compactMap { command in
            guard case let .setMessageBox(payload) = command, payload.screen == screen else {
                return nil
            }
            return payload
        }.last
    }

    public func activeMenu(
        screen: HGSSOpeningProgramIR.ScreenID
    ) -> HGSSOpeningProgramIR.MenuCommand? {
        currentProgramState?.commands.compactMap { command in
            guard case let .setMenu(payload) = command, payload.screen == screen else {
                return nil
            }
            return payload
        }.last
    }

    public func activeProgramFadeOverlay() -> (colorHex: String, opacity: Double)? {
        guard let programState = currentProgramState else {
            return nil
        }
        guard let fade = programState.commands.compactMap({ command -> HGSSOpeningProgramIR.FadeCommand? in
            guard case let .fade(payload) = command else {
                return nil
            }
            return payload
        }).last else {
            return nil
        }

        let progress = transitionProgress(
            durationFrames: fade.durationFrames,
            frame: state.frameInProgramState
        )
        let interpolatedLevel = interpolate(
            from: Double(fade.startLevel),
            to: Double(fade.endLevel),
            progress: progress
        )
        let opacity = max(0.0, min(interpolatedLevel / 31.0, 1.0))
        return (fade.colorHex ?? "#000000", opacity)
    }

    private func advanceProgramFrame() {
        guard let programState = currentProgramState else {
            return
        }

        if pendingTitleMenuRequest,
           let transition = programState.transitions.first(where: { transition in
               if case .flagEquals(name: "title_menu_requested", value: 1) = transition.trigger {
                   return true
               }
               return false
           }) {
            pendingTitleMenuRequest = false
            transitionToProgramState(transition)
            return
        }

        if let transition = automaticTransitionForCurrentProgramState() {
            transitionToProgramState(transition)
            return
        }

        let nextProgramFrame = state.frameInProgramState + 1
        let nextSceneFrame = state.frameInScene + 1
        if case let .fixedFrames(durationFrames) = programState.duration,
           nextProgramFrame >= durationFrames {
            if let transition = programState.transitions.first(where: { $0.trigger == .stateCompleted }) {
                transitionToProgramState(
                    transition,
                    sceneFrame: nextSceneFrame
                )
                return
            }

            state = HGSSOpeningPlaybackState(
                sceneIndex: state.sceneIndex,
                frameInScene: nextSceneFrame,
                hasReachedTitleHandoff: true,
                programSceneID: state.programSceneID,
                programStateID: state.programStateID,
                frameInProgramState: state.frameInProgramState,
                hasReachedOpeningMenuHandoff: state.hasReachedOpeningMenuHandoff
            )
            return
        }

        state = HGSSOpeningPlaybackState(
            sceneIndex: state.sceneIndex,
            frameInScene: nextSceneFrame,
            hasReachedTitleHandoff: true,
            programSceneID: state.programSceneID,
            programStateID: state.programStateID,
            frameInProgramState: nextProgramFrame,
            hasReachedOpeningMenuHandoff: false
        )
    }

    private func enterBundleScene(sceneIndex: Int) {
        let scene = loadedBundle.bundle.scenes[sceneIndex]
        let reachedTitleHandoff = scene.id == .titleHandoff
        state = HGSSOpeningPlaybackState(
            sceneIndex: sceneIndex,
            frameInScene: 0,
            hasReachedTitleHandoff: reachedTitleHandoff
        )
        pendingTitleMenuRequest = false

        if reachedTitleHandoff,
           let titleScene = loadedProgram?.program.scenes.first(where: { $0.id == .titleScreen }) {
            enterProgramState(sceneID: titleScene.id, stateID: titleScene.initialStateID)
            return
        }

        dispatchBundleAudioCuesForCurrentFrameIfNeeded()
    }

    private func enterProgramState(
        sceneID: HGSSOpeningProgramIR.SceneID,
        stateID: String,
        sceneFrame: Int = 0,
        frameInProgramState: Int = 0
    ) {
        let reachedOpeningMenu = isOpeningMenuState(sceneID: sceneID, stateID: stateID)
        state = HGSSOpeningPlaybackState(
            sceneIndex: state.sceneIndex,
            frameInScene: sceneFrame,
            hasReachedTitleHandoff: true,
            programSceneID: sceneID,
            programStateID: stateID,
            frameInProgramState: frameInProgramState,
            hasReachedOpeningMenuHandoff: reachedOpeningMenu
        )

        dispatchProgramAudioCommandsIfNeeded()

        if let transition = automaticTransitionForCurrentProgramState() {
            transitionToProgramState(transition, sceneFrame: sceneFrame)
        }
    }

    private func transitionToProgramState(
        _ transition: HGSSOpeningProgramIR.Transition,
        sceneFrame: Int? = nil
    ) {
        let nextSceneID = transition.targetSceneID ?? state.programSceneID ?? .titleScreen
        let nextSceneFrame = sceneFrame ?? state.frameInScene
        enterProgramState(
            sceneID: nextSceneID,
            stateID: transition.targetStateID,
            sceneFrame: nextSceneFrame
        )
    }

    private func automaticTransitionForCurrentProgramState() -> HGSSOpeningProgramIR.Transition? {
        guard let programState = currentProgramState else {
            return nil
        }
        return programState.transitions.first(where: { transition in
            if case let .flagEquals(name, value) = transition.trigger {
                return programFlags[name] == value
            }
            return false
        })
    }

    private func dispatchBundleAudioCuesForCurrentFrameIfNeeded() {
        let scene = currentScene
        guard !(scene.id == .titleHandoff && currentProgramScene != nil) else {
            return
        }

        for cue in scene.audioCues where cue.frame == state.frameInScene {
            let key = "bundle:\(scene.id.rawValue):\(cue.id):\(cue.frame)"
            guard dispatchedCueKeys.insert(key).inserted else {
                continue
            }
            let dispatchedCue = HGSSOpeningDispatchedAudioCue(sceneID: scene.id, cue: cue)
            audioCueLog.append(dispatchedCue)
            onAudioCue?(dispatchedCue)
        }
    }

    private func dispatchProgramAudioCommandsIfNeeded() {
        guard let programState = currentProgramState else {
            return
        }

        for command in programState.commands {
            guard case let .dispatchAudio(payload) = command else {
                continue
            }
            let key = "program:\(state.programSceneID?.rawValue ?? "unknown"):\(programState.id):\(payload.action.rawValue):\(payload.cueName)"
            guard dispatchedCueKeys.insert(key).inserted else {
                continue
            }

            let dispatchedCue = HGSSOpeningDispatchedAudioCue(
                sceneID: currentScene.id,
                cue: syntheticAudioCue(from: payload)
            )
            audioCueLog.append(dispatchedCue)
            onAudioCue?(dispatchedCue)
        }
    }

    private func syntheticAudioCue(
        from payload: HGSSOpeningProgramIR.AudioCommand
    ) -> HGSSOpeningBundle.AudioCue {
        let matchingAction: HGSSOpeningBundle.AudioCueAction
        switch payload.action {
        case .startBGM:
            matchingAction = .startBGM
        case .stopBGM:
            matchingAction = .stopBGM
        case .triggerSFX:
            matchingAction = .triggerCry
        }

        let playableAssetID = loadedBundle.bundle.scenes
            .flatMap(\.audioCues)
            .first(where: { $0.action == matchingAction && $0.cueName == payload.cueName })?
            .playableAssetID

        return .init(
            id: "program_\(payload.action.rawValue)_\(payload.cueName.lowercased())",
            action: matchingAction,
            cueName: payload.cueName,
            frame: state.frameInScene,
            playableAssetID: playableAssetID,
            provenance: payload.provenance.sourceFile
        )
    }

    private func isPromptVisible(
        _ prompt: HGSSOpeningProgramIR.PromptFlashCommand
    ) -> Bool {
        let cycleFrames = max(1, prompt.visibleFrames + prompt.hiddenFrames)
        let phaseFrame = state.frameInProgramState % cycleFrames
        switch prompt.initialPhase {
        case .visible:
            return phaseFrame < prompt.visibleFrames
        case .hidden:
            return phaseFrame >= prompt.hiddenFrames
        }
    }

    private func transitionProgress(
        durationFrames: Int,
        frame: Int
    ) -> Double {
        guard durationFrames > 0 else {
            return 1.0
        }
        let relativeFrame = max(1, min(frame + 1, durationFrames))
        return Double(relativeFrame) / Double(durationFrames)
    }

    private func interpolate(from: Double, to: Double, progress: Double) -> Double {
        from + ((to - from) * progress)
    }

    private func isOpeningMenuState(
        sceneID: HGSSOpeningProgramIR.SceneID,
        stateID: String
    ) -> Bool {
        guard
            let scene = loadedProgram?.program.scenes.first(where: { $0.id == sceneID }),
            let programState = scene.states.first(where: { $0.id == stateID })
        else {
            return false
        }

        return programState.commands.contains { command in
            if case .setMenu = command {
                return true
            }
            return false
        }
    }

    private static func defaultProgramFlags() -> [String: Int] {
        [
            "title_anim_initialized": 1,
            "check_save_message_index": -1,
            "main_menu_has_save_data": 0,
        ]
    }
}
