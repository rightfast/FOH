import SwiftUI

struct AutomationsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Automations")
                        .font(.largeTitle.bold())
                    Text("Put the right devices onstage when a work app opens.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 42, height: 42)
                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Zoom Workplace")
                                .font(.title2.bold())
                            Text(appState.isZoomRunning ? "●  Running now" : "○  Not running")
                                .font(.caption)
                                .foregroundStyle(appState.isZoomRunning ? Color.green : Color.secondary)
                        }
                        Spacer()
                        Toggle("Enable Zoom automation", isOn: enabled)
                            .labelsHidden()
                    }

                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 16) {
                        GridRow {
                            Label("Microphone", systemImage: "mic.fill")
                            Picker("Microphone", selection: inputSelection) {
                                Text("Highest-priority available").tag("")
                                ForEach(appState.priorities(for: .input)) { priority in
                                    Text(priority.name).tag(priority.id)
                                }
                            }
                            .labelsHidden()
                        }
                        GridRow {
                            Label("Listening", systemImage: "headphones")
                            Picker("Listening", selection: outputSelection) {
                                Text("Highest-priority available").tag("")
                                ForEach(appState.priorities(for: .output)) { priority in
                                    Text(priority.name).tag(priority.id)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .disabled(!appState.zoomRule.isEnabled)

                    HStack {
                        Text("Runs when Zoom launches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Test rule now") { appState.testZoomRule() }
                            .disabled(!appState.zoomRule.isEnabled)
                    }
                }
                .padding(22)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zoom should use “Same as System”")
                            .font(.headline)
                        Text("FOH changes the macOS system defaults when Zoom launches. A device pinned inside Zoom can take precedence. FOH leaves devices unchanged when Zoom quits.")
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
    }

    private var enabled: Binding<Bool> {
        Binding(
            get: { appState.zoomRule.isEnabled },
            set: { appState.setZoomRuleEnabled($0) }
        )
    }

    private var inputSelection: Binding<String> {
        Binding(
            get: { appState.zoomRule.inputDeviceID ?? "" },
            set: { appState.setZoomDevice($0.isEmpty ? nil : $0, for: .input) }
        )
    }

    private var outputSelection: Binding<String> {
        Binding(
            get: { appState.zoomRule.outputDeviceID ?? "" },
            set: { appState.setZoomDevice($0.isEmpty ? nil : $0, for: .output) }
        )
    }
}
