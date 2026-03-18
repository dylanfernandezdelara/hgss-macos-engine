import Foundation
import HGSSCore
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
    @Published public private(set) var currentMenuSelectionID: String?
    @Published public private(set) var lastConfirmedMenuSelectionID: String?
    @Published public private(set) var lastConfirmedMenuDestinationID: String?

    private var playbackTask: Task<Void, Never>?
    private var dispatchedCueKeys: Set<String>
    private let bootstrapProgramFlags: [String: Int]
    private var programFlags: [String: Int]

    public init(
        loadedBundle: LoadedOpeningBundle,
        loadedProgram: LoadedOpeningProgram? = nil,
        bootstrapState: HGSSOpeningBootstrapState = .noSave
    ) {
        self.loadedBundle = loadedBundle
        self.loadedProgram = loadedProgram
        self.state = HGSSOpeningPlaybackState(sceneIndex: 0, frameInScene: 0, hasReachedTitleHandoff: false)
        self.audioCueLog = []
        self.currentMenuSelectionID = nil
        self.lastConfirmedMenuSelectionID = nil
        self.lastConfirmedMenuDestinationID = nil
        self.dispatchedCueKeys = []
        self.bootstrapProgramFlags = bootstrapState.programFlags()
        self.programFlags = Self.defaultProgramFlags(overrides: self.bootstrapProgramFlags)
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
        currentMenuSelectionID = nil
        lastConfirmedMenuSelectionID = nil
        lastConfirmedMenuDestinationID = nil
        programFlags = Self.defaultProgramFlags(overrides: bootstrapProgramFlags)
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
        if state.hasReachedOpeningMenuHandoff {
            confirmCurrentMenuSelection()
            return
        }

        if currentProgramScene != nil {
            if requestProgramFlagTransition(flagName: "program_confirm_requested", value: 1) {
                return
            }
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

    public func requestTitleClearSaveExit() {
        guard currentProgramScene?.id == .titleScreen,
              currentProgramState?.id == "title_play" else {
            return
        }
        programFlags["title_clear_save_requested"] = 1
        programFlags["title_mic_test_requested"] = 0
    }

    public func requestTitleMicTestExit() {
        guard currentProgramScene?.id == .titleScreen,
              currentProgramState?.id == "title_play" else {
            return
        }
        programFlags["title_mic_test_requested"] = 1
        programFlags["title_clear_save_requested"] = 0
    }

    public func setProgramFlag(name: String, value: Int) {
        programFlags[name] = value
        if currentProgramScene != nil,
           let transition = automaticTransitionForCurrentProgramState() {
            transitionToProgramState(transition)
        } else {
            syncMenuSelectionForCurrentProgramState()
        }
    }

    public func moveCurrentMenuSelection(delta: Int) {
        guard delta != 0,
              let menu = activeMenu(screen: .bottom) ?? activeMenu(screen: .top) else {
            return
        }

        let enabledOptions = menu.options.filter(\.enabled)
        guard enabledOptions.isEmpty == false else {
            return
        }

        let selectedID = currentMenuSelectionID ?? menu.selectedOptionID
        let currentIndex = enabledOptions.firstIndex(where: { $0.id == selectedID }) ?? 0
        let nextIndex = (currentIndex + delta).positiveModulo(enabledOptions.count)
        currentMenuSelectionID = enabledOptions[nextIndex].id
    }

    public func confirmCurrentMenuSelection() {
        guard let menu = activeMenu(screen: .bottom) ?? activeMenu(screen: .top) else {
            return
        }

        let selectedID = currentMenuSelectionID ?? menu.selectedOptionID
        guard menu.options.contains(where: { $0.id == selectedID && $0.enabled }) else {
            return
        }

        lastConfirmedMenuSelectionID = selectedID
        lastConfirmedMenuDestinationID = menu.options.first(where: { $0.id == selectedID })?.destinationID
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
            return resolvedMenu(payload)
        }.last
    }

    public func resolvedMenuSelectionID(
        for menu: HGSSOpeningProgramIR.MenuCommand
    ) -> String {
        currentMenuSelectionID ?? menu.selectedOptionID
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
        currentMenuSelectionID = nil
        lastConfirmedMenuSelectionID = nil
        lastConfirmedMenuDestinationID = nil
        state = HGSSOpeningPlaybackState(
            sceneIndex: sceneIndex,
            frameInScene: 0,
            hasReachedTitleHandoff: reachedTitleHandoff
        )

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

        applyEntryFlagMutationsIfNeeded()
        dispatchProgramAudioCommandsIfNeeded()
        syncMenuSelectionForCurrentProgramState()

        if let transition = automaticTransitionForCurrentProgramState() {
            transitionToProgramState(transition, sceneFrame: sceneFrame)
        }
    }

    private func transitionToProgramState(
        _ transition: HGSSOpeningProgramIR.Transition,
        sceneFrame: Int? = nil
    ) {
        let nextSceneID = transition.targetSceneID ?? state.programSceneID ?? .titleScreen
        if let bundleSceneIndex = bundleSceneIndex(for: nextSceneID) {
            currentMenuSelectionID = nil
            lastConfirmedMenuSelectionID = nil
            dispatchedCueKeys.removeAll()
            enterBundleScene(sceneIndex: bundleSceneIndex)
            return
        }
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
        return programState.transitions.first(where: { evaluate(trigger: $0.trigger) })
    }

    private func syncMenuSelectionForCurrentProgramState() {
        guard let menu = activeMenu(screen: .bottom) ?? activeMenu(screen: .top) else {
            currentMenuSelectionID = nil
            return
        }

        let enabledOptions = menu.options.filter(\.enabled)
        guard enabledOptions.isEmpty == false else {
            currentMenuSelectionID = nil
            return
        }

        if let currentMenuSelectionID,
           enabledOptions.contains(where: { $0.id == currentMenuSelectionID }) {
            return
        }

        if enabledOptions.contains(where: { $0.id == menu.selectedOptionID }) {
            currentMenuSelectionID = menu.selectedOptionID
        } else {
            currentMenuSelectionID = enabledOptions[0].id
        }
    }

    private func resolvedMenu(
        _ menu: HGSSOpeningProgramIR.MenuCommand
    ) -> HGSSOpeningProgramIR.MenuCommand? {
        let visibleOptions = menu.options.filter(isMenuOptionVisible)
        guard visibleOptions.isEmpty == false else {
            return nil
        }

        let selectedOptionID: String
        if visibleOptions.contains(where: { $0.id == menu.selectedOptionID }) {
            selectedOptionID = menu.selectedOptionID
        } else {
            selectedOptionID = visibleOptions[0].id
        }

        return .init(
            screen: menu.screen,
            options: visibleOptions,
            selectedOptionID: selectedOptionID,
            provenance: menu.provenance
        )
    }

    private func isMenuOptionVisible(
        _ option: HGSSOpeningProgramIR.MenuOption
    ) -> Bool {
        option.requiredFlags.allSatisfy { requirement in
            programFlags[requirement.name] == requirement.value
        }
    }

    private func requestProgramFlagTransition(flagName: String, value: Int) -> Bool {
        guard let programState = currentProgramState,
              let transition = programState.transitions.first(where: {
                  if case let .flagEquals(name, expectedValue) = $0.trigger {
                      return name == flagName && expectedValue == value
                  }
                  return false
              }) else {
            return false
        }

        programFlags[flagName] = value
        transitionToProgramState(transition)
        return true
    }

    private func applyEntryFlagMutationsIfNeeded() {
        guard let programState = currentProgramState else {
            return
        }

        for command in programState.commands {
            guard case let .mutateFlag(payload) = command else {
                continue
            }
            switch payload.operation {
            case .assign:
                programFlags[payload.flagName] = payload.value
            case .clearBits:
                let currentValue = programFlags[payload.flagName] ?? 0
                programFlags[payload.flagName] = currentValue & ~payload.value
            case .xorBits:
                let currentValue = programFlags[payload.flagName] ?? 0
                programFlags[payload.flagName] = currentValue ^ payload.value
            }
        }
    }

    private func evaluate(trigger: HGSSOpeningProgramIR.Trigger) -> Bool {
        switch trigger {
        case .stateCompleted, .frameEquals, .frameAtLeast:
            return false
        case let .flagEquals(name, value):
            return programFlags[name] == value
        case let .flagBitSet(name, mask):
            return ((programFlags[name] ?? 0) & mask) != 0
        }
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

    private func bundleSceneIndex(
        for sceneID: HGSSOpeningProgramIR.SceneID
    ) -> Int? {
        let bundleSceneID: HGSSOpeningBundle.SceneID
        switch sceneID {
        case .scene1:
            bundleSceneID = .scene1
        case .scene2:
            bundleSceneID = .scene2
        case .scene3:
            bundleSceneID = .scene3
        case .scene4:
            bundleSceneID = .scene4
        case .scene5:
            bundleSceneID = .scene5
        case .titleHandoff, .titleScreen, .deleteSave, .micTest, .checkSave, .mainMenu:
            return nil
        }

        return loadedBundle.bundle.scenes.firstIndex(where: { $0.id == bundleSceneID })
    }

    private static func defaultProgramFlags(overrides: [String: Int] = [:]) -> [String: Int] {
        [
            "title_anim_initialized": 1,
            "check_save_status_flags": 0,
            "program_confirm_requested": 0,
            "main_menu_has_save_data": 0,
            "main_menu_has_pokedex": 0,
            "main_menu_draw_mystery_gift": 0,
            "main_menu_draw_ranger": 0,
            "main_menu_draw_connect_to_wii": 0,
            "main_menu_connected_agb_game": 0,
        ].merging(overrides) { _, override in override }
    }
}

private extension Int {
    func positiveModulo(_ modulus: Int) -> Int {
        let remainder = self % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}
