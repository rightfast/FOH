import Foundation

struct ApplicationAudioRule: Identifiable, Codable, Equatable, Sendable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    var displayName: String
    var applicationPath: String?
    var isPreset: Bool
    var isEnabled: Bool
    var inputDeviceID: String?
    var outputDeviceID: String?

    static let presets: [ApplicationAudioRule] = [
        preset("us.zoom.xos", "Zoom Workplace"),
        preset("com.microsoft.teams2", "Microsoft Teams"),
        preset("com.tinyspeck.slackmacgap", "Slack"),
        preset("Cisco-Systems.Spark", "Cisco Webex"),
        preset("com.hnc.Discord", "Discord"),
        preset("com.apple.FaceTime", "FaceTime"),
    ]

    private static func preset(_ bundleIdentifier: String, _ displayName: String) -> ApplicationAudioRule {
        ApplicationAudioRule(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationPath: nil,
            isPreset: true,
            isEnabled: false,
            inputDeviceID: nil,
            outputDeviceID: nil
        )
    }
}

enum ApplicationRulePolicy {
    static func target(configuredDeviceID: String?, orderedIDs: [String], availableIDs: Set<String>) -> String? {
        if let configuredDeviceID, availableIDs.contains(configuredDeviceID) { return configuredDeviceID }
        return orderedIDs.first(where: availableIDs.contains)
    }
}
