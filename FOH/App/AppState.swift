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
    @Published private(set) var runningApplicationIDs: Set<String> = []
    @Published private(set) var applicationRules: [ApplicationAudioRule]
    @Published private(set) var browserRule: BrowserAudioRule
    @Published private(set) var activeMeetingDomain: String?
    @Published private(set) var browserPermissionDenied = false
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
    private let browserMonitor: any BrowserMonitoring
    private var refreshTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?

    init(
        hardware: any AudioHardwareProviding = AudioHardwareService(),
        defaults: UserDefaults = .standard,
        applicationMonitor: any ApplicationMonitoring = ApplicationMonitor(),
        browserMonitor: any BrowserMonitoring = BrowserMonitor()
    ) {
        self.hardware = hardware
        self.defaults = defaults
        self.applicationMonitor = applicationMonitor
        self.browserMonitor = browserMonitor
        priorities = Self.loadPriorities(from: defaults)
        applicationRules = Self.loadApplicationRules(from: defaults)
        browserRule = Self.loadBrowserRule(from: defaults)
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
        runningApplicationIDs = Set(applicationRules.filter {
            applicationMonitor.isRunning(bundleIdentifier: $0.bundleIdentifier)
        }.map(\.bundleIdentifier))
        record(.appStarted, "FOH started and discovered \(devices.count) audio endpoints.")
        for rule in applicationRules where rule.isEnabled && runningApplicationIDs.contains(rule.bundleIdentifier) {
            applyApplicationRule(rule, trigger: "\(rule.displayName) was already running")
        }
        browserMonitor.onChange = { [weak self] snapshot in
            self?.browserPageDidChange(snapshot)
        }
        browserMonitor.startObserving()
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

    func isApplicationRunning(_ rule: ApplicationAudioRule) -> Bool {
        runningApplicationIDs.contains(rule.bundleIdentifier)
    }

    func isApplicationInstalled(_ rule: ApplicationAudioRule) -> Bool {
        if let path = rule.applicationPath, FileManager.default.fileExists(atPath: path) { return true }
        return applicationMonitor.applicationURL(bundleIdentifier: rule.bundleIdentifier) != nil
    }

    func setApplicationRuleEnabled(_ ruleID: String, isEnabled: Bool) {
        guard let index = applicationRules.firstIndex(where: { $0.id == ruleID }) else { return }
        applicationRules[index].isEnabled = isEnabled
        let rule = applicationRules[index]
        saveApplicationRules()
        record(.applicationRuleChanged, "\(rule.displayName) audio automation \(isEnabled ? "enabled" : "disabled").")
        if isEnabled, isApplicationRunning(rule) { applyApplicationRule(rule, trigger: "\(rule.displayName) automation was enabled") }
    }

    func setApplicationDevice(_ deviceID: String?, for direction: AudioDirection, ruleID: String) {
        guard let index = applicationRules.firstIndex(where: { $0.id == ruleID }) else { return }
        if direction == .input { applicationRules[index].inputDeviceID = deviceID } else { applicationRules[index].outputDeviceID = deviceID }
        let rule = applicationRules[index]
        saveApplicationRules()
        let choice = deviceID.flatMap { id in priorities.first(where: { $0.id == id })?.name } ?? "highest-priority available device"
        record(.applicationRuleChanged, "\(rule.displayName) \(direction.rawValue) set to \(choice).")
        if rule.isEnabled, isApplicationRunning(rule) { applyApplicationRule(rule, trigger: "\(rule.displayName) rule was updated") }
    }

    func testApplicationRule(_ ruleID: String) {
        guard let rule = applicationRules.first(where: { $0.id == ruleID }) else { return }
        applyApplicationRule(rule, trigger: "\(rule.displayName) rule test")
    }

    func addApplication(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else {
            errorMessage = "FOH couldn’t read that application’s bundle identifier."
            return
        }
        guard !applicationRules.contains(where: { $0.bundleIdentifier == identifier }) else {
            errorMessage = "That application already has an automation rule."
            return
        }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        applicationRules.append(ApplicationAudioRule(
            bundleIdentifier: identifier,
            displayName: name,
            applicationPath: url.path,
            isPreset: false,
            isEnabled: false,
            inputDeviceID: nil,
            outputDeviceID: nil
        ))
        if applicationMonitor.isRunning(bundleIdentifier: identifier) {
            runningApplicationIDs.insert(identifier)
        }
        saveApplicationRules()
        record(.applicationRuleChanged, "Added \(name) to application automations.")
    }

    func removeApplicationRule(_ ruleID: String) {
        guard let rule = applicationRules.first(where: { $0.id == ruleID }), !rule.isPreset else { return }
        applicationRules.removeAll { $0.id == ruleID }
        runningApplicationIDs.remove(ruleID)
        saveApplicationRules()
        record(.applicationRuleChanged, "Removed \(rule.displayName) from application automations.")
    }

    func isBrowserInstalled(_ browser: SupportedBrowser) -> Bool {
        applicationMonitor.applicationURL(bundleIdentifier: browser.id) != nil
    }

    func setBrowserAutomationEnabled(_ isEnabled: Bool) {
        browserRule.isEnabled = isEnabled
        saveBrowserRule()
        activeMeetingDomain = nil
        browserPermissionDenied = false
        record(.applicationRuleChanged, "Browser meeting automation \(isEnabled ? "enabled" : "disabled").")
        if isEnabled { browserMonitor.checkNow() }
    }

    func setBrowserEnabled(_ bundleIdentifier: String, isEnabled: Bool) {
        if isEnabled {
            browserRule.browserBundleIdentifiers.insert(bundleIdentifier)
        } else {
            browserRule.browserBundleIdentifiers.remove(bundleIdentifier)
        }
        saveBrowserRule()
        activeMeetingDomain = nil
        if browserRule.isEnabled { browserMonitor.checkNow() }
    }

    func setBrowserDevice(_ deviceID: String?, for direction: AudioDirection) {
        if direction == .input { browserRule.inputDeviceID = deviceID } else { browserRule.outputDeviceID = deviceID }
        saveBrowserRule()
        record(.applicationRuleChanged, "Browser meeting \(direction.rawValue) selection changed.")
        if browserRule.isEnabled { browserMonitor.checkNow() }
    }

    func addBrowserDomain(_ value: String) {
        guard let domain = BrowserDomainPolicy.normalizedDomain(value) else {
            errorMessage = "Enter a valid domain such as meet.example.com."
            return
        }
        guard !browserRule.domains.contains(domain) else {
            errorMessage = "That meeting domain is already included."
            return
        }
        browserRule.domains.append(domain)
        browserRule.domains.sort()
        saveBrowserRule()
        record(.applicationRuleChanged, "Added a browser meeting domain.")
        if browserRule.isEnabled { browserMonitor.checkNow() }
    }

    func removeBrowserDomain(_ domain: String) {
        browserRule.domains.removeAll { $0 == domain }
        saveBrowserRule()
        if activeMeetingDomain == domain { activeMeetingDomain = nil }
        record(.applicationRuleChanged, "Removed a browser meeting domain.")
    }

    func testBrowserRule() {
        applyBrowserRule(trigger: "Browser meeting rule test")
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
        guard let rule = applicationRules.first(where: { $0.bundleIdentifier == bundleIdentifier }) else { return }
        runningApplicationIDs.insert(bundleIdentifier)
        record(.applicationDetected, "\(rule.displayName) launched.")
        if rule.isEnabled { applyApplicationRule(rule, trigger: "\(rule.displayName) launched") }
    }

    private func applicationDidTerminate(_ bundleIdentifier: String) {
        guard let rule = applicationRules.first(where: { $0.bundleIdentifier == bundleIdentifier }) else { return }
        runningApplicationIDs.remove(bundleIdentifier)
        record(.applicationDetected, "\(rule.displayName) quit. FOH left the current system devices unchanged.")
    }

    private func browserPageDidChange(_ snapshot: BrowserPageSnapshot) {
        if snapshot.permissionDenied {
            browserPermissionDenied = true
        } else if snapshot.browserBundleIdentifier != nil {
            browserPermissionDenied = false
        }
        guard browserRule.isEnabled,
              !snapshot.permissionDenied,
              let browserID = snapshot.browserBundleIdentifier,
              browserRule.browserBundleIdentifiers.contains(browserID),
              let url = snapshot.url,
              let domain = BrowserDomainPolicy.matchingDomain(for: url, domains: browserRule.domains) else {
            activeMeetingDomain = nil
            return
        }
        guard activeMeetingDomain != domain else { return }
        activeMeetingDomain = domain
        applyBrowserRule(trigger: "A meeting opened on \(domain)")
    }

    private func applyBrowserRule(trigger: String) {
        let syntheticRule = ApplicationAudioRule(
            bundleIdentifier: "studio.rightfast.foh.browser-meetings",
            displayName: "Browser meetings",
            applicationPath: nil,
            isPreset: true,
            isEnabled: browserRule.isEnabled,
            inputDeviceID: browserRule.inputDeviceID,
            outputDeviceID: browserRule.outputDeviceID
        )
        applyApplicationRule(syntheticRule, trigger: trigger)
    }

    private func applyApplicationRule(_ rule: ApplicationAudioRule, trigger: String) {
        var appliedNames: [String] = []
        for direction in AudioDirection.allCases {
            let configuredID = direction == .input ? rule.inputDeviceID : rule.outputDeviceID
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
            let message = "No available devices could satisfy the \(rule.displayName) rule."
            record(.error, message)
            showNotice(title: "\(rule.displayName) rule needs attention", detail: message)
            return
        }
        let detail = "\(trigger): \(appliedNames.joined(separator: ", "))."
        record(.applicationRuleApplied, detail)
        showNotice(title: "\(rule.displayName) audio is ready", detail: detail)
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

    private func saveApplicationRules() {
        if let data = try? JSONEncoder().encode(applicationRules) {
            defaults.set(data, forKey: Keys.applicationRules)
        }
    }

    private static func loadApplicationRules(from defaults: UserDefaults) -> [ApplicationAudioRule] {
        var stored = defaults.data(forKey: Keys.applicationRules)
            .flatMap { try? JSONDecoder().decode([ApplicationAudioRule].self, from: $0) } ?? []
        if stored.isEmpty,
           let legacyData = defaults.data(forKey: Keys.zoomRule),
           let legacy = try? JSONDecoder().decode(LegacyApplicationAudioRule.self, from: legacyData),
           let zoomIndex = ApplicationAudioRule.presets.firstIndex(where: { $0.bundleIdentifier == legacy.bundleIdentifier }) {
            var zoom = ApplicationAudioRule.presets[zoomIndex]
            zoom.isEnabled = legacy.isEnabled
            zoom.inputDeviceID = legacy.inputDeviceID
            zoom.outputDeviceID = legacy.outputDeviceID
            stored.append(zoom)
        }
        for preset in ApplicationAudioRule.presets where !stored.contains(where: { $0.bundleIdentifier == preset.bundleIdentifier }) {
            stored.append(preset)
        }
        return stored
    }

    private func saveBrowserRule() {
        if let data = try? JSONEncoder().encode(browserRule) {
            defaults.set(data, forKey: Keys.browserRule)
        }
    }

    private static func loadBrowserRule(from defaults: UserDefaults) -> BrowserAudioRule {
        guard let data = defaults.data(forKey: Keys.browserRule),
              let rule = try? JSONDecoder().decode(BrowserAudioRule.self, from: data) else { return .standard }
        return rule
    }

    private enum Keys {
        static let priorities = "devicePriorities.v1"
        static let automaticSwitching = "automaticSwitching.v1"
        static let restoresPreferredDevice = "restoresPreferredDevice.v1"
        static let zoomRule = "zoomAudioRule.v1"
        static let applicationRules = "applicationAudioRules.v2"
        static let browserRule = "browserAudioRule.v1"
    }

    private struct LegacyApplicationAudioRule: Codable {
        let bundleIdentifier: String
        let isEnabled: Bool
        let inputDeviceID: String?
        let outputDeviceID: String?
    }
}
