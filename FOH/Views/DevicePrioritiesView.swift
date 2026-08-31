import SwiftUI

struct DevicePrioritiesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                automationCard
                ForEach(AudioDirection.allCases, id: \.self) { direction in
                    priorityCard(direction)
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            Button("Reset order", systemImage: "arrow.counterclockwise") {
                appState.resetPriorities()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Device priorities")
                .font(.largeTitle.bold())
            Text("FOH picks the first available device in each list when your setup changes.")
                .foregroundStyle(.secondary)
        }
    }

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $appState.automaticSwitching) {
                Label("Automatic fallback", systemImage: "arrow.triangle.branch")
                    .font(.headline)
            }
            Text("If the current device disconnects, FOH selects the highest-priority device that is still available.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Restore a preferred device when it reconnects", isOn: $appState.restoresPreferredDevice)
                .disabled(!appState.automaticSwitching)
            Text("Manual device changes remain untouched until a device connects or disconnects.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func priorityCard(_ direction: AudioDirection) -> some View {
        let priorities = appState.priorities(for: direction)
        return VStack(alignment: .leading, spacing: 14) {
            Label(direction.title, systemImage: direction.systemImage)
                .font(.title2.bold())

            if priorities.isEmpty {
                ContentUnavailableView(
                    "No known devices",
                    systemImage: direction.systemImage,
                    description: Text("Connect a device and FOH will add it here.")
                )
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(priorities.enumerated()), id: \.element.id) { index, priority in
                        priorityRow(priority, position: index, count: priorities.count)
                        if index < priorities.count - 1 { Divider().padding(.leading, 48) }
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func priorityRow(_ priority: DevicePriority, position: Int, count: Int) -> some View {
        let device = appState.device(for: priority)
        return HStack(spacing: 12) {
            Text("\(position + 1)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(priority.name)
                        .fontWeight(device.map(appState.isDefault) == true ? .semibold : .regular)
                    if device.map(appState.isDefault) == true {
                        Text("IN USE")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Label(
                    device == nil ? "Not connected" : "Available · \(device?.transport.rawValue ?? "")",
                    systemImage: device == nil ? "circle.dashed" : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(device == nil ? Color.secondary : Color.green)
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    appState.movePriority(priority, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(position == 0)
                .help("Move up")

                Button {
                    appState.movePriority(priority, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(position == count - 1)
                .help("Move down")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 11)
    }
}
