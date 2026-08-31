import CoreAudio
import Foundation

enum AudioDirection: String, CaseIterable, Codable, Sendable {
    case input
    case output

    var title: String {
        switch self {
        case .input: "Microphones"
        case .output: "Listening devices"
        }
    }

    var systemImage: String {
        switch self {
        case .input: "mic.fill"
        case .output: "speaker.wave.2.fill"
        }
    }
}

struct AudioDevice: Identifiable, Hashable, Sendable {
    let objectID: AudioObjectID
    let uid: String
    let name: String
    let direction: AudioDirection
    let transport: AudioTransport
    let canSetVolume: Bool
    let canSetMute: Bool
    let canSetGain: Bool
    let volume: Float?
    let isMuted: Bool?

    var id: String { "\(direction.rawValue):\(uid)" }
}

enum AudioTransport: String, Codable, Sendable {
    case builtIn = "Built-in"
    case bluetooth = "Bluetooth"
    case usb = "USB"
    case hdmi = "HDMI"
    case displayPort = "DisplayPort"
    case virtual = "Virtual"
    case aggregate = "Aggregate"
    case other = "Other"

    init(coreAudioValue value: UInt32) {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn: self = .builtIn
        case kAudioDeviceTransportTypeBluetooth,
             kAudioDeviceTransportTypeBluetoothLE: self = .bluetooth
        case kAudioDeviceTransportTypeUSB: self = .usb
        case kAudioDeviceTransportTypeHDMI: self = .hdmi
        case kAudioDeviceTransportTypeDisplayPort: self = .displayPort
        case kAudioDeviceTransportTypeVirtual: self = .virtual
        case kAudioDeviceTransportTypeAggregate: self = .aggregate
        default: self = .other
        }
    }
}

