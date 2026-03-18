import Foundation
import HGSSDataModel
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

    public init(sceneIndex: Int, frameInScene: Int, hasReachedTitleHandoff: Bool) {
        self.sceneIndex = sceneIndex
        self.frameInScene = frameInScene
        self.hasReachedTitleHandoff = hasReachedTitleHandoff
    }
}

@MainActor
public final class HGSSOpeningPlaybackController: ObservableObject {
    public static let framesPerSecond: Double = 60.0
    private static let frameDurationNanoseconds: UInt64 = 16_666_667

    public private(set) var loadedBundle: LoadedOpeningBundle
    public var onAudioCue: ((HGSSOpeningDispatchedAudioCue) -> Void)?

    @Published public private(set) var state: HGSSOpeningPlaybackState
    @Published public private(set) var audioCueLog: [HGSSOpeningDispatchedAudioCue]

    private var playbackTask: Task<Void, Never>?
    private var dispatchedCueKeys: Set<String>

    public init(loadedBundle: LoadedOpeningBundle) {
        self.loadedBundle = loadedBundle
        self.state = HGSSOpeningPlaybackState(sceneIndex: 0, frameInScene: 0, hasReachedTitleHandoff: false)
        self.audioCueLog = []
        self.dispatchedCueKeys = []
        dispatchAudioCuesForCurrentFrameIfNeeded()
    }

    deinit {
        playbackTask?.cancel()
    }

    public var currentScene: HGSSOpeningBundle.Scene {
        loadedBundle.bundle.scenes[state.sceneIndex]
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
        state = HGSSOpeningPlaybackState(sceneIndex: 0, frameInScene: 0, hasReachedTitleHandoff: false)
        dispatchAudioCuesForCurrentFrameIfNeeded()
    }

    public func advanceFrame() {
        guard !state.hasReachedTitleHandoff else {
            return
        }

        let scene = currentScene
        if state.frameInScene + 1 < scene.durationFrames {
            state = HGSSOpeningPlaybackState(
                sceneIndex: state.sceneIndex,
                frameInScene: state.frameInScene + 1,
                hasReachedTitleHandoff: false
            )
            dispatchAudioCuesForCurrentFrameIfNeeded()
            return
        }

        let nextSceneIndex = min(state.sceneIndex + 1, loadedBundle.bundle.scenes.count - 1)
        let reachedTitleHandoff = loadedBundle.bundle.scenes[nextSceneIndex].id == .titleHandoff
        state = HGSSOpeningPlaybackState(
            sceneIndex: nextSceneIndex,
            frameInScene: 0,
            hasReachedTitleHandoff: reachedTitleHandoff
        )
        dispatchAudioCuesForCurrentFrameIfNeeded()
    }

    public func requestSkip() {
        let scene = currentScene
        guard let skipAllowedFromFrame = scene.skipAllowedFromFrame,
              state.frameInScene >= skipAllowedFromFrame else {
            return
        }

        let titleSceneIndex = loadedBundle.bundle.scenes.firstIndex(where: { $0.id == .titleHandoff }) ?? loadedBundle.bundle.scenes.count - 1
        state = HGSSOpeningPlaybackState(
            sceneIndex: titleSceneIndex,
            frameInScene: 0,
            hasReachedTitleHandoff: true
        )
        dispatchAudioCuesForCurrentFrameIfNeeded()
    }

    private func dispatchAudioCuesForCurrentFrameIfNeeded() {
        let scene = currentScene
        for cue in scene.audioCues where cue.frame == state.frameInScene {
            let key = "\(scene.id.rawValue):\(cue.id):\(cue.frame)"
            guard dispatchedCueKeys.insert(key).inserted else {
                continue
            }
            let dispatchedCue = HGSSOpeningDispatchedAudioCue(sceneID: scene.id, cue: cue)
            audioCueLog.append(dispatchedCue)
            onAudioCue?(dispatchedCue)
        }
    }
}
