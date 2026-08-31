import SwiftUI
import UniformTypeIdentifiers

struct AutomationsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isAddingApplication = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Automations")
                            .font(.largeTitle.bold())
                        Text("Put the right devices onstage when a work app opens.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Add Application…", systemImage: "plus") {
                        isAddingApplication = true
                    }
                    .controlSize(.large)
                }

                AutomationReadinessCard()

                BrowserMeetingRuleCard()

                if !availableRules.isEmpty {
                    ruleSection("Available on this Mac", rules: availableRules)
                }

                if !unavailableRules.isEmpty {
                    ruleSection("Other supported apps", rules: unavailableRules)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use “Same as System” inside your apps")
                            .font(.headline)
                        Text("FOH changes the macOS system defaults when an enabled app launches. A device selected inside the app can take precedence. FOH leaves devices unchanged when the app quits.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $isAddingApplication,
            allowedContentTypes: [.applicationBundle],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                appState.addApplication(at: url)
            }
        }
        .alert("FOH couldn’t update this automation", isPresented: errorBinding) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
    }

    private var availableRules: [ApplicationAudioRule] {
        appState.applicationRules.filter(appState.isApplicationInstalled)
    }

    private var unavailableRules: [ApplicationAudioRule] {
        appState.applicationRules.filter { !appState.isApplicationInstalled($0) }
    }

    private func ruleSection(_ title: String, rules: [ApplicationAudioRule]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            LazyVStack(spacing: 12) {
                ForEach(rules) { rule in
                    ApplicationRuleCard(ruleID: rule.id)
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )
    }
}

private struct AutomationReadinessCard: View {
    @EnvironmentObject private var appState: AppState

    private var enabledNativeCount: Int {
        appState.applicationRules.filter { $0.isEnabled && appState.isApplicationInstalled($0) }.count
    }

    private var enabledCount: Int {
        enabledNativeCount + (appState.browserRule.isEnabled ? 1 : 0)
    }

    private var isActive: Bool {
        appState.activeMeetingDomain != nil || appState.applicationRules.contains {
            $0.isEnabled && appState.isApplicationRunning($0)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isActive ? "waveform.circle.fill" : enabledCount > 0 ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title2)
                .foregroundStyle(isActive ? Color.green : enabledCount > 0 ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(isActive ? "FOH is managing your audio" : enabledCount > 0 ? "FOH is ready for your next call" : "Choose where FOH should step in")
                    .font(.headline)
                Text(enabledCount == 0 ? "Enable a browser or app rule below to get started." : "\(enabledCount) automation\(enabledCount == 1 ? "" : "s") enabled · FOH only changes devices when a rule matches.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Text("ACTIVE")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }
        }
        .padding(18)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Color.accentColor.opacity(0.14))
        }
    }
}

