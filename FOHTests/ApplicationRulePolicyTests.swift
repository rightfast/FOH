import XCTest
@testable import FOH

final class ApplicationRulePolicyTests: XCTestCase {
    func testUsesConfiguredDeviceWhenAvailable() {
        XCTAssertEqual(
            ApplicationRulePolicy.target(
                configuredDeviceID: "airpods",
                orderedIDs: ["studio", "built-in"],
                availableIDs: ["airpods", "built-in"]
            ),
            "airpods"
        )
    }

    func testFallsBackToPriorityWhenConfiguredDeviceIsUnavailable() {
        XCTAssertEqual(
            ApplicationRulePolicy.target(
                configuredDeviceID: "airpods",
                orderedIDs: ["studio", "built-in"],
                availableIDs: ["studio", "built-in"]
            ),
            "studio"
        )
    }

    func testPriorityModeUsesHighestAvailableDevice() {
        XCTAssertEqual(
            ApplicationRulePolicy.target(
                configuredDeviceID: nil,
                orderedIDs: ["studio", "usb", "built-in"],
                availableIDs: ["usb", "built-in"]
            ),
            "usb"
        )
    }
}
