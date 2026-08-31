import SwiftUI

@main
struct FOHApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: "stage") {
            StageView()
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 520)
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "slider.horizontal.3")
                .accessibilityLabel("FOH")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

