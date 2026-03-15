import Foundation
import HGSSContent
import HGSSDataModel

public enum MovementDirection: String, CaseIterable, Sendable {
    case up
    case down
    case left
    case right
}

public enum CoreCommand: Equatable, Sendable {
    case idle
    case move(MovementDirection)
}

public struct TilePosition: Equatable, Hashable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public func moved(_ direction: MovementDirection) -> TilePosition {
        switch direction {
        case .up:
            TilePosition(x: x, y: y - 1)
        case .down:
            TilePosition(x: x, y: y + 1)
        case .left:
            TilePosition(x: x - 1, y: y)
        case .right:
            TilePosition(x: x + 1, y: y)
        }
    }
}

public struct GameState: Equatable, Sendable {
    public let tick: Int
    public let currentMapID: String
    public let playerPosition: TilePosition

    public init(tick: Int, currentMapID: String, playerPosition: TilePosition) {
        self.tick = tick
        self.currentMapID = currentMapID
        self.playerPosition = playerPosition
    }
}

public enum GameStepOutcome: Equatable, Sendable {
    case idle
    case moved(MovementDirection)
    case blocked(MovementDirection)
}

public struct GameStepResult: Equatable, Sendable {
    public let state: GameState
    public let outcome: GameStepOutcome
    public let triggerEvents: [TriggerEvent]

    public init(
        state: GameState,
        outcome: GameStepOutcome,
        triggerEvents: [TriggerEvent] = []
    ) {
        self.state = state
        self.outcome = outcome
        self.triggerEvents = triggerEvents
    }
}

public struct CoreSnapshot: Equatable, Sendable {
    public let title: String
    public let build: String
    public let mapID: String
    public let mapName: String
    public let mapWidth: Int
    public let mapHeight: Int
    public let blockedTiles: Set<TilePosition>
    public let warpTiles: Set<TilePosition>
    public let placementTiles: Set<TilePosition>
    public let tick: Int
    public let playerPosition: TilePosition

    public var statusLine: String {
        "Tick \(tick) on \(mapName) at (\(playerPosition.x), \(playerPosition.y))."
    }

    static func make(manifest: HGSSManifest, map: NormalizedPlayableMap, state: GameState) -> CoreSnapshot {
        CoreSnapshot(
            title: manifest.title,
            build: manifest.build,
            mapID: map.id,
            mapName: map.displayName,
            mapWidth: map.width,
            mapHeight: map.height,
            blockedTiles: Set(map.blockedTiles.map { TilePosition(x: $0.x, y: $0.y) }),
            warpTiles: Set(map.warpTiles.map { TilePosition(x: $0.x, y: $0.y) }),
            placementTiles: Set(map.placementTiles.map { TilePosition(x: $0.x, y: $0.y) }),
            tick: state.tick,
            playerPosition: state.playerPosition
        )
    }
}

public struct CoreLoopConfiguration: Equatable, Sendable {
    public let tickDuration: Duration
    public let maximumCatchUpTicks: Int

    public init(tickDuration: Duration, maximumCatchUpTicks: Int) {
        self.tickDuration = tickDuration
        self.maximumCatchUpTicks = maximumCatchUpTicks
    }

    public static let gameplay = CoreLoopConfiguration(
        tickDuration: .nanoseconds(16_666_667),
        maximumCatchUpTicks: 5
    )
}
