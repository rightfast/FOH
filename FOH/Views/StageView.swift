import SwiftUI
import AppKit

struct StageView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var microphoneMonitor: MicrophoneMonitor
    @Environment(\.openWindow) private var openWindow
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
                    .foregroundStyle(selection == section ? FOHTheme.signal : FOHTheme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        selection == section ? FOHTheme.signal.opacity(0.09) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .overlay(alignment: .leading) {
                        if selection == section {
                            Rectangle().fill(FOHTheme.signal).frame(width: 2, height: 20)
                        }
                    }
                }
                Spacer()
            }
            .padding(10)
            .background(FOHTheme.panel)
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
                ScenesView().environmentObject(appState)
            }
        }
        .sheet(isPresented: Binding(
            get: { !appState.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView().environmentObject(appState)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            appState.refresh()
        }
    }

    private var stageContent: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let notice = appState.automationNotice {
                        automationBanner(notice)
                    }
                    FOHPageHeader(
                        title: "Your audio stage",
                        detail: "See what’s connected and which devices currently have the signal.",
                        status: appState.automationPaused ? "Paused" : "Ready",
                        statusKind: appState.automationPaused ? .paused : .ready
                    )

                    signalRoutes

                    capabilityPanel
                }
                .padding(32)
                .frame(maxWidth: FOHTheme.pageWidth, alignment: .leading)
            }
            .fohCanvas()
            .toolbar {
                Button {
                    openWindow(id: "call-check")
                } label: {
                    Label("Call Check", systemImage: "checkmark.bubble")
                }
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
                .foregroundStyle(FOHTheme.signal)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).font(.headline)
                Text(notice.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if appState.undoState != nil {
                Button("Undo") { appState.undoLastAutomation() }
            }
        }
        .padding(14)
        .background(FOHTheme.signal.opacity(0.07))
        .overlay(alignment: .bottom) { FOHSectionRule() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var signalRoutes: some View {
        VStack(spacing: 0) {
            signalRoute(
                title: "Microphone",
                icon: "mic",
                device: appState.defaultInput,
                alternatives: appState.inputDevices.filter { !appState.isDefault($0) },
                accessory: AnyView(InputActivityView().environmentObject(appState).environmentObject(microphoneMonitor))
            )
            FOHSectionRule()
            signalRoute(
                title: "Listening",
                icon: "headphones",
                device: appState.defaultOutput,
                alternatives: appState.outputDevices.filter { !appState.isDefault($0) },
                accessory: AnyView(
                    Text(appState.defaultOutput.map(outputCapability) ?? "Connect a listening device")
                        .font(.caption).foregroundStyle(FOHTheme.muted)
                )
            )
        }
        .background(FOHTheme.panel)
        .overlay { RoundedRectangle(cornerRadius: FOHTheme.panelRadius).stroke(FOHTheme.rule, lineWidth: 0.7) }
        .clipShape(RoundedRectangle(cornerRadius: FOHTheme.panelRadius))
    }

    private func signalRoute(
        title: String,
        icon: String,
        device: AudioDevice?,
        alternatives: [AudioDevice],
        accessory: AnyView
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon).font(.headline)
                accessory
            }
            .frame(width: 205, alignment: .leading)

            HStack(spacing: 0) {
                Rectangle().fill(FOHTheme.rule).frame(height: 1)
                ZStack {
                    Circle().fill(FOHTheme.panel).frame(width: 22, height: 22)
                    Circle().stroke(FOHTheme.live, lineWidth: 1).frame(width: 22, height: 22)
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(FOHTheme.live)
                }
                Rectangle().fill(FOHTheme.rule).frame(height: 1)
            }
            .frame(minWidth: 64, maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        FOHStatusMark(device == nil ? "Unavailable" : "Active", kind: device == nil ? .warning : .active)
                        Text(device?.name ?? "No device")
                            .font(.headline)
                        Text(device?.transport.rawValue ?? "Not connected")
                            .font(.caption).foregroundStyle(FOHTheme.muted)
                    }
                    Spacer()
                }
                if !alternatives.isEmpty {
                    Text("Available: " + alternatives.prefix(2).map(\.name).joined(separator: ", "))
                        .font(.caption).foregroundStyle(FOHTheme.muted).lineLimit(1)
                }
            }
            .padding(14)
            .frame(width: 240, alignment: .leading)
            .background(FOHTheme.raised)
            .overlay { RoundedRectangle(cornerRadius: 5).stroke(device == nil ? FOHTheme.rule : FOHTheme.live, lineWidth: 0.8) }
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
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
        .background(FOHTheme.panel)
        .overlay { RoundedRectangle(cornerRadius: FOHTheme.panelRadius).stroke(FOHTheme.rule, lineWidth: 0.7) }
        .clipShape(RoundedRectangle(cornerRadius: FOHTheme.panelRadius))
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
