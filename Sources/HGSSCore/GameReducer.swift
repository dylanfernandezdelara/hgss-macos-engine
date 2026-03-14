import Foundation
import HGSSContent

public enum GameReducer {
    public static func step(
        state: GameState,
        command: CoreCommand,
        map: NormalizedPlayableMap
    ) -> GameStepResult {
        let advancedTick = state.tick + 1

        switch command {
        case .idle:
            return GameStepResult(
                state: GameState(
                    tick: advancedTick,
                    currentMapID: state.currentMapID,
                    playerPosition: state.playerPosition
                ),
                outcome: .idle
            )

        case let .move(direction):
            let proposed = state.playerPosition.moved(direction)
            let proposedTile = NormalizedTileCoordinate(x: proposed.x, y: proposed.y)

            guard map.contains(proposedTile), !map.isBlocked(proposedTile) else {
                return GameStepResult(
                    state: GameState(
                        tick: advancedTick,
                        currentMapID: state.currentMapID,
                        playerPosition: state.playerPosition
                    ),
                    outcome: .blocked(direction)
                )
            }

            return GameStepResult(
                state: GameState(
                    tick: advancedTick,
                    currentMapID: state.currentMapID,
                    playerPosition: proposed
                ),
                outcome: .moved(direction)
            )
        }
    }
}
