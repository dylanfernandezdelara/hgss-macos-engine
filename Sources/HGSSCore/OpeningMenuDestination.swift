import Foundation

public enum HGSSOpeningMenuDestination: String, CaseIterable, Equatable, Sendable {
    case continueGame = "ov36_App_MainMenu_SelectOption_Continue"
    case newGame = "ov36_App_MainMenu_SelectOption_NewGame"
    case connectToPokewalker = "ov112_App_MainMenu_SelectOption_ConnectToPokewalker"
    case mysteryGift = "gApp_MainMenu_SelectOption_MysteryGift"
    case connectToRanger = "gApp_MainMenu_SelectOption_ConnectToRanger"
    case migrateFromAgb = "gApp_MainMenu_SelectOption_MigrateFromAgb"
    case connectToWii = "sub_02027098:data/eoo.dat"
    case nintendoWFCSetup = "gApp_MainMenu_SelectOption_NintendoWFCSetup"
    case wiiMessageSettings = "ov75_App_MainMenu_SelectOption_WiiMessageSettings"

    public init?(destinationID: String?) {
        guard let destinationID else {
            return nil
        }
        self.init(rawValue: destinationID)
    }

    public var title: String {
        switch self {
        case .continueGame:
            return "Continue"
        case .newGame:
            return "New Game"
        case .connectToPokewalker:
            return "Pokewalker"
        case .mysteryGift:
            return "Mystery Gift"
        case .connectToRanger:
            return "Connect To Ranger"
        case .migrateFromAgb:
            return "Migrate From AGB"
        case .connectToWii:
            return "Connect To Wii"
        case .nintendoWFCSetup:
            return "Nintendo WFC Setup"
        case .wiiMessageSettings:
            return "Wii Message Settings"
        }
    }

    public var subtitle: String {
        switch self {
        case .continueGame:
            return "Stub handoff for the continue overlay path."
        case .newGame:
            return "Stub handoff for the new game confirmation path."
        case .connectToPokewalker:
            return "Stub handoff for the Pokewalker connection flow."
        case .mysteryGift:
            return "Stub handoff for the Mystery Gift overlay."
        case .connectToRanger:
            return "Stub handoff for the Ranger transfer overlay."
        case .migrateFromAgb:
            return "Stub handoff for the migrate-from-GBA overlay."
        case .connectToWii:
            return "Stub handoff for the Wii connection launcher."
        case .nintendoWFCSetup:
            return "Stub handoff for the Nintendo WFC setup flow."
        case .wiiMessageSettings:
            return "Stub handoff for Wii message settings."
        }
    }
}
