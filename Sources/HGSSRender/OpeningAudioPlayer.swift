import AVFoundation
import Foundation
import HGSSDataModel

@MainActor
public final class HGSSOpeningAudioPlayer {
    private let loadedBundle: LoadedOpeningBundle
    private var currentBGMPlayer: AVAudioPlayer?
    private var currentBGMName: String?
    private var activeOneShots: [AVAudioPlayer]

    public init(loadedBundle: LoadedOpeningBundle) {
        self.loadedBundle = loadedBundle
        self.activeOneShots = []
    }

    public func handle(_ dispatchedCue: HGSSOpeningDispatchedAudioCue) {
        let cue = dispatchedCue.cue
        switch cue.action {
        case .startBGM:
            startBGM(for: cue)
        case .stopBGM:
            stopBGM(named: cue.cueName)
        case .triggerCry:
            playOneShot(for: cue)
        }
    }

    public func stopAll() {
        currentBGMPlayer?.stop()
        currentBGMPlayer = nil
        currentBGMName = nil
        for player in activeOneShots {
            player.stop()
        }
        activeOneShots.removeAll()
    }

    private func startBGM(for cue: HGSSOpeningBundle.AudioCue) {
        guard let player = makePlayer(for: cue) else {
            return
        }

        if currentBGMName == cue.cueName {
            if currentBGMPlayer?.isPlaying != true {
                currentBGMPlayer?.play()
            }
            return
        }

        currentBGMPlayer?.stop()
        currentBGMPlayer = player
        currentBGMName = cue.cueName
        player.numberOfLoops = -1
        player.play()
    }

    private func stopBGM(named cueName: String) {
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
}
