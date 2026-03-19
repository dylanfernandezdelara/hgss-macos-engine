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

    public init(saveSummary: HGSSOpeningSaveSummary) {
        self.init(
            checkSaveStatus: saveSummary.checkSaveStatus,
            mainMenu: saveSummary.mainMenuAvailability
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
    public static let saveSummaryFilename = "opening_save_summary.json"
    public static let bootstrapFilename = "opening_bootstrap_state.json"

    public init() {}

    public func load(
        from root: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> HGSSOpeningBootstrapState {
        if let saveSummary = try HGSSOpeningLocalSaveSummaryLoader().load(from: root, environment: environment) {
            return HGSSOpeningBootstrapState(saveSummary: saveSummary)
        }

        let saveSummaryURL = root.appendingPathComponent(Self.saveSummaryFilename, isDirectory: false)
        if FileManager.default.fileExists(atPath: saveSummaryURL.path()) {
            let data = try Data(contentsOf: saveSummaryURL)
            let summary = try JSONDecoder().decode(HGSSOpeningSaveSummary.self, from: data)
            return HGSSOpeningBootstrapState(saveSummary: summary)
        }

        let bootstrapURL = root.appendingPathComponent(Self.bootstrapFilename, isDirectory: false)
        guard FileManager.default.fileExists(atPath: bootstrapURL.path()) else {
            return .noSave
        }

        let data = try Data(contentsOf: bootstrapURL)
        return try JSONDecoder().decode(HGSSOpeningBootstrapState.self, from: data)
    }
}
