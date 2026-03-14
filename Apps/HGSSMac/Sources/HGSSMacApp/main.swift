import AppKit
import Foundation
import SwiftUI
import HGSSCore

@MainActor
final class GameViewModel: ObservableObject {
    enum Phase {
        case loading
        case ready(CoreSnapshot)
        case error(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var inputStatus = "Press an arrow key."

    private var runtime: HGSSCoreRuntime?
    private var snapshotTask: Task<Void, Never>?

    func boot() {
        guard runtime == nil else {
            return
        }

        let environment = ProcessInfo.processInfo.environment
        let rootPath = environment["HGSS_REPO_ROOT"] ?? FileManager.default.currentDirectoryPath
        let stubRoot = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent("DevContent/Stub", isDirectory: true)

        phase = .loading

        Task {
            do {
                let runtime = try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubRoot)
                await runtime.start()
                self.runtime = runtime
                phase = .ready(await runtime.snapshot())
                startSnapshotLoop()
            } catch {
                phase = .error("Failed to boot stub map: \(error.localizedDescription)")
            }
        }
    }

    func shutdown() {
        snapshotTask?.cancel()
        snapshotTask = nil

        let runtime = self.runtime
        self.runtime = nil
        inputStatus = "Press an arrow key."

        Task {
            await runtime?.stop()
        }
    }

    func handleKeyDown(_ keyCode: UInt16) {
        guard let direction = MovementDirection(keyCode: keyCode) else {
            return
        }

        inputStatus = "Input: \(direction.rawValue)"
#if DEBUG
        print("HGSSMac keyDown: \(direction.rawValue)")
#endif
        step(direction)
    }

    func handleKeyUp(_ keyCode: UInt16) {
        guard MovementDirection(keyCode: keyCode) != nil else {
            return
        }

        inputStatus = "Press an arrow key."
    }

    private func step(_ direction: MovementDirection) {
        let runtime = self.runtime

        Task {
            guard let runtime else {
                return
            }

            let snapshot = await runtime.send(command: .move(direction))
            await MainActor.run {
                phase = .ready(snapshot)
            }
#if DEBUG
            print("HGSSMac player: \(snapshot.playerPosition.x),\(snapshot.playerPosition.y)")
#endif
        }
    }

    private func startSnapshotLoop() {
        snapshotTask?.cancel()

        snapshotTask = Task {
            while !Task.isCancelled {
                guard let runtime else {
                    break
                }

                let snapshot = await runtime.snapshot()
                await MainActor.run {
                    phase = .ready(snapshot)
                }

                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}

private extension MovementDirection {
    init?(keyCode: UInt16) {
        switch keyCode {
        case 123:
            self = .left
        case 124:
            self = .right
        case 125:
            self = .down
        case 126:
            self = .up
        default:
            return nil
        }
    }
}

private final class GameWindow: NSWindow {
    var onArrowKeyDown: ((UInt16) -> Void)?
    var onArrowKeyUp: ((UInt16) -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if MovementDirection(keyCode: event.keyCode) != nil {
            onArrowKeyDown?(event.keyCode)
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if MovementDirection(keyCode: event.keyCode) != nil {
            onArrowKeyUp?(event.keyCode)
            return
        }

        super.keyUp(with: event)
    }
}

private struct TileCell: View {
    enum Kind {
        case open
        case blocked
        case warp
        case placement
        case player
    }

    let kind: Kind

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(borderColor.opacity(0.75), lineWidth: 1)
            )
            .frame(width: 28, height: 28)
    }

    private var fillColor: Color {
        switch kind {
        case .open:
            Color(red: 0.89, green: 0.92, blue: 0.87)
        case .blocked:
            Color(red: 0.31, green: 0.36, blue: 0.26)
        case .warp:
            Color(red: 0.37, green: 0.60, blue: 0.79)
        case .placement:
            Color(red: 0.86, green: 0.75, blue: 0.45)
        case .player:
            Color(red: 0.88, green: 0.43, blue: 0.22)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .open:
            Color(red: 0.58, green: 0.65, blue: 0.55)
        case .blocked:
            Color(red: 0.18, green: 0.21, blue: 0.15)
        case .warp:
            Color(red: 0.19, green: 0.38, blue: 0.54)
        case .placement:
            Color(red: 0.53, green: 0.42, blue: 0.15)
        case .player:
            Color(red: 0.56, green: 0.23, blue: 0.09)
        }
    }
}

private struct GameBoardView: View {
    let snapshot: CoreSnapshot
    let inputStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.title)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text(snapshot.statusLine)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.34, green: 0.37, blue: 0.31))
                Text("Arrow keys move the player. Dark tiles block movement, blue tiles are warps, and amber tiles preserve upstream placements.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(inputStatus)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.32, green: 0.36, blue: 0.30))
            }

            VStack(spacing: 4) {
                ForEach(0..<snapshot.mapHeight, id: \.self) { y in
                    HStack(spacing: 4) {
                        ForEach(0..<snapshot.mapWidth, id: \.self) { x in
                            TileCell(kind: tileKind(x: x, y: y))
                        }
                    }
                }
            }

            HStack(spacing: 14) {
                Label("Map: \(snapshot.mapName)", systemImage: "map")
                Label("ID: \(snapshot.mapID)", systemImage: "number")
                Label("Tick: \(snapshot.tick)", systemImage: "timer")
                Label("Player: \(snapshot.playerPosition.x),\(snapshot.playerPosition.y)", systemImage: "figure.walk")
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color(red: 0.26, green: 0.30, blue: 0.25))
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 460)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.95, blue: 0.90),
                    Color(red: 0.87, green: 0.91, blue: 0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func tileKind(x: Int, y: Int) -> TileCell.Kind {
        let tile = TilePosition(x: x, y: y)
        if tile == snapshot.playerPosition {
            return .player
        }

        if snapshot.blockedTiles.contains(tile) {
            return .blocked
        }

        if snapshot.warpTiles.contains(tile) {
            return .warp
        }

        if snapshot.placementTiles.contains(tile) {
            return .placement
        }

        return .open
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HGSS Mac Shell")
                .font(.title2)
                .bold()
            ProgressView()
            Text("Booting normalized New Bark content and deterministic core loop...")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 180)
    }
}

private struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HGSS Mac Shell")
                .font(.title2)
                .bold()
            Text(message)
                .foregroundStyle(.primary)
            Text("Check stub content and runtime boot path.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 180)
        .background(Color.red.opacity(0.08))
    }
}

private struct RootView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                LoadingView()
            case let .ready(snapshot):
                GameBoardView(snapshot: snapshot, inputStatus: viewModel.inputStatus)
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
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "HGSSMac"
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.onArrowKeyDown = { [weak self] keyCode in
            self?.viewModel.handleKeyDown(keyCode)
        }
        window.onArrowKeyUp = { [weak self] keyCode in
            self?.viewModel.handleKeyUp(keyCode)
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
