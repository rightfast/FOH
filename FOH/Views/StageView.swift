import SwiftUI

struct StageView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List {
                Label("Stage", systemImage: "slider.horizontal.3")
                Label("Devices", systemImage: "hifispeaker.2")
                Label("Scenes", systemImage: "rectangle.stack")
                Label("Automations", systemImage: "bolt")
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your audio stage")
                            .font(.largeTitle.bold())
                        Text("See what’s connected and put the right gear onstage.")
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        activeCard(
                            title: "Microphone",
                            device: appState.defaultInput,
                            icon: "mic.fill"
                        )
                        activeCard(
                            title: "Listening",
                            device: appState.defaultOutput,
                            icon: "headphones"
                        )
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
    }

    private func activeCard(title: String, device: AudioDevice?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(device?.name ?? "No device")
                .font(.title2.weight(.semibold))
            Text(device?.transport.rawValue ?? "Not connected")
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
}

