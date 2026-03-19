import AVFoundation
import Foundation
import HGSSDataModel

@MainActor
public final class HGSSOpeningAudioPlayer {
    private static let framesPerSecond: Double = 60.0

    private let loadedBundle: LoadedOpeningBundle
    private var currentBGMPlayer: AVAudioPlayer?
    private var currentBGMName: String?
    private var activeOneShots: [AVAudioPlayer]
    private var fadeOutTask: Task<Void, Never>?

    public init(loadedBundle: LoadedOpeningBundle) {
        self.loadedBundle = loadedBundle
        self.activeOneShots = []
    }

    public func handle(_ dispatchedCue: HGSSOpeningDispatchedAudioCue) {
        let cue = dispatchedCue.cue
        switch cue.action {
        case .startBGM:
            startBGM(for: cue)
        case .fadeOutBGM:
            fadeOutBGM(for: cue)
        case .stopBGM:
            stopBGM(named: cue.cueName)
        case .triggerCry:
            playOneShot(for: cue)
        }
    }

    public func stopAll() {
        fadeOutTask?.cancel()
        fadeOutTask = nil
        currentBGMPlayer?.stop()
        currentBGMPlayer = nil
        currentBGMName = nil
        for player in activeOneShots {
            player.stop()
        }
        activeOneShots.removeAll()
    }

    private func startBGM(for cue: HGSSOpeningBundle.AudioCue) {
        fadeOutTask?.cancel()
        fadeOutTask = nil

        guard let player = makePlayer(for: cue) else {
            return
        }

        if currentBGMName == cue.cueName {
            currentBGMPlayer?.setVolume(1.0, fadeDuration: 0)
            if currentBGMPlayer?.isPlaying != true {
                currentBGMPlayer?.play()
            }
            return
        }

        currentBGMPlayer?.stop()
        currentBGMPlayer = player
        currentBGMName = cue.cueName
        player.volume = 1.0
        player.numberOfLoops = -1
        player.play()
    }

    private func fadeOutBGM(for cue: HGSSOpeningBundle.AudioCue) {
        guard currentBGMName == nil || currentBGMName == cue.cueName,
              let player = currentBGMPlayer else {
            return
        }

        let durationFrames = max(1, cue.fadeDurationFrames ?? 1)
        let durationSeconds = Double(durationFrames) / Self.framesPerSecond

        fadeOutTask?.cancel()
        player.setVolume(0, fadeDuration: durationSeconds)

        let expectedCueName = currentBGMName
        fadeOutTask = Task { [weak self, weak player] in
            let nanoseconds = UInt64(durationSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard Task.isCancelled == false else {
                return
            }
            self?.finishFadeOut(expectedCueName: expectedCueName, expectedPlayer: player)
        }
    }

    private func stopBGM(named cueName: String) {
        fadeOutTask?.cancel()
        fadeOutTask = nil
        guard currentBGMName == nil || currentBGMName == cueName else {
            return
        }
        currentBGMPlayer?.stop()
        currentBGMPlayer = nil
        currentBGMName = nil
    }

    private func playOneShot(for cue: HGSSOpeningBundle.AudioCue) {
        guard let player = makePlayer(for: cue) else {
            return
        }
        player.numberOfLoops = 0
        activeOneShots.removeAll { !$0.isPlaying }
        activeOneShots.append(player)
        player.play()
    }

    private func makePlayer(for cue: HGSSOpeningBundle.AudioCue) -> AVAudioPlayer? {
        guard let playableAssetID = cue.playableAssetID,
              let assetURL = try? loadedBundle.assetURL(id: playableAssetID) else {
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: assetURL)
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    private func finishFadeOut(
        expectedCueName: String?,
        expectedPlayer: AVAudioPlayer?
    ) {
        guard currentBGMName == expectedCueName,
              currentBGMPlayer === expectedPlayer else {
            return
        }

        currentBGMPlayer?.stop()
        currentBGMPlayer = nil
        currentBGMName = nil
        fadeOutTask = nil
    }
}
