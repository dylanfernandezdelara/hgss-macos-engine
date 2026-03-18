import AppKit
import Foundation
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

    enum Phase {
        case loading
        case ready(ReadyState)
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
                let controller = HGSSOpeningPlaybackController(
                    loadedBundle: loadedBundle,
                    loadedProgram: loadedProgram
                )
                let audioPlayer = HGSSOpeningAudioPlayer(loadedBundle: loadedBundle)
                controller.onAudioCue = { dispatchedCue in
                    audioPlayer.handle(dispatchedCue)
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

    func handleKeyDown(_ keyCode: UInt16) {
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
            readyState?.controller.requestTitleClearSaveExit()
        case 46:
            readyState?.controller.requestTitleMicTestExit()
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
        if [0, 2, 8, 36, 46, 76, 125, 126].contains(event.keyCode) {
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
            case let .error(message):
                ErrorView(message: message)
            }
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let viewModel = GameViewModel()
    private var window: GameWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = GameWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 960),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "HGSSMac"
        window.center()
        window.minSize = NSSize(width: 360, height: 620)
        window.delegate = self
        window.onKeyDownHandler = { [weak self] keyCode in
            self?.viewModel.handleKeyDown(keyCode)
        }
        window.contentView = NSHostingView(rootView: RootView(viewModel: viewModel))
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
