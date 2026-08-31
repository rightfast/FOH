import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var microphoneMonitor: MicrophoneMonitor

    var body: some View {
        Form {
            Section("About this build") {
                LabeledContent("Bundle ID", value: "studio.rightfast.foh")
                LabeledContent("Minimum macOS", value: "14.0")
                LabeledContent("Connected devices", value: "\(appState.devices.count)")
            }

            Section("Privacy") {
                LabeledContent("Input activity", value: microphoneMonitor.isEnabled ? "Enabled" : "Off")
                Text("When you enable input activity, FOH analyzes microphone levels locally only while its window or menu is visible. Audio is never recorded, retained, or transmitted.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 300)
        .padding()
    }
}
