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

    public static let noSave = HGSSOpeningBootstrapState()

    public func programFlags() -> [String: Int] {
        [
            "check_save_status_flags": checkSaveStatusFlags,
            "main_menu_has_save_data": mainMenuHasSaveData ? 1 : 0,
            "main_menu_has_pokedex": mainMenuHasPokedex ? 1 : 0,
            "main_menu_draw_mystery_gift": drawMysteryGift ? 1 : 0,
            "main_menu_draw_ranger": drawRanger ? 1 : 0,
            "main_menu_draw_connect_to_wii": drawConnectToWii ? 1 : 0,
            "main_menu_connected_agb_game": connectedAgbGame,
        ]
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
