import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var microphoneMonitor: MicrophoneMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            automationControls
            if let notice = appState.automationNotice {
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    Label(notice.title, systemImage: "bolt.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FOHTheme.signal)
                    Text(notice.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            Divider()
            InputActivityView(compact: true)
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
                .padding(14)
            Divider()
            deviceSection(title: "Microphone", devices: appState.inputDevices)
            Divider()
            deviceSection(title: "Listening", devices: appState.outputDevices)
            Divider()
            footer
        }
        .frame(width: 360)
        .background(FOHTheme.canvas)
        .alert("FOH couldn’t update audio", isPresented: errorBinding) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            appState.refresh()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOH")
                    .font(.headline)
                Text(appState.automationPaused ? "Automation paused" : (appState.activeAutomation?.name ?? "Your audio stage"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh devices")
        }
        .padding(14)
    }

    private var automationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let active = appState.activeAutomation {
                Label(active.detail, systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                Button {
                    appState.setAutomationPaused(!appState.automationPaused)
                } label: {
                    Label(appState.automationPaused ? "Resume" : "Pause", systemImage: appState.automationPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
                Button {
                    openWindow(id: "call-check")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Call Check", systemImage: "checkmark.bubble")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                if appState.undoState != nil {
                    Button("Undo") { appState.undoLastAutomation() }
                        .buttonStyle(.plain)
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private func deviceSection(title: String, devices: [AudioDevice]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FOHTheme.muted)

            if devices.isEmpty {
                Text("No devices available")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(devices) { device in
                    DeviceRow(device: device, isSelected: appState.isDefault(device)) {
                        appState.select(device)
                    }
                }
            }
        }
        .padding(14)
    }

    private var footer: some View {
        HStack {
            Button("Open FOH") {
                openWindow(id: "stage")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )
    }
}
