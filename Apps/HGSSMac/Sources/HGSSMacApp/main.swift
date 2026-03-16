import AppKit
import Foundation
import HGSSCore
import HGSSRender
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    struct ReadyState {
        let loadedBundle: LoadedRenderBundle
        let presentation: HGSSDualScreenPresentation
    }

    enum Phase {
        case loading
        case ready(ReadyState)
        case error(String)
    }

    @Published private(set) var phase: Phase = .loading

    private var runtime: HGSSCoreRuntime?
    private var readyState: ReadyState?
    private var showDeveloperOverlay = false

    func boot() {
        guard runtime == nil else {
            return
        }

        phase = .loading

        Task { @MainActor in
            do {
                let contentRoot = try resolveContentRoot()
                let loadedBundle = try RenderBundleLoader().load(from: contentRoot)
                let runtime = try await HGSSCoreRuntime.bootWithStubContent(stubRoot: contentRoot)
                let snapshot = await runtime.snapshot()
                let cameraOrigin = HGSSRenderCamera.clampedOrigin(
                    for: HGSSRenderDisplayPoint(tile: snapshot.playerPosition),
                    snapshot: snapshot,
                    camera: loadedBundle.bundle.topScreen.camera
                )

                self.runtime = runtime
                self.readyState = ReadyState(
                    loadedBundle: loadedBundle,
                    presentation: HGSSDualScreenPresentation(
                        snapshot: snapshot,
                        cameraOrigin: cameraOrigin,
                        showDeveloperOverlay: self.showDeveloperOverlay
                    )
                )
                self.phase = .ready(self.readyState!)
            } catch {
                phase = .error(errorMessage(for: error))
            }
        }
    }

    func shutdown() {
        let runtime = self.runtime
        self.runtime = nil
        readyState = nil

        Task {
            await runtime?.stop()
        }
    }

    func handleKeyDown(_ keyCode: UInt16) {
        if keyCode == 2 {
            toggleDeveloperOverlay()
        }
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
        candidates.append(repoRoot.appendingPathComponent("Content/Local/StubExtract", isDirectory: true))

        for candidate in candidates {
            if hasRenderableContent(at: candidate) {
                return candidate
            }
        }

        throw NSError(
            domain: "HGSSMac",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "No renderable extracted content found. Run ./scripts/run_extractor_stub.sh before launching the app."
            ]
        )
    }

    private func hasRenderableContent(at root: URL) -> Bool {
        let manifestURL = root.appendingPathComponent("manifest.json", isDirectory: false)
        let renderBundleURL = root.appendingPathComponent("render_bundle.json", isDirectory: false)
        return FileManager.default.fileExists(atPath: manifestURL.path()) &&
            FileManager.default.fileExists(atPath: renderBundleURL.path())
    }

    private func toggleDeveloperOverlay() {
        showDeveloperOverlay.toggle()
        guard let current = readyState else {
            return
        }

        let updated = ReadyState(
            loadedBundle: current.loadedBundle,
            presentation: HGSSDualScreenPresentation(
                snapshot: current.presentation.snapshot,
                cameraOrigin: current.presentation.cameraOrigin,
                showDeveloperOverlay: showDeveloperOverlay
            )
        )
        readyState = updated
        phase = .ready(updated)
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
        Failed to boot the dual-screen shell: \(error.localizedDescription)

        Expected extracted content under Content/Local/StubExtract.
        Run ./scripts/run_extractor_stub.sh first.
        For pret-backed assets, ensure POKEHEARTGOLD_ROOT points to a local clone such as:
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
        if event.keyCode == 2 || [123, 124, 125, 126].contains(event.keyCode) {
            onKeyDownHandler?(event.keyCode)
            return
        }

        super.keyDown(with: event)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HGSS Dual-Screen Shell")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            ProgressView()
                .tint(.white)
            Text("Loading extracted New Bark parity assets and the deterministic core snapshot.")
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(28)
        .frame(minWidth: 420, minHeight: 220)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.17),
                    Color(red: 0.10, green: 0.20, blue: 0.26)
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
            Text("HGSS Dual-Screen Shell")
                .font(.system(size: 26, weight: .bold, design: .rounded))
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
                HGSSDualScreenView(
                    loadedBundle: state.loadedBundle,
                    presentation: state.presentation
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
        window.isReleasedWhenClosed = false
        window.onKeyDownHandler = { [weak self] keyCode in
            self?.viewModel.handleKeyDown(keyCode)
        }
        window.contentView = NSHostingView(rootView: RootView(viewModel: viewModel))
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        self.window = window
        viewModel.boot()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.shutdown()
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.shutdown()
    }
}

@main
struct HGSSMacApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.regular)
        application.delegate = delegate
        application.run()
    }
}
