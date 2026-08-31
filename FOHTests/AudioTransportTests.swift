import CoreAudio
import XCTest
@testable import FOH

final class AudioTransportTests: XCTestCase {
    func testKnownTransportTypes() {
        XCTAssertEqual(AudioTransport(coreAudioValue: kAudioDeviceTransportTypeBuiltIn), .builtIn)
        XCTAssertEqual(AudioTransport(coreAudioValue: kAudioDeviceTransportTypeBluetooth), .bluetooth)
        XCTAssertEqual(AudioTransport(coreAudioValue: kAudioDeviceTransportTypeUSB), .usb)
        XCTAssertEqual(AudioTransport(coreAudioValue: kAudioDeviceTransportTypeHDMI), .hdmi)
    }

    func testUnknownTransportTypeFallsBackToOther() {
        XCTAssertEqual(AudioTransport(coreAudioValue: 0), .other)
    }
}
