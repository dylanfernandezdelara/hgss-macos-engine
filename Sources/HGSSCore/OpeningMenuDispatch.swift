import Foundation

public struct HGSSOpeningMenuDispatch: Equatable, Sendable {
    public let menuStateID: String
    public let selectionID: String
    public let destinationID: String?

    public init(
        menuStateID: String,
        selectionID: String,
        destinationID: String?
    ) {
        self.menuStateID = menuStateID
        self.selectionID = selectionID
        self.destinationID = destinationID
    }
}
