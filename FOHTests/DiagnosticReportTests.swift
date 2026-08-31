import CoreAudio
import Foundation
import XCTest
@testable import FOH

final class DiagnosticReportTests: XCTestCase {
    func testExportOmitsRawIdentifiersNamesAndEventMessages() throws {
        let device = AudioDevice(
            objectID: 4242,
            uid: "private-hardware-serial",
            name: "Jamie's AirPods",
            manufacturer: "Example Audio",
            direction: .output,
            transport: .bluetooth,
            channelCount: 2,
            nominalSampleRate: 48_000,
            isAlive: true,
            isRunning: false,
            canSetVolume: true,
            canSetMute: false,
            canSetGain: false,
            volume: 0.5,
            isMuted: nil
        )
        let event = DiagnosticEvent(kind: .deviceConnected, message: "Connected: Jamie's AirPods")

        let report = DiagnosticReport.make(
            devices: [device],
            defaultInputID: nil,
            defaultOutputID: device.objectID,
            events: [event]
        )
        let json = String(decoding: try report.encoded(), as: UTF8.self)

        XCTAssertFalse(json.contains(device.uid))
        XCTAssertFalse(json.contains(device.name))
        XCTAssertFalse(json.contains("4242"))
        XCTAssertFalse(json.contains(event.message))
        XCTAssertTrue(json.contains("Bluetooth"))
        XCTAssertTrue(json.contains("deviceConnected"))
    }

    func testPrivacyIdentifierIsStableButDirectionSpecific() {
        let input = makeDevice(direction: .input)
        let output = makeDevice(direction: .output)

        let firstInputID = report(for: input).devices[0].privacyID
        let secondInputID = report(for: input).devices[0].privacyID
        let outputID = report(for: output).devices[0].privacyID

        XCTAssertEqual(firstInputID, secondInputID)
        XCTAssertNotEqual(firstInputID, outputID)
    }

    private func report(for device: AudioDevice) -> DiagnosticReport {
        DiagnosticReport.make(
            devices: [device],
            defaultInputID: nil,
            defaultOutputID: nil,
            events: []
        )
    }

    private func makeDevice(direction: AudioDirection) -> AudioDevice {
        AudioDevice(
            objectID: 1,
            uid: "shared-device",
            name: "Test Device",
            manufacturer: nil,
            direction: direction,
            transport: .usb,
            channelCount: 2,
            nominalSampleRate: 44_100,
            isAlive: true,
            isRunning: false,
            canSetVolume: false,
            canSetMute: false,
            canSetGain: false,
            volume: nil,
            isMuted: nil
        )
    }
}