private struct BrowserMeetingRuleCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var newDomain = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(Color.purple)
                    .frame(width: 42, height: 42)
                    .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Browser meetings")
                        .font(.title3.bold())
                    Text(browserStatus)
                        .font(.caption)
                        .foregroundStyle(appState.activeMeetingDomain == nil ? Color.secondary : Color.green)
                }
                Spacer()
                Toggle("Enable browser meeting automation", isOn: Binding(
                    get: { appState.browserRule.isEnabled },
                    set: { appState.setBrowserAutomationEnabled($0) }
                ))
                .labelsHidden()
            }

            if appState.browserPermissionDenied {
                Label("Browser access was denied. Allow FOH in System Settings › Privacy & Security › Automation.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            if appState.browserRule.isEnabled {
                Divider()

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                    GridRow {
                        Text("Browsers")
                            .font(.headline)
                        HStack(spacing: 16) {
                            ForEach(SupportedBrowser.all) { browser in
                                let installed = appState.isBrowserInstalled(browser)
                                Toggle(browser.name, isOn: browserBinding(browser.id))
                                    .toggleStyle(.checkbox)
                                    .disabled(!installed || !appState.browserRule.isEnabled)
                                    .opacity(installed ? 1 : 0.5)
                                    .help(installed ? browser.name : "\(browser.name) is not installed")
                            }
                        }
                    }
                    GridRow {
                        Label("Microphone", systemImage: "mic.fill")
                        browserDevicePicker(direction: .input)
                    }
                    GridRow {
                        Label("Listening", systemImage: "headphones")
                        browserDevicePicker(direction: .output)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Meeting domains")
                        .font(.headline)
                    ForEach(appState.browserRule.domains, id: \.self) { domain in
                        HStack {
                            Image(systemName: "globe.americas.fill")
                                .foregroundStyle(.secondary)
                            Text(domain)
                                .font(.callout.monospaced())
                            Spacer()
                            Button("Remove \(domain)", systemImage: "xmark") {
                                appState.removeBrowserDomain(domain)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                    }

                    HStack {
                        TextField("Add a domain, such as meet.example.com", text: $newDomain)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addDomain)
                        Button("Add", action: addDomain)
                            .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                HStack {
                    Label("Only the frontmost tab is checked. URLs are never saved.", systemImage: "hand.raised.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Test rule now") { appState.testBrowserRule() }
                }
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var browserStatus: String {
        if let domain = appState.activeMeetingDomain { return "●  Active on \(domain)" }
        return appState.browserRule.isEnabled ? "○  Watching the frontmost tab" : "○  Off"
    }

    private func browserBinding(_ identifier: String) -> Binding<Bool> {
        Binding(
            get: { appState.browserRule.browserBundleIdentifiers.contains(identifier) },
            set: { appState.setBrowserEnabled(identifier, isEnabled: $0) }
        )
    }

    private func browserDevicePicker(direction: AudioDirection) -> some View {
        Picker(direction.title, selection: Binding(
            get: { direction == .input ? appState.browserRule.inputDeviceID ?? "" : appState.browserRule.outputDeviceID ?? "" },
            set: { appState.setBrowserDevice($0.isEmpty ? nil : $0, for: direction) }
        )) {
            Text("Highest-priority available").tag("")
            ForEach(appState.priorities(for: direction)) { priority in
                Text(priority.name).tag(priority.id)
            }
        }
        .labelsHidden()
    }

    private func addDomain() {
        let value = newDomain
        appState.addBrowserDomain(value)
        if BrowserDomainPolicy.normalizedDomain(value) != nil { newDomain = "" }
    }
}

private struct ApplicationRuleCard: View {
    @EnvironmentObject private var appState: AppState
    let ruleID: String

    private var rule: ApplicationAudioRule? {
        appState.applicationRules.first { $0.id == ruleID }
    }

    var body: some View {
        if let rule {
            let installed = appState.isApplicationInstalled(rule)
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: iconName(for: rule.bundleIdentifier))
                        .font(.title2)
                        .foregroundStyle(installed ? Color.accentColor : Color.secondary)
                        .frame(width: 42, height: 42)
                        .background((installed ? Color.accentColor : Color.secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(rule.displayName)
                            .font(.title3.bold())
                        status(for: rule, installed: installed)
                    }

                    Spacer()

                    if !rule.isPreset {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            appState.removeApplicationRule(rule.id)
                        }
                        .labelStyle(.iconOnly)
                        .help("Remove \(rule.displayName)")
                    }

                    Toggle("Enable \(rule.displayName) automation", isOn: enabledBinding(for: rule))
                        .labelsHidden()
                        .disabled(!installed)
                }

                if installed && rule.isEnabled {
                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 16) {
                        GridRow {
                            Label("Microphone", systemImage: "mic.fill")
                            devicePicker(direction: .input, rule: rule)
                        }
                        GridRow {
                            Label("Listening", systemImage: "headphones")
                            devicePicker(direction: .output, rule: rule)
                        }
                    }

                    HStack {
                        Text("Runs when \(rule.displayName) launches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Test rule now") {
                            appState.testApplicationRule(rule.id)
                        }
                    }
                } else if !installed {
                    Text("Install \(rule.displayName) to make this preset available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(installed && rule.isEnabled ? 22 : 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .opacity(installed ? 1 : 0.62)
        }
    }

    @ViewBuilder
    private func status(for rule: ApplicationAudioRule, installed: Bool) -> some View {
        if appState.isApplicationRunning(rule) {
            Text("●  Running now")
                .foregroundStyle(.green)
                .font(.caption)
        } else if installed {
            Text("○  Installed")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else {
            Text("○  Not installed")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func devicePicker(direction: AudioDirection, rule: ApplicationAudioRule) -> some View {
        Picker(direction.title, selection: deviceBinding(direction: direction, rule: rule)) {
            Text("Highest-priority available").tag("")
            ForEach(appState.priorities(for: direction)) { priority in
                Text(priority.name).tag(priority.id)
            }
        }
        .labelsHidden()
    }

    private func enabledBinding(for rule: ApplicationAudioRule) -> Binding<Bool> {
        Binding(
            get: { appState.applicationRules.first(where: { $0.id == rule.id })?.isEnabled ?? false },
            set: { appState.setApplicationRuleEnabled(rule.id, isEnabled: $0) }
        )
    }

    private func deviceBinding(direction: AudioDirection, rule: ApplicationAudioRule) -> Binding<String> {
        Binding(
            get: {
                guard let current = appState.applicationRules.first(where: { $0.id == rule.id }) else { return "" }
                return direction == .input ? current.inputDeviceID ?? "" : current.outputDeviceID ?? ""
            },
            set: { appState.setApplicationDevice($0.isEmpty ? nil : $0, for: direction, ruleID: rule.id) }
        )
    }

    private func iconName(for bundleIdentifier: String) -> String {
        switch bundleIdentifier {
        case "us.zoom.xos", "com.microsoft.teams2", "Cisco-Systems.Spark", "com.apple.FaceTime": "video.fill"
        case "com.tinyspeck.slackmacgap", "com.hnc.Discord": "bubble.left.and.bubble.right.fill"
        default: "app.fill"
        }
    }
}
