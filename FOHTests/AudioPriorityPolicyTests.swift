import XCTest
@testable import FOH

final class AudioPriorityPolicyTests: XCTestCase {
    func testFallsBackToHighestPriorityAvailableDevice() {
        let decision = AudioPriorityPolicy.decision(
            orderedIDs: ["studio", "airpods", "built-in"],
            availableIDs: ["airpods", "built-in"],
            currentID: nil,
            newlyConnectedIDs: [],
            restoresPreferredDevice: true
        )

        XCTAssertEqual(decision, .init(deviceID: "airpods", reason: .fallback))
    }

    func testRestoresNewlyConnectedHigherPriorityDevice() {
        let decision = AudioPriorityPolicy.decision(
            orderedIDs: ["studio", "airpods", "built-in"],
            availableIDs: ["studio", "built-in"],
            currentID: "built-in",
            newlyConnectedIDs: ["studio"],
            restoresPreferredDevice: true
        )

        XCTAssertEqual(decision, .init(deviceID: "studio", reason: .restoration))
    }

    func testDoesNotOverrideManualSelectionWithoutTopologyChange() {
        let decision = AudioPriorityPolicy.decision(
            orderedIDs: ["studio", "built-in"],
            availableIDs: ["studio", "built-in"],
            currentID: "built-in",
            newlyConnectedIDs: [],
            restoresPreferredDevice: true
        )

        XCTAssertNil(decision)
    }

    func testDoesNotRestoreWhenPreferenceIsDisabled() {
        let decision = AudioPriorityPolicy.decision(
            orderedIDs: ["studio", "built-in"],
            availableIDs: ["studio", "built-in"],
            currentID: "built-in",
            newlyConnectedIDs: ["studio"],
            restoresPreferredDevice: false
        )

        XCTAssertNil(decision)
    }
}
