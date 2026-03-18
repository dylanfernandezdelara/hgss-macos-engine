import AppKit
import Foundation
import HGSSCore
import HGSSRender
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    struct ReadyState {
        let loadedBundle: LoadedOpeningBundle
        let loadedProgram: LoadedOpeningProgram
        let controller: HGSSOpeningPlaybackController
        let audioPlayer: HGSSOpeningAudioPlayer
    }

    struct HandoffState {
        let dispatch: HGSSOpeningMenuDispatch
        let destination: HGSSOpeningMenuDestination?
    }

    enum Phase {
        case loading
        case ready(ReadyState)
        case handoff(HandoffState)
        case error(String)
    }

    @Published private(set) var phase: Phase = .loading

    private var readyState: ReadyState?
    private var showDeveloperOverlay = false

    func boot() {
        guard readyState == nil else {
            return
        }

        phase = .loading

        Task { @MainActor in
            do {
                let contentRoot = try resolveContentRoot()
                let loadedBundle = try OpeningBundleLoader().load(from: contentRoot)
                let loadedProgram = try OpeningProgramLoader().load(from: contentRoot)
                let bootstrapState = try HGSSOpeningBootstrapLoader().load(from: contentRoot)
                let controller = HGSSOpeningPlaybackController(
                    loadedBundle: loadedBundle,
                    loadedProgram: loadedProgram,
                    bootstrapState: bootstrapState
                )
                let audioPlayer = HGSSOpeningAudioPlayer(loadedBundle: loadedBundle)
                controller.onAudioCue = { dispatchedCue in
                    audioPlayer.handle(dispatchedCue)
                }
                controller.onMenuDispatch = { [weak self, weak controller] dispatchedMenu in
                    audioPlayer.stopAll()
                    controller?.stop()
                    self?.phase = .handoff(
                        HandoffState(
                            dispatch: dispatchedMenu,
                            destination: HGSSOpeningMenuDestination(destinationID: dispatchedMenu.destinationID)
                        )
                    )
                }
                for dispatchedCue in controller.audioCueLog {
                    audioPlayer.handle(dispatchedCue)
                }
                controller.start()

                let readyState = ReadyState(
                    loadedBundle: loadedBundle,
                    loadedProgram: loadedProgram,
                    controller: controller,
                    audioPlayer: audioPlayer
                )
                self.readyState = readyState
                self.phase = .ready(readyState)
            } catch {
                phase = .error(errorMessage(for: error))
            }
        }
    }

    func shutdown() {
        readyState?.audioPlayer.stopAll()
        readyState?.controller.stop()
        readyState = nil
    }

    func rebootOpening() {
        guard let readyState else {
            return
        }

        readyState.audioPlayer.stopAll()
        readyState.controller.reset()
        readyState.controller.start()
        phase = .ready(readyState)
    }

    func handleKeyDown(_ keyCode: UInt16) {
        if case .handoff = phase {
            switch keyCode {
            case 15, 53:
                rebootOpening()
            default:
                return
            }
        }

        if let controller = readyState?.controller, controller.state.hasReachedOpeningMenuHandoff {
            switch keyCode {
            case 125:
                controller.moveCurrentMenuSelection(delta: 1)
                return
            case 126:
                controller.moveCurrentMenuSelection(delta: -1)
                return
            case 36, 76:
                controller.confirmCurrentMenuSelection()
                return
            default:
                break
            }
        }

        switch keyCode {
        case 0, 36, 76:
            readyState?.controller.requestSkip()
        case 8:
            readyState?.controller.requestProgramFlagMutations(
                [
                    "title_clear_save_requested": 1,
                    "title_mic_test_requested": 0,
                ],
                sceneID: .titleScreen,
                stateID: "title_play"
            )
        case 46:
            readyState?.controller.requestProgramFlagMutations(
                [
                    "title_mic_test_requested": 1,
                    "title_clear_save_requested": 0,
                ],
                sceneID: .titleScreen,
                stateID: "title_play"
            )
        case 2:
            if developerOverlayEnabled {
                showDeveloperOverlay.toggle()
                if case let .ready(state) = phase {
                    phase = .ready(state)
                }
            }
        default:
            return
        }
    }

    func handleBottomScreenTap() {
        if let controller = readyState?.controller, controller.state.hasReachedOpeningMenuHandoff {
            controller.confirmCurrentMenuSelection()
            return
        }
        readyState?.controller.requestSkip()
    }

    var developerOverlayEnabled: Bool {
        ProcessInfo.processInfo.environment["HGSS_OPENING_DEBUG_OVERLAY"] == "1"
    }

    var shouldShowDeveloperOverlay: Bool {
        developerOverlayEnabled && showDeveloperOverlay
    }

    private func resolveContentRoot() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let repoRoot = URL(
            fileURLWithPath: environment["HGSS_REPO_ROOT"] ?? FileManager.default.currentDirectoryPath,
            isDirectory: true
        )

        var candidates: [URL] = []
        if let override = environment["HGSS_CONTENT_ROOT"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        candidates.append(repoRoot.appendingPathComponent("Content/Local/Boot/HeartGold", isDirectory: true))

        for candidate in candidates {
            if hasOpeningContent(at: candidate) {
                return candidate
            }
        }

        throw NSError(
            domain: "HGSSMac",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "No HeartGold opening content found. Run ./scripts/run_extractor_stub.sh before launching the app."
            ]
        )
    }

    private func hasOpeningContent(at root: URL) -> Bool {
        let bundleURL = root.appendingPathComponent("opening_bundle.json", isDirectory: false)
        let programURL = root.appendingPathComponent("opening_program_ir.json", isDirectory: false)
        return FileManager.default.fileExists(atPath: bundleURL.path()) &&
            FileManager.default.fileExists(atPath: programURL.path())
    }

    private func errorMessage(for error: Error) -> String {
        let environment = ProcessInfo.processInfo.environment
        let defaultPretRoot = URL(
            fileURLWithPath: environment["HGSS_REPO_ROOT"] ?? FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
            .appendingPathComponent("External/pokeheartgold", isDirectory: true)
            .path()

        return """
        Failed to boot the HeartGold opening player: \(error.localizedDescription)

        Expected extracted content under Content/Local/Boot/HeartGold.
        Run ./scripts/run_extractor_stub.sh first.
        Optional real-save boot inputs:
        - set HGSS_SAVE_FILE to a local HeartGold save snapshot
        - or place opening_savedata.sav / opening_savedata.dsv under the content root
        - use opening_feature_flags.json for Ranger / Wii / AGB feature overrides
        For pret-backed extraction, ensure POKEHEARTGOLD_ROOT points to a local clone such as:
        \(defaultPretRoot)
        """
    }
}

