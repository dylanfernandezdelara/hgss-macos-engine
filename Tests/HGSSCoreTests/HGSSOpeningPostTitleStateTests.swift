import Testing
import HGSSCore

struct HGSSOpeningPostTitleStateTests {
    @Test("CheckSave status exposes source-backed bit flags")
    func checkSaveStatusFlags() {
        let status: HGSSCheckSaveStatus = [.saveCorrupted, .battleHallErased, .battleVideoCorrupted]

        #expect(status.rawValue == ((1 << 0) | (1 << 3) | (1 << 4)))
        #expect(status.contains(.saveCorrupted))
        #expect(status.contains(.battleHallErased))
        #expect(status.contains(.battleVideoCorrupted))
        #expect(status.contains(.saveErased) == false)
    }

    @Test("MainMenu availability reproduces the no-save source option set")
    func mainMenuAvailabilityForNoSave() {
        let availability = HGSSOpeningMainMenuAvailability.noSave

        #expect(availability.visibleOptionIDs == [
            "new_game",
            "pokewalker",
            "wfc",
            "wii_settings",
        ])
    }

    @Test("MainMenu availability reproduces source-backed feature gates")
    func mainMenuAvailabilityForContinueCase() {
        let availability = HGSSOpeningMainMenuAvailability(
            hasSaveData: true,
            hasPokedex: true,
            drawMysteryGift: true,
            drawRanger: true,
            drawConnectToWii: true,
            connectedAGBGame: .ruby
        )

        #expect(availability.visibleOptionIDs == [
            "continue",
            "new_game",
            "pokewalker",
            "mystery_gift",
            "ranger",
            "migrate_ruby",
            "connect_to_wii",
            "wfc",
            "wii_settings",
        ])
    }

    @Test("MainMenu availability keeps Ranger and Mystery Gift hidden without Pokedex")
    func mainMenuAvailabilityRequiresPokedex() {
        let availability = HGSSOpeningMainMenuAvailability(
            hasSaveData: true,
            hasPokedex: false,
            drawMysteryGift: true,
            drawRanger: true,
            drawConnectToWii: false,
            connectedAGBGame: .emerald
        )

        #expect(availability.visibleOptionIDs == [
            "continue",
            "new_game",
            "pokewalker",
            "migrate_emerald",
            "wfc",
            "wii_settings",
        ])
    }

    @Test("Bootstrap state exposes typed post-title state and flags")
    func bootstrapStateBuildsTypedPostTitleState() {
        let bootstrapState = HGSSOpeningBootstrapState(
            checkSaveStatus: [.saveErased, .battleVideoErased],
            mainMenu: HGSSOpeningMainMenuAvailability(
                hasSaveData: true,
                hasPokedex: true,
                drawMysteryGift: true,
                drawRanger: false,
                drawConnectToWii: true,
                connectedAGBGame: .leafGreen
            )
        )

        #expect(bootstrapState.checkSaveStatus == [.saveErased, .battleVideoErased])
        #expect(bootstrapState.mainMenuAvailability.visibleOptionIDs == [
            "continue",
            "new_game",
            "pokewalker",
            "mystery_gift",
            "migrate_leafgreen",
            "connect_to_wii",
            "wfc",
            "wii_settings",
        ])
        #expect(bootstrapState.postTitleState.programFlags == [
            "check_save_status_flags": (1 << 1) | (1 << 5),
            "main_menu_has_save_data": 1,
            "main_menu_has_pokedex": 1,
            "main_menu_draw_mystery_gift": 1,
            "main_menu_draw_ranger": 0,
            "main_menu_draw_connect_to_wii": 1,
            "main_menu_connected_agb_game": 3,
        ])
    }
}
