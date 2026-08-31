import CoreAudio
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultInputID: AudioObjectID?
    @Published private(set) var defaultOutputID: AudioObjectID?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var events: [DiagnosticEvent] = []
    @Published var errorMessage: String?

    private let hardware: AudioHardwareService
    private var refreshTask: Task<Void, Never>?

    init(hardware: AudioHardwareService = AudioHardwareService()) {
        self.hardware = hardware
        hardware.onChange = { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
        hardware.startObserving()
        refresh()
        record(.appStarted, "FOH started and discovered \(devices.count) audio endpoints.")
    }

    var inputDevices: [AudioDevice] { devices.filter { $0.direction == .input } }
    var outputDevices: [AudioDevice] { devices.filter { $0.direction == .output } }
    var defaultInput: AudioDevice? { devices.first { $0.objectID == defaultInputID && $0.direction == .input } }
    var defaultOutput: AudioDevice? { devices.first { $0.objectID == defaultOutputID && $0.direction == .output } }

    var diagnosticReport: DiagnosticReport {
        DiagnosticReport.make(
            devices: devices,
            defaultInputID: defaultInputID,
            defaultOutputID: defaultOutputID,
            events: events
        )
    }

    func isDefault(_ device: AudioDevice) -> Bool {
        switch device.direction {
        case .input: device.objectID == defaultInputID
        case .output: device.objectID == defaultOutputID
        }
    }

    func select(_ device: AudioDevice) {
        do {
            try hardware.setDefaultDevice(device)
            record(.deviceSelected, "Selected \(device.name) as the default \(device.direction.rawValue).")
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            record(.error, error.localizedDescription)
        }
    }

    func refresh() {
        let previousDevices = devices
        let previousInputID = defaultInputID
        let previousOutputID = defaultOutputID
        do {
            let refreshedDevices = try hardware.devices()
            let refreshedInputID = try? hardware.defaultDeviceID(for: .input)
            let refreshedOutputID = try? hardware.defaultDeviceID(for: .output)
            devices = refreshedDevices
            defaultInputID = refreshedInputID
            defaultOutputID = refreshedOutputID
            lastUpdated = Date()
            errorMessage = nil
            recordChanges(
                from: previousDevices,
                to: refreshedDevices,
                previousInputID: previousInputID,
                currentInputID: refreshedInputID,
                previousOutputID: previousOutputID,
                currentOutputID: refreshedOutputID
            )
        } catch {
            errorMessage = error.localizedDescription
            record(.error, error.localizedDescription)
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private func recordChanges(
        from previousDevices: [AudioDevice],
        to currentDevices: [AudioDevice],
        previousInputID: AudioObjectID?,
        currentInputID: AudioObjectID?,
        previousOutputID: AudioObjectID?,
        currentOutputID: AudioObjectID?
    ) {
        guard !previousDevices.isEmpty else { return }
        let previousIDs = Set(previousDevices.map(\.id))
        let currentIDs = Set(currentDevices.map(\.id))

        for device in currentDevices where !previousIDs.contains(device.id) {
            record(.deviceConnected, "Connected: \(device.name) (\(device.direction.rawValue)).")
        }
        for device in previousDevices where !currentIDs.contains(device.id) {
            record(.deviceDisconnected, "Disconnected: \(device.name) (\(device.direction.rawValue)).")
        }
        if previousInputID != nil, previousInputID != currentInputID {
            let name = currentDevices.first { $0.objectID == currentInputID && $0.direction == .input }?.name ?? "Unavailable"
            record(.defaultInputChanged, "Default microphone changed to \(name).")
        }
        if previousOutputID != nil, previousOutputID != currentOutputID {
            let name = currentDevices.first { $0.objectID == currentOutputID && $0.direction == .output }?.name ?? "Unavailable"
            record(.defaultOutputChanged, "Default listening device changed to \(name).")
        }
    }

    private func record(_ kind: DiagnosticEventKind, _ message: String) {
        events.append(DiagnosticEvent(kind: kind, message: message))
        if events.count > 200 {
            events.removeFirst(events.count - 200)
        }
    }
}