private final class GameWindow: NSWindow {
    var onKeyDownHandler: ((UInt16) -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if [0, 2, 8, 15, 36, 46, 53, 76, 125, 126].contains(event.keyCode) {
            onKeyDownHandler?(event.keyCode)
            return
        }

        super.keyDown(with: event)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HeartGold Opening")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            ProgressView()
                .tint(.white)
            Text("Loading the extracted HeartGold intro movie scenes and title-screen program.")
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(28)
        .frame(minWidth: 420, minHeight: 220)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.07, blue: 0.04),
                    Color(red: 0.22, green: 0.15, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HeartGold Opening")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(28)
        .frame(minWidth: 520, minHeight: 260)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.08, blue: 0.08),
                    Color(red: 0.20, green: 0.10, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct RootView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                LoadingView()
            case let .ready(state):
                HGSSOpeningPlayerView(
                    loadedBundle: state.loadedBundle,
                    controller: state.controller,
                    showDebugOverlay: viewModel.shouldShowDeveloperOverlay,
                    onBottomScreenTap: viewModel.handleBottomScreenTap
                )
                .background(Color.black)
            case let .handoff(state):
                HandoffView(
                    state: state,
                    onReboot: viewModel.rebootOpening
                )
            case let .error(message):
                ErrorView(message: message)
            }
        }
    }
}

private struct HandoffView: View {
    let state: GameViewModel.HandoffState
    let onReboot: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(state.destination?.title ?? "Menu Handoff")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(state.destination?.subtitle ?? "Stub handoff for an unmapped main-menu destination.")
                .foregroundStyle(Color.white.opacity(0.82))

            VStack(alignment: .leading, spacing: 8) {
                Text("State: \(state.dispatch.menuStateID)")
                Text("Selection: \(state.dispatch.selectionID)")
                Text("Destination: \(state.dispatch.destinationID ?? "<none>")")
            }
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(16)
            .background(Color.black.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: onReboot) {
                Text("Restart Opening")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            Text("Press R or Escape to return to the opening flow.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.64))
        }
        .padding(28)
        .frame(minWidth: 520, minHeight: 320, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.12),
                    Color(red: 0.17, green: 0.11, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private struct OpeningWindowMetrics {
        static let nativeWidth = 256
        static let topHeight = 192
        static let bottomHeight = 192
        static let screenGap = 18
    }

    private let viewModel = GameViewModel()
    private var window: GameWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nativeContentSize = contentSize()
        let nativeFrameSize = frameSize(forContentSize: nativeContentSize)
        let window = GameWindow(
            contentRect: NSRect(origin: .zero, size: nativeContentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "HGSSMac"
        window.collectionBehavior = []
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.delegate = self
        window.onKeyDownHandler = { [weak self] keyCode in
            self?.viewModel.handleKeyDown(keyCode)
        }
        window.contentView = NSHostingView(rootView: RootView(viewModel: viewModel))
        window.minSize = nativeFrameSize
        window.maxSize = nativeFrameSize
        center(window)
        window.makeKeyAndOrderFront(nil)

        self.window = window
        viewModel.boot()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.shutdown()
    }

    private func center(_ window: NSWindow) {
        let visibleFrame = (NSScreen.main ?? window.screen)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frameSize = frameSize(forContentSize: contentSize())
        let frameOrigin = NSPoint(
            x: visibleFrame.midX - (frameSize.width / 2.0),
            y: visibleFrame.midY - (frameSize.height / 2.0)
        )
        let frame = NSRect(origin: frameOrigin, size: frameSize)
        window.setFrame(frame, display: false)
    }

    private func contentSize() -> NSSize {
        return NSSize(
            width: CGFloat(OpeningWindowMetrics.nativeWidth),
            height: CGFloat(OpeningWindowMetrics.topHeight + OpeningWindowMetrics.bottomHeight + OpeningWindowMetrics.screenGap)
        )
    }

    private func frameSize(forContentSize contentSize: NSSize) -> NSSize {
        window?.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
            ?? NSWindow.contentRect(
                forFrameRect: NSRect(origin: .zero, size: contentSize),
                styleMask: [.titled, .closable, .miniaturizable]
            ).size
    }
}

@main
struct HGSSMacApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.activate(ignoringOtherApps: true)
        application.run()
    }
}
