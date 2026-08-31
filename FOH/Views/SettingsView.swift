import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("About this build") {
                LabeledContent("Bundle ID", value: "studio.rightfast.foh")
                LabeledContent("Minimum macOS", value: "14.0")
                LabeledContent("Connected devices", value: "\(appState.devices.count)")
            }

            Section("Privacy") {
                Text("FOH currently reads audio-device metadata only. It does not capture, record, or transmit audio.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 300)
        .padding()
    }
}

