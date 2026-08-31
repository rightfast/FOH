import SwiftUI

struct CallCheckView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var microphoneMonitor: MicrophoneMonitor
    @EnvironmentObject private var outputTonePlayer: OutputTonePlayer
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Call Check", systemImage: "checkmark.bubble")
                    .font(.headline)
                Spacer()
                Text("\(min(step + 1, 4)) of 4")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()

            Group {
                switch step {
                case 0: microphoneStep
                case 1: outputStep
                case 2: automationStep
                default: readyStep
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                Button("Back") { step -= 1 }
                    .disabled(step == 0 || step >= 3)
                Spacer()
                if step < 3 {
                    Button("Continue") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 460)
        .fohCanvas()
        .onAppear { appState.refresh() }
    }

    private var microphoneStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("Check your microphone", "Speak normally and look for movement in the waveform.", "mic.fill")
            deviceStatus(appState.defaultInput?.name ?? "No microphone selected", available: appState.defaultInput != nil)
            InputActivityView()
                .environmentObject(appState)
                .environmentObject(microphoneMonitor)
                .padding(18)
                .background(FOHTheme.panel)
                .overlay { RoundedRectangle(cornerRadius: FOHTheme.panelRadius).stroke(FOHTheme.rule, lineWidth: 0.7) }
        }
    }

    private var outputStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("Check your listening device", "Play a short tone and confirm you hear it in the right place.", "headphones")
            deviceStatus(appState.defaultOutput?.name ?? "No listening device selected", available: appState.defaultOutput != nil)
            Button {
                outputTonePlayer.play()
            } label: {
                Label(outputTonePlayer.isPlaying ? "Playing test tone…" : "Play Test Sound", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appState.defaultOutput == nil || outputTonePlayer.isPlaying)
            if let error = outputTonePlayer.errorMessage {
                Text(error).font(.caption).foregroundStyle(FOHTheme.danger)
            }
        }
    }

    private var automationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("Confirm automation", "FOH will keep this setup ready using the rules you’ve enabled.", "bolt.fill")
            statusRow("Automation", appState.automationPaused ? "Paused" : "Running", good: !appState.automationPaused)
            statusRow("Active scene", appState.activeScene?.name ?? "None", good: appState.activeScene != nil)
            statusRow("App rules", "\(appState.applicationRules.filter(\.isEnabled).count) enabled", good: appState.applicationRules.contains(where: \.isEnabled))
            if appState.automationPaused {
                Button("Resume Automation") { appState.setAutomationPaused(false) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(FOHTheme.live)
            Text("You’re ready for the call").font(.largeTitle.bold())
            Text("FOH is using \(appState.defaultInput?.name ?? "your microphone") and \(appState.defaultOutput?.name ?? "your listening device").")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Run Check Again") { step = 0 }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepHeader(_ title: String, _ detail: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(FOHTheme.signal)
            Text(title).font(.system(size: 28, weight: .semibold))
            Text(detail).foregroundStyle(.secondary)
        }
    }

    private func deviceStatus(_ name: String, available: Bool) -> some View {
        HStack {
            Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(available ? FOHTheme.live : FOHTheme.caution)
            Text(name).font(.headline)
        }
    }

    private func statusRow(_ label: String, _ value: String, good: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Label(value, systemImage: good ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(good ? FOHTheme.live : FOHTheme.muted)
        }
        .padding(14)
        .background(FOHTheme.panel)
        .overlay(alignment: .bottom) { FOHSectionRule() }
    }
}
