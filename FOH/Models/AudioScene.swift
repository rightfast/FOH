import Foundation

struct AudioScene: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var symbolName: String
    var inputDeviceID: String?
    var outputDeviceID: String?

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        inputDeviceID: String? = nil,
        outputDeviceID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.inputDeviceID = inputDeviceID
        self.outputDeviceID = outputDeviceID
    }

    static let defaults: [AudioScene] = [
        AudioScene(name: "Desk", symbolName: "desktopcomputer"),
        AudioScene(name: "Travel", symbolName: "airplane"),
        AudioScene(name: "Presentation", symbolName: "person.crop.rectangle"),
        AudioScene(name: "Laptop only", symbolName: "laptopcomputer"),
    ]
}

enum AutomationSource: Int, Codable, Comparable, Sendable {
    case devicePriority = 0
    case application = 1
    case browserMeeting = 2
    case scene = 3

    static func < (lhs: AutomationSource, rhs: AutomationSource) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ActiveAutomation: Equatable, Sendable {
    let source: AutomationSource
    let name: String
    let detail: String
}

struct AudioUndoState: Equatable, Sendable {
    let inputDeviceID: String?
    let outputDeviceID: String?
    let actionName: String
}

