import Foundation
import HGSSContent
import HGSSTelemetry

public actor HGSSCoreRuntime {
    private let contentRoot: URL
    private let content: NormalizedWorldContent
    private let telemetry: MemoryTelemetry
    private let loopConfiguration: CoreLoopConfiguration

    private var heldCommand: CoreCommand = .idle
    private var state: GameState
    private var latestSnapshot: CoreSnapshot
    private var loopTask: Task<Void, Never>?

    private init(
        contentRoot: URL,
        content: NormalizedWorldContent,
        telemetry: MemoryTelemetry,
        loopConfiguration: CoreLoopConfiguration,
        initialState: GameState
    ) {
        self.contentRoot = contentRoot
        self.content = content
        self.telemetry = telemetry
        self.loopConfiguration = loopConfiguration
        self.state = initialState
        self.latestSnapshot = CoreSnapshot.make(
            manifest: content.manifest,
            map: content.initialMap,
            state: initialState
        )
    }

    public static func bootWithStubContent(
        stubRoot: URL,
        loopConfiguration: CoreLoopConfiguration = .gameplay
    ) async throws -> HGSSCoreRuntime {
        let loader = StubContentLoader()
        let content = try loader.loadPlayableContent(from: stubRoot)
        let telemetry = MemoryTelemetry()
        let initialMap = content.initialMap
        let initialEntryPoint = content.initialEntryPoint
        let initialState = GameState(
            tick: 0,
            currentMapID: initialMap.id,
            playerPosition: TilePosition(
                x: initialEntryPoint.localPosition.x,
                y: initialEntryPoint.localPosition.y
            ),
            playerFacing: MovementDirection(facingToken: initialEntryPoint.facing) ?? .down
        )

        await telemetry.emit(event: "core.boot.stub")
        await telemetry.emit(event: "content.manifest.loaded")
        await telemetry.emit(event: "content.map.normalized.ready")

        return HGSSCoreRuntime(
            contentRoot: stubRoot,
            content: content,
            telemetry: telemetry,
            loopConfiguration: loopConfiguration,
            initialState: initialState
        )
    }

    public func start() {
        guard loopTask == nil else {
            return
        }

        loopTask = Task { [loopConfiguration] in
            let clock = ContinuousClock()
            var lastInstant = clock.now
            var accumulator: Duration = .zero

            while !Task.isCancelled {
                let now = clock.now
                accumulator += lastInstant.duration(to: now)
                lastInstant = now

                var steps = 0
                while accumulator >= loopConfiguration.tickDuration && steps < loopConfiguration.maximumCatchUpTicks {
                    await self.advanceOneTick()
                    accumulator -= loopConfiguration.tickDuration
                    steps += 1
                }

                if accumulator >= loopConfiguration.tickDuration {
                    accumulator = .zero
                    await self.telemetry.emit(event: "loop.catchup.clamped")
                }

                let sleepDuration = loopConfiguration.tickDuration - accumulator
                if sleepDuration > .zero {
                    try? await Task.sleep(for: sleepDuration)
                } else {
                    await Task.yield()
                }
            }
        }
    }

    public func stop() {
        let task = loopTask
        loopTask = nil
        task?.cancel()
    }

    public func setHeldDirection(_ direction: MovementDirection?) {
        heldCommand = direction.map(CoreCommand.move) ?? .idle
    }

    @discardableResult
    public func send(command: CoreCommand) async -> CoreSnapshot {
        let result = await sendStep(command: command)
        return result.snapshot
    }

    @discardableResult
    public func advanceOneTick() async -> CoreSnapshot {
        let result = await advanceOneTickResult()
        return result.snapshot
    }

    @discardableResult
    public func sendStep(command: CoreCommand) async -> CoreTickResult {
        await apply(command: command)
    }

    @discardableResult
    public func advanceOneTickResult() async -> CoreTickResult {
        await apply(command: heldCommand)
    }

    private func apply(command: CoreCommand) async -> CoreTickResult {
        guard let map = content.map(id: state.currentMapID) else {
            await telemetry.emit(event: "content.map.missing")
            return CoreTickResult(snapshot: latestSnapshot, outcome: .idle, triggerEvents: [])
        }

        let result = GameReducer.step(state: state, command: command, map: map)
        state = result.state
        latestSnapshot = CoreSnapshot.make(manifest: content.manifest, map: map, state: state)

        await telemetry.emit(event: "tick.advance")
        switch result.outcome {
        case .idle:
            break
        case .moved:
            await telemetry.emit(event: "movement.accepted")
        case .blocked:
            await telemetry.emit(event: "movement.blocked")
        }

        return CoreTickResult(
            snapshot: latestSnapshot,
            outcome: result.outcome,
            triggerEvents: result.triggerEvents
        )
    }

    public func snapshot() -> CoreSnapshot {
        latestSnapshot
    }

    public func telemetryCounters() async -> [String: Int] {
        await telemetry.counterSnapshot()
    }

    public func contentPath() -> String {
        contentRoot.path()
    }
}
