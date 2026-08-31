import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var microphoneMonitor: MicrophoneMonitor
    @EnvironmentObject private var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch FOH at login", isOn: Binding(
                    get: { launchAtLoginController.isEnabled },
                    set: { launchAtLoginController.setEnabled($0) }
                ))
                Toggle("Pause all automation", isOn: Binding(
                    get: { appState.automationPaused },
                    set: { appState.setAutomationPaused($0) }
                ))
                Button("Show Welcome Setup Again") { appState.resetOnboarding() }
            }

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
        .frame(width: 520, height: 430)
        .padding()
        .onAppear { launchAtLoginController.refresh() }
        .alert("Launch at Login", isPresented: Binding(
            get: { launchAtLoginController.errorMessage != nil },
            set: { if !$0 { launchAtLoginController.clearError() } }
        )) {
            Button("OK", role: .cancel) { launchAtLoginController.clearError() }
        } message: {
            Text(launchAtLoginController.errorMessage ?? "Unknown error")
        }
    }
}
