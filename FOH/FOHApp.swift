import SwiftUI

@main
struct FOHApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var microphoneMonitor = MicrophoneMonitor()

    var body: some Scene {
        WindowGroup(id: "stage") {
            StageView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
                .frame(minWidth: 760, minHeight: 520)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
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
        }
    }
}
