import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            deviceSection(title: "Microphone", devices: appState.inputDevices)
            Divider()
            deviceSection(title: "Listening", devices: appState.outputDevices)
            Divider()
            footer
        }
        .frame(width: 360)
        .alert("FOH couldn’t update audio", isPresented: errorBinding) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOH")
                    .font(.headline)
                Text("Your audio stage")
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

    private func deviceSection(title: String, devices: [AudioDevice]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

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
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
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

