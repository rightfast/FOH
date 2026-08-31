import CryptoKit
import CoreAudio
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum DiagnosticEventKind: String, Codable, Sendable {
    case appStarted
    case hardwareChanged
    case deviceConnected
    case deviceDisconnected
    case defaultInputChanged
    case defaultOutputChanged
    case deviceSelected
    case priorityChanged
    case automationChanged
    case automaticFallback
    case preferredRestored
    case error
}

struct DiagnosticEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let kind: DiagnosticEventKind
    let message: String

    init(kind: DiagnosticEventKind, message: String, timestamp: Date = Date()) {
        id = UUID()
        self.timestamp = timestamp
        self.kind = kind
        self.message = message
    }
}

struct DiagnosticReport: Codable, Sendable {
    let formatVersion: Int
    let generatedAt: Date
    let operatingSystem: String
    let appVersion: String
    let devices: [Device]
    let recentEventKinds: [Event]

    struct Device: Codable, Sendable {
        let privacyID: String
        let direction: AudioDirection
        let transport: AudioTransport
        let manufacturer: String?
        let channelCount: Int
        let nominalSampleRate: Double?
        let isAlive: Bool
        let isRunning: Bool
        let isDefault: Bool
        let canSetVolume: Bool
        let canSetGain: Bool
        let canSetMute: Bool
        let hasReadableVolume: Bool
        let hasReadableMute: Bool
    }

    struct Event: Codable, Sendable {
        let timestamp: Date
        let kind: DiagnosticEventKind
    }

    static func make(
        devices: [AudioDevice],
        defaultInputID: AudioObjectID?,
        defaultOutputID: AudioObjectID?,
        events: [DiagnosticEvent]
    ) -> DiagnosticReport {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development"
        return DiagnosticReport(
            formatVersion: 1,
            generatedAt: Date(),
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            appVersion: version,
            devices: devices.map { device in
                Device(
                    privacyID: privacyID(for: device.id),
                    direction: device.direction,
                    transport: device.transport,
                    manufacturer: device.manufacturer,
                    channelCount: device.channelCount,
                    nominalSampleRate: device.nominalSampleRate,
                    isAlive: device.isAlive,
                    isRunning: device.isRunning,
                    isDefault: device.direction == .input
                        ? device.objectID == defaultInputID
                        : device.objectID == defaultOutputID,
                    canSetVolume: device.canSetVolume,
                    canSetGain: device.canSetGain,
                    canSetMute: device.canSetMute,
                    hasReadableVolume: device.volume != nil,
                    hasReadableMute: device.isMuted != nil
                )
            },
            recentEventKinds: events.suffix(100).map { Event(timestamp: $0.timestamp, kind: $0.kind) }
        )
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    private static func privacyID(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

struct DiagnosticReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let report: DiagnosticReport

    init(report: DiagnosticReport) {
        self.report = report
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        report = try decoder.decode(DiagnosticReport.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try report.encoded())
    }
}
