import Foundation

public struct HGSSOpeningBootstrapState: Codable, Equatable, Sendable {
    public let checkSaveStatusFlags: Int
    public let mainMenuHasSaveData: Bool
    public let mainMenuHasPokedex: Bool
    public let drawMysteryGift: Bool
    public let drawRanger: Bool
    public let drawConnectToWii: Bool
    public let connectedAgbGame: Int

    public init(
        checkSaveStatusFlags: Int = 0,
        mainMenuHasSaveData: Bool = false,
        mainMenuHasPokedex: Bool = false,
        drawMysteryGift: Bool = false,
        drawRanger: Bool = false,
        drawConnectToWii: Bool = false,
        connectedAgbGame: Int = 0
    ) {
        self.checkSaveStatusFlags = checkSaveStatusFlags
        self.mainMenuHasSaveData = mainMenuHasSaveData
        self.mainMenuHasPokedex = mainMenuHasPokedex
        self.drawMysteryGift = drawMysteryGift
        self.drawRanger = drawRanger
        self.drawConnectToWii = drawConnectToWii
        self.connectedAgbGame = connectedAgbGame
    }

    public init(
        checkSaveStatus: HGSSCheckSaveStatus = [],
        mainMenu: HGSSOpeningMainMenuAvailability = .noSave
    ) {
        self.init(
            checkSaveStatusFlags: checkSaveStatus.rawValue,
            mainMenuHasSaveData: mainMenu.hasSaveData,
            mainMenuHasPokedex: mainMenu.hasPokedex,
            drawMysteryGift: mainMenu.drawMysteryGift,
            drawRanger: mainMenu.drawRanger,
            drawConnectToWii: mainMenu.drawConnectToWii,
            connectedAgbGame: mainMenu.connectedAGBGame.rawValue
        )
    }

    public static let noSave = HGSSOpeningBootstrapState()

    public var checkSaveStatus: HGSSCheckSaveStatus {
        HGSSCheckSaveStatus(rawValue: checkSaveStatusFlags)
    }

    public var mainMenuAvailability: HGSSOpeningMainMenuAvailability {
        HGSSOpeningMainMenuAvailability(
            hasSaveData: mainMenuHasSaveData,
            hasPokedex: mainMenuHasPokedex,
            drawMysteryGift: drawMysteryGift,
            drawRanger: drawRanger,
            drawConnectToWii: drawConnectToWii,
            connectedAGBGame: HGSSOpeningAGBGame(rawValue: connectedAgbGame) ?? .none
        )
    }

    public var postTitleState: HGSSOpeningPostTitleState {
        HGSSOpeningPostTitleState(
            checkSaveStatus: checkSaveStatus,
            mainMenu: mainMenuAvailability
        )
    }

    public func programFlags() -> [String: Int] {
        postTitleState.programFlags
    }
}

public struct HGSSOpeningBootstrapLoader: Sendable {
    public init() {}

    public func load(from root: URL) throws -> HGSSOpeningBootstrapState {
        let fileURL = root.appendingPathComponent("opening_bootstrap_state.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return .noSave
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(HGSSOpeningBootstrapState.self, from: data)
    }
}
