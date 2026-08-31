import CoreAudio
import XCTest
@testable import FOH

@MainActor
final class AppStateAutomationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "studio.rightfast.foh.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDisconnectUsesFOHPriorityAfterMacOSAlreadySelectedFallback() {
        let preferred = device(id: 10, uid: "studio", name: "Studio Mic", direction: .input)
        let second = device(id: 11, uid: "usb", name: "USB Mic", direction: .input)
        let builtIn = device(id: 12, uid: "built-in", name: "Mac Microphone", direction: .input)
        let hardware = FakeAudioHardware(devices: [preferred, second, builtIn], inputID: preferred.objectID)
        let state = AppState(hardware: hardware, defaults: defaults)
        state.automaticSwitching = true

        // Core Audio commonly chooses its own fallback before notifying FOH.
        hardware.connectedDevices = [second, builtIn]
        hardware.inputID = builtIn.objectID
        state.refresh()

        XCTAssertEqual(hardware.selections.last?.id, second.id)
        XCTAssertEqual(state.defaultInput?.id, second.id)
        XCTAssertEqual(state.events.last?.kind, .automaticFallback)
    }

    func testReconnectRestoresHigherPriorityDevice() {
        let preferred = device(id: 20, uid: "airpods", name: "AirPods", direction: .output)
        let builtIn = device(id: 21, uid: "built-in", name: "Mac Speakers", direction: .output)
        let hardware = FakeAudioHardware(devices: [preferred, builtIn], outputID: preferred.objectID)
        let state = AppState(hardware: hardware, defaults: defaults)
        state.automaticSwitching = true

        hardware.connectedDevices = [builtIn]
        hardware.outputID = builtIn.objectID
        state.refresh()
        hardware.connectedDevices = [preferred, builtIn]
        state.refresh()

        XCTAssertEqual(hardware.selections.last?.id, preferred.id)
        XCTAssertEqual(state.defaultOutput?.id, preferred.id)
        XCTAssertEqual(state.events.last?.kind, .preferredRestored)
    }

    func testReconnectDoesNotRestoreWhenDisabled() {
        let preferred = device(id: 30, uid: "airpods", name: "AirPods", direction: .output)
        let builtIn = device(id: 31, uid: "built-in", name: "Mac Speakers", direction: .output)
        let hardware = FakeAudioHardware(devices: [preferred, builtIn], outputID: preferred.objectID)
        let state = AppState(hardware: hardware, defaults: defaults)
        state.automaticSwitching = true
        state.restoresPreferredDevice = false

        hardware.connectedDevices = [builtIn]
        hardware.outputID = builtIn.objectID
        state.refresh()
        let selectionCountAfterFallback = hardware.selections.count
        hardware.connectedDevices = [preferred, builtIn]
        state.refresh()

        XCTAssertEqual(hardware.selections.count, selectionCountAfterFallback)
        XCTAssertEqual(state.defaultOutput?.id, builtIn.id)
    }

    func testManualSelectionIsNotOverriddenWithoutConnectionChange() {
        let preferred = device(id: 40, uid: "usb", name: "USB Headphones", direction: .output)
        let manual = device(id: 41, uid: "built-in", name: "Mac Speakers", direction: .output)
        let hardware = FakeAudioHardware(devices: [preferred, manual], outputID: preferred.objectID)
        let state = AppState(hardware: hardware, defaults: defaults)
        state.automaticSwitching = true

        hardware.outputID = manual.objectID
        state.refresh()

        XCTAssertTrue(hardware.selections.isEmpty)
        XCTAssertEqual(state.defaultOutput?.id, manual.id)
    }

    func testInputDisconnectDoesNotChangeOutput() {
        let preferredInput = device(id: 50, uid: "studio", name: "Studio Mic", direction: .input)
        let fallbackInput = device(id: 51, uid: "built-in-in", name: "Mac Microphone", direction: .input)
        let output = device(id: 52, uid: "built-in-out", name: "Mac Speakers", direction: .output)
        let hardware = FakeAudioHardware(
            devices: [preferredInput, fallbackInput, output],
            inputID: preferredInput.objectID,
            outputID: output.objectID
        )
        let state = AppState(hardware: hardware, defaults: defaults)
        state.automaticSwitching = true

        hardware.connectedDevices = [fallbackInput, output]
        hardware.inputID = fallbackInput.objectID
        state.refresh()

        XCTAssertEqual(hardware.selections.map(\.direction), [.input])
        XCTAssertEqual(state.defaultOutput?.id, output.id)
    }

    func testPresetApplicationLaunchAppliesConfiguredInputAndOutput() async {
        let input = device(id: 60, uid: "zoom-input", name: "Desk Microphone", direction: .input)
        let output = device(id: 61, uid: "zoom-output", name: "Desk Headphones", direction: .output)
        let otherInput = device(id: 62, uid: "other-input", name: "Mac Microphone", direction: .input)
        let otherOutput = device(id: 63, uid: "other-output", name: "Mac Speakers", direction: .output)
        let hardware = FakeAudioHardware(
            devices: [input, otherInput, output, otherOutput],
            inputID: otherInput.objectID,
            outputID: otherOutput.objectID
        )
        let applications = FakeApplicationMonitor()
        let state = AppState(hardware: hardware, defaults: defaults, applicationMonitor: applications)
        let zoomID = "us.zoom.xos"
        state.setApplicationDevice(input.id, for: .input, ruleID: zoomID)
        state.setApplicationDevice(output.id, for: .output, ruleID: zoomID)
        state.setApplicationRuleEnabled(zoomID, isEnabled: true)

        applications.launch("us.zoom.xos")
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(state.runningApplicationIDs.contains(zoomID))
        XCTAssertEqual(hardware.selections.map(\.id), [input.id, output.id])
        XCTAssertEqual(state.defaultInput?.id, input.id)
        XCTAssertEqual(state.defaultOutput?.id, output.id)
        XCTAssertEqual(state.events.last?.kind, .applicationRuleApplied)
    }

    func testNonZoomPresetLaunchUsesTheSameGenericAutomationEngine() async {
        let input = device(id: 70, uid: "slack-input", name: "Conference Microphone", direction: .input)
        let output = device(id: 71, uid: "slack-output", name: "Conference Speakers", direction: .output)
        let hardware = FakeAudioHardware(devices: [input, output])
        let applications = FakeApplicationMonitor(installed: ["com.tinyspeck.slackmacgap"])
        let state = AppState(hardware: hardware, defaults: defaults, applicationMonitor: applications)
        let slackID = "com.tinyspeck.slackmacgap"
        state.setApplicationRuleEnabled(slackID, isEnabled: true)

        applications.launch(slackID)
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(state.runningApplicationIDs.contains(slackID))
        XCTAssertEqual(hardware.selections.map(\.id), [input.id, output.id])
        XCTAssertEqual(state.events.last?.kind, .applicationRuleApplied)
    }

    private func device(id: AudioObjectID, uid: String, name: String, direction: AudioDirection) -> AudioDevice {
        AudioDevice(
            objectID: id,
            uid: uid,
            name: name,
            manufacturer: "Test",
            direction: direction,
            transport: .usb,
            channelCount: 2,
            nominalSampleRate: 48_000,
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

private final class FakeAudioHardware: AudioHardwareProviding, @unchecked Sendable {
    var onChange: AudioHardwareService.ChangeHandler?
    var connectedDevices: [AudioDevice]
    var inputID: AudioObjectID?
    var outputID: AudioObjectID?
    private(set) var selections: [AudioDevice] = []

    init(devices: [AudioDevice], inputID: AudioObjectID? = nil, outputID: AudioObjectID? = nil) {
        connectedDevices = devices
        self.inputID = inputID
        self.outputID = outputID
    }

    func devices() throws -> [AudioDevice] { connectedDevices }

    func defaultDeviceID(for direction: AudioDirection) throws -> AudioObjectID {
        guard let id = direction == .input ? inputID : outputID else {
            throw CoreAudioError(operation: "Read fake default", status: kAudioHardwareBadObjectError)
        }
        return id
    }

    func setDefaultDevice(_ device: AudioDevice) throws {
        selections.append(device)
        if device.direction == .input { inputID = device.objectID } else { outputID = device.objectID }
    }

    func startObserving() {}
}

private final class FakeApplicationMonitor: ApplicationMonitoring, @unchecked Sendable {
    var onLaunch: (@Sendable (String) -> Void)?
    var onTerminate: (@Sendable (String) -> Void)?
    private var running: Set<String> = []

    private let installed: Set<String>

    init(installed: Set<String> = []) {
        self.installed = installed
    }

    func startObserving() {}

    func isRunning(bundleIdentifier: String) -> Bool {
        running.contains(bundleIdentifier)
    }

    func applicationURL(bundleIdentifier: String) -> URL? {
        installed.contains(bundleIdentifier) ? URL(fileURLWithPath: "/Applications/Fake.app") : nil
    }

    func launch(_ bundleIdentifier: String) {
        running.insert(bundleIdentifier)
        onLaunch?(bundleIdentifier)
    }
}
