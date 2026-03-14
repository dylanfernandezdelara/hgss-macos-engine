import Foundation
import HGSSContent
import HGSSDataModel
import HGSSTelemetry

public struct HGSSCoreRuntime: Sendable {
    public let manifest: HGSSManifest
    public let contentRoot: URL
    public let telemetry: MemoryTelemetry

    public init(manifest: HGSSManifest, contentRoot: URL, telemetry: MemoryTelemetry) {
        self.manifest = manifest
        self.contentRoot = contentRoot
        self.telemetry = telemetry
    }

    public var statusLine: String {
        "Loaded \(manifest.title) (schema v\(manifest.schemaVersion), build \(manifest.build))."
    }

    public static func bootWithStubContent(stubRoot: URL) async throws -> HGSSCoreRuntime {
        let loader = StubContentLoader()
        let manifest = try loader.loadManifest(from: stubRoot)
        let telemetry = MemoryTelemetry()
        await telemetry.emit(event: "core.boot.stub")
        await telemetry.emit(event: "content.manifest.loaded")
        return HGSSCoreRuntime(manifest: manifest, contentRoot: stubRoot, telemetry: telemetry)
    }
}
