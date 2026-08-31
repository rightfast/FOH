import Foundation

struct DevicePriority: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    let direction: AudioDirection

    init(device: AudioDevice) {
        id = device.id
        name = device.name
        direction = device.direction
    }
}

struct AutomationNotice: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let detail: String
}

enum AudioPriorityPolicy {
    enum Reason: Equatable {
        case fallback
        case restoration
    }

    struct Decision: Equatable {
        let deviceID: String
        let reason: Reason
    }

    static func decision(
        orderedIDs: [String],
        availableIDs: Set<String>,
        currentID: String?,
        newlyConnectedIDs: Set<String>,
        restoresPreferredDevice: Bool
    ) -> Decision? {
        guard let bestAvailable = orderedIDs.first(where: availableIDs.contains) else { return nil }

        guard let currentID, availableIDs.contains(currentID) else {
            return Decision(deviceID: bestAvailable, reason: .fallback)
        }

        guard restoresPreferredDevice,
              newlyConnectedIDs.contains(bestAvailable),
              bestAvailable != currentID,
              let bestRank = orderedIDs.firstIndex(of: bestAvailable),
              let currentRank = orderedIDs.firstIndex(of: currentID),
              bestRank < currentRank else { return nil }

        return Decision(deviceID: bestAvailable, reason: .restoration)
    }
}
