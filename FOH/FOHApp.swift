import SwiftUI

@main
struct FOHApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var microphoneMonitor = MicrophoneMonitor()
    @StateObject private var outputTonePlayer = OutputTonePlayer()
    @StateObject private var launchAtLoginController = LaunchAtLoginController()

    var body: some Scene {
        WindowGroup(id: "stage") {
            StageView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
                .environmentObject(outputTonePlayer)
                .frame(minWidth: 760, minHeight: 520)
        }

        WindowGroup(id: "call-check") {
            CallCheckView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
                .environmentObject(outputTonePlayer)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
                .environmentObject(outputTonePlayer)
        } label: {
            Image("FOHMenuBarTemplate")
                .renderingMode(.template)
                .accessibilityLabel("FOH")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
                .environmentObject(launchAtLoginController)
        }
    }
}
