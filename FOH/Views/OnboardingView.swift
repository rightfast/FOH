import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(24)

            Group {
                switch step {
                case 0: welcome
                case 1: devices
                case 2: automations
                case 3: privacy
                default: ready
                }
            }
            .padding(.horizontal, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                Button("Back") { step -= 1 }.disabled(step == 0)
                Spacer()
                Button(step == 4 ? "Start Using FOH" : "Continue") {
                    if step == 4 { appState.completeOnboarding() } else { step += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 640, height: 520)
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        intro(icon: "slider.horizontal.3", title: "Welcome to FOH", detail: "A calm, dependable front of house for your Mac’s microphone and listening devices.")
    }

    private var devices: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro(icon: "hifispeaker.2.fill", title: "Your devices", detail: "FOH found \(appState.inputDevices.count) microphone options and \(appState.outputDevices.count) listening options.")
            Toggle("Switch automatically when devices connect", isOn: $appState.automaticSwitching)
            Toggle("Restore a preferred device when it returns", isOn: $appState.restoresPreferredDevice)
        }
    }

    private var automations: some View {
        VStack(alignment: .leading, spacing: 18) {
            intro(icon: "bolt.fill", title: "Ready for your work apps", detail: "Enable installed presets now. You can add any other Mac app later.")
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(appState.applicationRules.filter(\.isPreset)) { rule in
                        let installed = appState.isApplicationInstalled(rule)
                        Toggle(isOn: Binding(
                            get: { rule.isEnabled },
                            set: { appState.setApplicationRuleEnabled(rule.id, isEnabled: $0) }
                        )) {
                            HStack {
                                Text(rule.displayName)
                                Spacer()
                                Text(installed ? "Installed" : "Not installed")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!installed)
                        .opacity(installed ? 1 : 0.55)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 18) {
            intro(icon: "hand.raised.fill", title: "Private by design", detail: "FOH works locally on your Mac. It doesn’t create an account, record audio, or send device information anywhere.")
            Label("Microphone activity is analyzed only while visible and enabled.", systemImage: "waveform")
            Label("Browser meeting detection is optional and off until you enable it.", systemImage: "safari")
            Label("Diagnostic exports remove device names and stable identifiers.", systemImage: "lock.shield")
        }
    }

    private var ready: some View {
        intro(icon: "checkmark.circle.fill", title: "Your stage is ready", detail: "Use the menu bar for quick changes, Scenes for one-click setups, and Call Check before an important meeting.")
    }

    private func intro(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 42)).foregroundStyle(Color.accentColor)
            Text(title).font(.largeTitle.bold())
            Text(detail).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
