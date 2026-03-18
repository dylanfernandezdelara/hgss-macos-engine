import Foundation

public struct HGSSCheckSaveStatus: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int

    public static let saveCorrupted = Self(rawValue: 1 << 0)
    public static let saveErased = Self(rawValue: 1 << 1)
    public static let battleHallCorrupted = Self(rawValue: 1 << 2)
    public static let battleHallErased = Self(rawValue: 1 << 3)
    public static let battleVideoCorrupted = Self(rawValue: 1 << 4)
    public static let battleVideoErased = Self(rawValue: 1 << 5)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(Int.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum HGSSOpeningAGBGame: Int, Codable, Equatable, Sendable, CaseIterable {
    case none = 0
    case ruby = 1
    case sapphire = 2
    case leafGreen = 3
    case fireRed = 4
    case emerald = 5

    public var menuOptionID: String? {
        switch self {
        case .none:
            return nil
        case .ruby:
            return "migrate_ruby"
        case .sapphire:
            return "migrate_sapphire"
        case .leafGreen:
            return "migrate_leafgreen"
        case .fireRed:
            return "migrate_firered"
        case .emerald:
            return "migrate_emerald"
        }
    }
}

public struct HGSSOpeningMainMenuAvailability: Codable, Equatable, Sendable {
    public let hasSaveData: Bool
    public let hasPokedex: Bool
    public let drawMysteryGift: Bool
    public let drawRanger: Bool
    public let drawConnectToWii: Bool
    public let connectedAGBGame: HGSSOpeningAGBGame

    public init(
        hasSaveData: Bool = false,
        hasPokedex: Bool = false,
        drawMysteryGift: Bool = false,
        drawRanger: Bool = false,
        drawConnectToWii: Bool = false,
        connectedAGBGame: HGSSOpeningAGBGame = .none
    ) {
        self.hasSaveData = hasSaveData
        self.hasPokedex = hasPokedex
        self.drawMysteryGift = drawMysteryGift
        self.drawRanger = drawRanger
        self.drawConnectToWii = drawConnectToWii
        self.connectedAGBGame = connectedAGBGame
    }

    public static let noSave = Self()

    public var visibleOptionIDs: [String] {
        var result: [String] = []
        if hasSaveData {
            result.append("continue")
        }
        result.append("new_game")
        result.append("pokewalker")
        if drawMysteryGift && hasPokedex {
            result.append("mystery_gift")
        }
        if drawRanger && hasPokedex {
            result.append("ranger")
        }
        if let migrateOptionID = connectedAGBGame.menuOptionID {
            result.append(migrateOptionID)
        }
        if drawConnectToWii {
            result.append("connect_to_wii")
        }
        result.append("wfc")
        result.append("wii_settings")
        return result
    }

    public var programFlags: [String: Int] {
        [
            "main_menu_has_save_data": hasSaveData ? 1 : 0,
            "main_menu_has_pokedex": hasPokedex ? 1 : 0,
            "main_menu_draw_mystery_gift": drawMysteryGift ? 1 : 0,
            "main_menu_draw_ranger": drawRanger ? 1 : 0,
            "main_menu_draw_connect_to_wii": drawConnectToWii ? 1 : 0,
            "main_menu_connected_agb_game": connectedAGBGame.rawValue,
        ]
    }
}

public struct HGSSOpeningPostTitleState: Codable, Equatable, Sendable {
    public let checkSaveStatus: HGSSCheckSaveStatus
    public let mainMenu: HGSSOpeningMainMenuAvailability

    public init(
        checkSaveStatus: HGSSCheckSaveStatus = [],
        mainMenu: HGSSOpeningMainMenuAvailability = .noSave
    ) {
        self.checkSaveStatus = checkSaveStatus
        self.mainMenu = mainMenu
    }

    public static let noSave = Self()

    public var programFlags: [String: Int] {
        ["check_save_status_flags": checkSaveStatus.rawValue]
            .merging(mainMenu.programFlags) { _, newValue in newValue }
    }
}
