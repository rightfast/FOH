import Foundation

struct ApplicationAudioRule: Codable, Equatable, Sendable {
    let bundleIdentifier: String
    var isEnabled: Bool
    var inputDeviceID: String?
    var outputDeviceID: String?

    static let zoom = ApplicationAudioRule(
        bundleIdentifier: "us.zoom.xos",
        isEnabled: false,
        inputDeviceID: nil,
        outputDeviceID: nil
    )
}

enum ApplicationRulePolicy {
    static func target(
        configuredDeviceID: String?,
        orderedIDs: [String],
        availableIDs: Set<String>
    ) -> String? {
        if let configuredDeviceID, availableIDs.contains(configuredDeviceID) {
            return configuredDeviceID
        }
        return orderedIDs.first(where: availableIDs.contains)
    }
}
