import HGSSContent

public struct TriggerEvent: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case object
        case coordinateTrigger
        case backgroundEvent
    }

    public struct MapContext: Equatable, Sendable {
        public let mapID: String
        public let mapName: String
        public let upstreamMapID: String
        public let eventsBank: String

        public init(
            mapID: String,
            mapName: String,
            upstreamMapID: String,
            eventsBank: String
        ) {
            self.mapID = mapID
            self.mapName = mapName
            self.upstreamMapID = upstreamMapID
            self.eventsBank = eventsBank
        }
    }

    public struct Identity: Equatable, Sendable {
        public let id: String
        public let kind: Kind
        public let localPosition: TilePosition
        public let width: Int
        public let height: Int
        public let scriptReference: String?

        public init(
            id: String,
            kind: Kind,
            localPosition: TilePosition,
            width: Int,
            height: Int,
            scriptReference: String?
        ) {
            self.id = id
            self.kind = kind
            self.localPosition = localPosition
            self.width = width
            self.height = height
            self.scriptReference = scriptReference
        }
    }

    public let tick: Int
    public let playerPosition: TilePosition
    public let map: MapContext
    public let trigger: Identity

    public init(
        tick: Int,
        playerPosition: TilePosition,
        map: MapContext,
        trigger: Identity
    ) {
        self.tick = tick
        self.playerPosition = playerPosition
        self.map = map
        self.trigger = trigger
    }
}

public struct CoreTickResult: Equatable, Sendable {
    public let snapshot: CoreSnapshot
    public let outcome: GameStepOutcome
    public let triggerEvents: [TriggerEvent]

    public init(
        snapshot: CoreSnapshot,
        outcome: GameStepOutcome,
        triggerEvents: [TriggerEvent]
    ) {
        self.snapshot = snapshot
        self.outcome = outcome
        self.triggerEvents = triggerEvents
    }
}

extension TriggerEvent {
    static func triggerHit(
        tick: Int,
        playerPosition: TilePosition,
        map: NormalizedPlayableMap,
        placement: NormalizedMapPlacement
    ) -> TriggerEvent {
        TriggerEvent(
            tick: tick,
            playerPosition: playerPosition,
            map: MapContext(map: map),
            trigger: Identity(placement: placement)
        )
    }
}

private extension TriggerEvent.MapContext {
    init(map: NormalizedPlayableMap) {
        self.init(
            mapID: map.id,
            mapName: map.displayName,
            upstreamMapID: map.provenance.upstreamMapID,
            eventsBank: map.provenance.eventsBank
        )
    }
}

private extension TriggerEvent.Identity {
    init(placement: NormalizedMapPlacement) {
        self.init(
            id: placement.id,
            kind: TriggerEvent.Kind(placement.kind),
            localPosition: TilePosition(
                x: placement.localPosition.x,
                y: placement.localPosition.y
            ),
            width: placement.width,
            height: placement.height,
            scriptReference: placement.scriptReference
        )
    }
}

private extension TriggerEvent.Kind {
    init(_ placementKind: NormalizedPlacementKind) {
        switch placementKind {
        case .object:
            self = .object
        case .coordinateTrigger:
            self = .coordinateTrigger
        case .backgroundEvent:
            self = .backgroundEvent
        }
    }
}
