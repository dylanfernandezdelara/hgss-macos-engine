import Foundation

public enum HGSSOpeningSaveRecordStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case absent
    case valid
    case corrupted
    case erased
}

public struct HGSSOpeningSaveSummary: Codable, Equatable, Sendable {
    public let hasUsableSaveData: Bool
    public let mainSaveStatus: HGSSOpeningSaveRecordStatus
    public let battleHallStatus: HGSSOpeningSaveRecordStatus
    public let battleVideoStatus: HGSSOpeningSaveRecordStatus
    public let hasPokedex: Bool
    public let mysteryGiftEnabled: Bool
    public let rangerEnabled: Bool
    public let connectToWiiEnabled: Bool
    public let connectedAGBGame: HGSSOpeningAGBGame

    public init(
        hasUsableSaveData: Bool = false,
        mainSaveStatus: HGSSOpeningSaveRecordStatus = .absent,
        battleHallStatus: HGSSOpeningSaveRecordStatus = .absent,
        battleVideoStatus: HGSSOpeningSaveRecordStatus = .absent,
        hasPokedex: Bool = false,
        mysteryGiftEnabled: Bool = false,
        rangerEnabled: Bool = false,
        connectToWiiEnabled: Bool = false,
        connectedAGBGame: HGSSOpeningAGBGame = .none
    ) {
        self.hasUsableSaveData = hasUsableSaveData
        self.mainSaveStatus = mainSaveStatus
        self.battleHallStatus = battleHallStatus
        self.battleVideoStatus = battleVideoStatus
        self.hasPokedex = hasPokedex
        self.mysteryGiftEnabled = mysteryGiftEnabled
        self.rangerEnabled = rangerEnabled
        self.connectToWiiEnabled = connectToWiiEnabled
        self.connectedAGBGame = connectedAGBGame
    }

    public static let noSave = HGSSOpeningSaveSummary()

    public var checkSaveStatus: HGSSCheckSaveStatus {
        var status: HGSSCheckSaveStatus = []
        switch mainSaveStatus {
        case .corrupted:
            status.insert(.saveCorrupted)
        case .erased:
            status.insert(.saveErased)
        case .absent, .valid:
            break
        }

        switch battleHallStatus {
        case .corrupted:
            status.insert(.battleHallCorrupted)
        case .erased:
            status.insert(.battleHallErased)
        case .absent, .valid:
            break
        }

        switch battleVideoStatus {
        case .corrupted:
            status.insert(.battleVideoCorrupted)
        case .erased:
            status.insert(.battleVideoErased)
        case .absent, .valid:
            break
        }

        return status
    }

    public var mainMenuAvailability: HGSSOpeningMainMenuAvailability {
        HGSSOpeningMainMenuAvailability(
            hasSaveData: hasUsableSaveData,
            hasPokedex: hasPokedex,
            drawMysteryGift: mysteryGiftEnabled,
            drawRanger: rangerEnabled,
            drawConnectToWii: connectToWiiEnabled,
            connectedAGBGame: connectedAGBGame
        )
    }

    public var postTitleState: HGSSOpeningPostTitleState {
        HGSSOpeningPostTitleState(
            checkSaveStatus: checkSaveStatus,
            mainMenu: mainMenuAvailability
        )
    }
}
