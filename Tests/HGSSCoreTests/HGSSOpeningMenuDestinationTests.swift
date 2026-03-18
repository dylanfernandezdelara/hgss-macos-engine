import HGSSCore
import Testing

struct HGSSOpeningMenuDestinationTests {
    @Test("Maps known source-backed main-menu destination IDs into typed handoff destinations")
    func mapsKnownDestinationIDs() {
        for destination in HGSSOpeningMenuDestination.allCases {
            #expect(HGSSOpeningMenuDestination(destinationID: destination.rawValue) == destination)
            #expect(destination.title.isEmpty == false)
            #expect(destination.subtitle.isEmpty == false)
        }
    }

    @Test("Leaves unknown menu destination IDs unmapped")
    func leavesUnknownDestinationIDsUnmapped() {
        #expect(HGSSOpeningMenuDestination(destinationID: nil) == nil)
        #expect(HGSSOpeningMenuDestination(destinationID: "unknown_destination") == nil)
    }
}
