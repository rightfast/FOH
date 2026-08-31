import CoreAudio
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultInputID: AudioObjectID?
    @Published private(set) var defaultOutputID: AudioObjectID?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var events: [DiagnosticEvent] = []
    @Published private(set) var priorities: [DevicePriority]
    @Published private(set) var automationNotice: AutomationNotice?
    @Published private(set) var isZoomRunning = false
    @Published private(set) var zoomRule: ApplicationAudioRule
    @Published var automaticSwitching: Bool {
        didSet {
            defaults.set(automaticSwitching, forKey: Keys.automaticSwitching)
            record(.automationChanged, "Automatic device switching \(automaticSwitching ? "enabled" : "disabled").")
        }
    }
    @Published var restoresPreferredDevice: Bool {
        didSet {
            defaults.set(restoresPreferredDevice, forKey: Keys.restoresPreferredDevice)
            record(.automationChanged, "Restore preferred devices \(restoresPreferredDevice ? "enabled" : "disabled").")
        }
    }
    @Published var errorMessage: String?

    private let hardware: any AudioHardwareProviding
    private let defaults: UserDefaults
    private let applicationMonitor: any ApplicationMonitoring
    private var refreshTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?

    init(
        hardware: any AudioHardwareProviding = AudioHardwareService(),
        defaults: UserDefaults = .standard,
        applicationMonitor: any ApplicationMonitoring = ApplicationMonitor()
    ) {
        self.hardware = hardware
        self.defaults = defaults
        self.applicationMonitor = applicationMonitor
        priorities = Self.loadPriorities(from: defaults)
        zoomRule = Self.loadZoomRule(from: defaults)
        automaticSwitching = defaults.bool(forKey: Keys.automaticSwitching)
        restoresPreferredDevice = defaults.object(forKey: Keys.restoresPreferredDevice) as? Bool ?? true
        hardware.onChange = { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
        hardware.startObserving()
        refresh()
        applicationMonitor.onLaunch = { [weak self] bundleIdentifier in
            Task { @MainActor in self?.applicationDidLaunch(bundleIdentifier) }
        }
        applicationMonitor.onTerminate = { [weak self] bundleIdentifier in
            Task { @MainActor in self?.applicationDidTerminate(bundleIdentifier) }
        }
        applicationMonitor.startObserving()
        isZoomRunning = applicationMonitor.isRunning(bundleIdentifier: zoomRule.bundleIdentifier)
        record(.appStarted, "FOH started and discovered \(devices.count) audio endpoints.")
        if isZoomRunning, zoomRule.isEnabled { applyZoomRule(trigger: "Zoom was already running") }
    }

    var inputDevices: [AudioDevice] { devices.filter { $0.direction == .input } }
    var outputDevices: [AudioDevice] { devices.filter { $0.direction == .output } }
    var defaultInput: AudioDevice? { devices.first { $0.objectID == defaultInputID && $0.direction == .input } }
    var defaultOutput: AudioDevice? { devices.first { $0.objectID == defaultOutputID && $0.direction == .output } }

    func priorities(for direction: AudioDirection) -> [DevicePriority] {
        priorities.filter { $0.direction == direction }
    }

    func device(for priority: DevicePriority) -> AudioDevice? {
        devices.first { $0.id == priority.id }
    }

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

    func movePriority(_ priority: DevicePriority, by offset: Int) {
        var directional = priorities(for: priority.direction)
        guard let source = directional.firstIndex(where: { $0.id == priority.id }) else { return }
        let destination = source + offset
        guard directional.indices.contains(destination) else { return }
        directional.swapAt(source, destination)
        priorities.removeAll { $0.direction == priority.direction }
        priorities.append(contentsOf: directional)
        savePriorities()
        record(.priorityChanged, "Moved \(priority.name) to priority \(destination + 1) for \(priority.direction.title.lowercased()).")
    }

    func resetPriorities() {
        priorities = devices.map(DevicePriority.init(device:))
        savePriorities()
        record(.priorityChanged, "Reset device priorities to the current connected-device order.")
    }

    func clearHistory() {
        events.removeAll()
    }

    func setZoomRuleEnabled(_ isEnabled: Bool) {
        zoomRule.isEnabled = isEnabled
        saveZoomRule()
        record(.applicationRuleChanged, "Zoom audio automation \(isEnabled ? "enabled" : "disabled").")
        if isEnabled, isZoomRunning { applyZoomRule(trigger: "Zoom automation was enabled") }
    }

    func setZoomDevice(_ deviceID: String?, for direction: AudioDirection) {
        if direction == .input { zoomRule.inputDeviceID = deviceID } else { zoomRule.outputDeviceID = deviceID }
        saveZoomRule()
        let choice = deviceID.flatMap { id in priorities.first(where: { $0.id == id })?.name } ?? "highest-priority available device"
        record(.applicationRuleChanged, "Zoom \(direction.rawValue) set to \(choice).")
        if zoomRule.isEnabled, isZoomRunning { applyZoomRule(trigger: "Zoom rule was updated") }
    }

    func testZoomRule() {
        applyZoomRule(trigger: "Zoom rule test")
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
            syncPriorities(with: refreshedDevices)
            recordChanges(
                from: previousDevices,
                to: refreshedDevices,
                previousInputID: previousInputID,
                currentInputID: refreshedInputID,
                previousOutputID: previousOutputID,
                currentOutputID: refreshedOutputID
            )
            if !previousDevices.isEmpty, automaticSwitching {
                applyPriorityPolicy(
                    previousDevices: previousDevices,
                    previousInputID: previousInputID,
                    previousOutputID: previousOutputID
                )
            }
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

    private func syncPriorities(with devices: [AudioDevice]) {
        var changed = false
        for device in devices {
            if let index = priorities.firstIndex(where: { $0.id == device.id }) {
                if priorities[index].name != device.name {
                    priorities[index].name = device.name
                    changed = true
                }
            } else {
                priorities.append(DevicePriority(device: device))
                changed = true
            }
        }
        if changed { savePriorities() }
    }

    private func applyPriorityPolicy(
        previousDevices: [AudioDevice],
        previousInputID: AudioObjectID?,
        previousOutputID: AudioObjectID?
    ) {
        let previousIDs = Set(previousDevices.map(\.id))
        let currentIDs = Set(devices.map(\.id))
        guard previousIDs != currentIDs else { return }
        let newlyConnectedIDs = currentIDs.subtracting(previousIDs)

        for direction in AudioDirection.allCases {
            let available = devices.filter { $0.direction == direction }
            let availableIDs = Set(available.map(\.id))
            let refreshedDefaultID = direction == .input ? defaultInputID : defaultOutputID
            let currentDeviceID = available.first {
                $0.objectID == refreshedDefaultID
            }?.id
            let previousDefaultObjectID = direction == .input ? previousInputID : previousOutputID
            let previousDefaultDeviceID = previousDevices.first {
                $0.direction == direction && $0.objectID == previousDefaultObjectID
            }?.id
            let previousDefaultDisconnected = previousDefaultDeviceID.map { !currentIDs.contains($0) } ?? false
            let orderedIDs = priorities(for: direction).map(\.id)

            guard let decision = AudioPriorityPolicy.decision(
                orderedIDs: orderedIDs,
                availableIDs: availableIDs,
                currentID: previousDefaultDisconnected ? nil : currentDeviceID,
                newlyConnectedIDs: newlyConnectedIDs,
                restoresPreferredDevice: restoresPreferredDevice
            ), let target = available.first(where: { $0.id == decision.deviceID }) else { continue }

            do {
                try hardware.setDefaultDevice(target)
                if direction == .input { defaultInputID = target.objectID } else { defaultOutputID = target.objectID }
                let action = decision.reason == .fallback ? "Fell back to" : "Restored"
                let detail = "\(action) \(target.name) because it is the highest-priority available \(direction.rawValue)."
                record(decision.reason == .fallback ? .automaticFallback : .preferredRestored, detail)
                showNotice(title: decision.reason == .fallback ? "Audio fallback applied" : "Preferred device restored", detail: detail)
            } catch {
                errorMessage = error.localizedDescription
                record(.error, error.localizedDescription)
            }
        }
    }

    private func showNotice(title: String, detail: String) {
        noticeTask?.cancel()
        automationNotice = AutomationNotice(title: title, detail: detail)
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.automationNotice = nil
        }
    }

    private func applicationDidLaunch(_ bundleIdentifier: String) {
        guard bundleIdentifier == zoomRule.bundleIdentifier else { return }
        isZoomRunning = true
        record(.applicationDetected, "Zoom launched.")
        if zoomRule.isEnabled { applyZoomRule(trigger: "Zoom launched") }
    }

    private func applicationDidTerminate(_ bundleIdentifier: String) {
        guard bundleIdentifier == zoomRule.bundleIdentifier else { return }
        isZoomRunning = false
        record(.applicationDetected, "Zoom quit. FOH left the current system devices unchanged.")
    }

    private func applyZoomRule(trigger: String) {
        var appliedNames: [String] = []
        for direction in AudioDirection.allCases {
            let configuredID = direction == .input ? zoomRule.inputDeviceID : zoomRule.outputDeviceID
            let available = devices.filter { $0.direction == direction }
            let availableIDs = Set(available.map(\.id))
            guard let targetID = ApplicationRulePolicy.target(
                configuredDeviceID: configuredID,
                orderedIDs: priorities(for: direction).map(\.id),
                availableIDs: availableIDs
            ), let target = available.first(where: { $0.id == targetID }) else { continue }

            if !isDefault(target) {
                do {
                    try hardware.setDefaultDevice(target)
                    if direction == .input { defaultInputID = target.objectID } else { defaultOutputID = target.objectID }
                } catch {
                    errorMessage = error.localizedDescription
                    record(.error, error.localizedDescription)
                    continue
                }
            }
            appliedNames.append("\(direction == .input ? "microphone" : "output") \(target.name)")
        }

        guard !appliedNames.isEmpty else {
            let message = "No available devices could satisfy the Zoom rule."
            record(.error, message)
            showNotice(title: "Zoom rule needs attention", detail: message)
            return
        }
        let detail = "\(trigger): \(appliedNames.joined(separator: ", "))."
        record(.applicationRuleApplied, detail)
        showNotice(title: "Zoom audio is ready", detail: detail)
    }

    private func savePriorities() {
        if let data = try? JSONEncoder().encode(priorities) {
            defaults.set(data, forKey: Keys.priorities)
        }
    }

    private static func loadPriorities(from defaults: UserDefaults) -> [DevicePriority] {
        guard let data = defaults.data(forKey: Keys.priorities),
              let priorities = try? JSONDecoder().decode([DevicePriority].self, from: data) else { return [] }
        return priorities
    }

    private func saveZoomRule() {
        if let data = try? JSONEncoder().encode(zoomRule) {
            defaults.set(data, forKey: Keys.zoomRule)
        }
    }

    private static func loadZoomRule(from defaults: UserDefaults) -> ApplicationAudioRule {
        guard let data = defaults.data(forKey: Keys.zoomRule),
              let rule = try? JSONDecoder().decode(ApplicationAudioRule.self, from: data) else { return .zoom }
        return rule
    }

    private enum Keys {
        static let priorities = "devicePriorities.v1"
        static let automaticSwitching = "automaticSwitching.v1"
        static let restoresPreferredDevice = "restoresPreferredDevice.v1"
        static let zoomRule = "zoomAudioRule.v1"
    }
}
