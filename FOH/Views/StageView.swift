import SwiftUI

struct StageView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var microphoneMonitor: MicrophoneMonitor
    @State private var selection: AppSection? = .stage

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selection == section ? Color.white : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        selection == section ? Color.accentColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                Spacer()
            }
            .padding(10)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            switch selection ?? .stage {
            case .stage:
                stageContent
            case .devices:
                DevicePrioritiesView()
                    .environmentObject(appState)
            case .history:
                HistoryView()
                    .environmentObject(appState)
            case .diagnostics:
                DiagnosticsView()
                    .environmentObject(appState)
            case .automations:
                AutomationsView()
                    .environmentObject(appState)
            case .scenes:
                let section = selection ?? .stage
                comingSoon(section.title, icon: section.systemImage)
            }
        }
    }

    private var stageContent: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let notice = appState.automationNotice {
                        automationBanner(notice)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Your audio stage")
                                .font(.largeTitle.bold())
                            Spacer()
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        Text("See what’s connected and put the right gear onstage.")
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        microphoneCard
                        listeningCard
                    }

                    capabilityPanel
                }
                .padding(32)
                .frame(maxWidth: 900, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                Button {
                    appState.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
    }

    private func automationBanner(_ notice: AutomationNotice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).font(.headline)
                Text(notice.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var microphoneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Microphone", systemImage: "mic.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(appState.defaultInput?.name ?? "No device")
                .font(.title2.weight(.semibold))
            Text(appState.defaultInput?.transport.rawValue ?? "Not connected")
                .foregroundStyle(.secondary)
            Divider()
            InputActivityView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var listeningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Listening", systemImage: "headphones")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(appState.defaultOutput?.name ?? "No device")
                .font(.title2.weight(.semibold))
            Text(appState.defaultOutput?.transport.rawValue ?? "Not connected")
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                Label(
                    appState.defaultOutput == nil ? "Unavailable" : "System default",
                    systemImage: appState.defaultOutput == nil ? "exclamationmark.circle" : "checkmark.circle.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(appState.defaultOutput == nil ? Color.secondary : Color.green)
                Spacer()
                if let output = appState.defaultOutput {
                    Text(outputCapability(output))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 48)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func comingSoon(_ title: String, icon: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: icon,
            description: Text("This workspace will arrive after hardware behavior is verified.")
        )
    }

    private var capabilityPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected devices")
                .font(.title2.bold())

            ForEach(AudioDirection.allCases, id: \.self) { direction in
                let devices = appState.devices.filter { $0.direction == direction }
                DisclosureGroup("\(direction.title) (\(devices.count))") {
                    VStack(spacing: 14) {
                        ForEach(devices) { device in
                            DeviceRow(device: device, isSelected: appState.isDefault(device)) {
                                appState.select(device)
                            }
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func outputCapability(_ device: AudioDevice) -> String {
        if device.canSetVolume { return "Volume adjustable" }
        if device.canSetMute { return "Mute available" }
        return "System controlled"
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case stage
    case devices
    case scenes
    case automations
    case history
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stage: "Stage"
        case .devices: "Devices"
        case .scenes: "Scenes"
        case .automations: "Automations"
        case .history: "History"
        case .diagnostics: "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .stage: "slider.horizontal.3"
        case .devices: "hifispeaker.2"
        case .scenes: "rectangle.stack"
        case .automations: "bolt"
        case .history: "clock.arrow.circlepath"
        case .diagnostics: "stethoscope"
        }
    }
}
