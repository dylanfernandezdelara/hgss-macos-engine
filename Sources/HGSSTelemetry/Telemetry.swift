import Foundation

public protocol TelemetrySink: Sendable {
    func emit(event: String) async
}

public actor MemoryTelemetry: TelemetrySink {
    private var entries: [String] = []
    private var counters: [String: Int] = [:]
    private let maxEntries = 256

    public init() {}

    public func emit(event: String) async {
        counters[event, default: 0] += 1
        entries.append(event)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func snapshot() -> [String] {
        entries
    }

    public func counterSnapshot() -> [String: Int] {
        counters
    }
}
