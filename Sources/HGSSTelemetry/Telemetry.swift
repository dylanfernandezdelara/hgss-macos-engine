import Foundation

public protocol TelemetrySink: Sendable {
    func emit(event: String) async
}

public actor MemoryTelemetry: TelemetrySink {
    private var entries: [String] = []

    public init() {}

    public func emit(event: String) async {
        entries.append(event)
    }

    public func snapshot() -> [String] {
        entries
    }
}
