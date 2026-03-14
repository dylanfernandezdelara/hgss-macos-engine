import Foundation
import SwiftUI
import HGSSCore

struct LaunchState {
    let title: String
    let details: String
    let isError: Bool

    static func load() async -> LaunchState {
        let environment = ProcessInfo.processInfo.environment
        let rootPath = environment["HGSS_REPO_ROOT"] ?? FileManager.default.currentDirectoryPath
        let stubRoot = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent("DevContent/Stub", isDirectory: true)

        do {
            let runtime = try await HGSSCoreRuntime.bootWithStubContent(stubRoot: stubRoot)
            return LaunchState(
                title: "HGSS Mac Shell",
                details: runtime.statusLine,
                isError: false
            )
        } catch {
            return LaunchState(
                title: "HGSS Mac Shell",
                details: "Failed to load stub content: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}

struct RootView: View {
    let state: LaunchState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.title)
                .font(.title2)
                .bold()
            Text(state.details)
                .font(.body)
            Divider()
            Text("This app shell stays thin. Engine/content logic belongs in root package modules.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 240)
    }
}

@main
struct HGSSMacApp: App {
    @State private var launchState = LaunchState(
        title: "HGSS Mac Shell",
        details: "Loading stub content...",
        isError: false
    )

    var body: some Scene {
        WindowGroup {
            RootView(state: launchState)
                .task {
                    launchState = await LaunchState.load()
                }
                .background(launchState.isError ? Color.red.opacity(0.08) : Color.clear)
        }
    }
}
