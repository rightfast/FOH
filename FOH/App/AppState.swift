import CoreAudio
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultInputID: AudioObjectID?
    @Published private(set) var defaultOutputID: AudioObjectID?
    @Published private(set) var lastUpdated: Date?
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
    }

    var inputDevices: [AudioDevice] { devices.filter { $0.direction == .input } }
    var outputDevices: [AudioDevice] { devices.filter { $0.direction == .output } }
    var defaultInput: AudioDevice? { devices.first { $0.objectID == defaultInputID && $0.direction == .input } }
    var defaultOutput: AudioDevice? { devices.first { $0.objectID == defaultOutputID && $0.direction == .output } }

    func isDefault(_ device: AudioDevice) -> Bool {
        switch device.direction {
        case .input: device.objectID == defaultInputID
        case .output: device.objectID == defaultOutputID
        }
    }

    func select(_ device: AudioDevice) {
        do {
            try hardware.setDefaultDevice(device)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        do {
            devices = try hardware.devices()
            defaultInputID = try? hardware.defaultDeviceID(for: .input)
            defaultOutputID = try? hardware.defaultDeviceID(for: .output)
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
}

