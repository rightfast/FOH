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

                LazyVStack(spacing: 14) {
                    ForEach(appState.applicationRules) { rule in
                        ApplicationRuleCard(ruleID: rule.id)
                    }
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )
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
                .disabled(!installed || !rule.isEnabled)

                HStack {
                    Text(installed ? "Runs when \(rule.displayName) launches" : "Install \(rule.displayName) to enable this preset")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Test rule now") {
                        appState.testApplicationRule(rule.id)
                    }
                    .disabled(!installed || !rule.isEnabled)
                }
            }
            .padding(22)
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
