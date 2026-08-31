import SwiftUI

struct InputActivityView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var monitor: MicrophoneMonitor
    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack {
                Label("Input activity", systemImage: "waveform")
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                Spacer()
                passiveStatus
            }

            switch monitor.authorization {
            case .denied:
                Text("Microphone access is off. Allow FOH in Privacy & Security to show activity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .notDetermined:
                enablePrompt
            case .authorized where !monitor.isEnabled:
                enablePrompt
            default:
                waveform
            }
        }
        .onAppear { monitor.beginVisiblePresentation() }
        .onDisappear { monitor.endVisiblePresentation() }
        .onChange(of: monitor.isMonitoring) {
            appState.refresh()
        }
    }

    private var waveform: some View {
        VStack(alignment: .leading, spacing: 7) {
            WaveformView(samples: monitor.samples)
                .frame(height: compact ? 34 : 48)
                .accessibilityLabel(monitor.isMonitoring ? "Live microphone activity" : "Microphone monitor paused")
                .accessibilityValue(activityDescription)

            HStack {
                Label(
                    monitor.isMonitoring ? "Listening locally" : "Waiting for microphone",
                    systemImage: monitor.isMonitoring ? "lock.fill" : "pause.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Turn off") { monitor.disable() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
            }

            if let errorMessage = monitor.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(FOHTheme.danger)
            }
        }
    }

    private var enablePrompt: some View {
        HStack(spacing: 10) {
            Text("See whether your selected microphone is receiving sound.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Enable") { monitor.enable() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private var passiveStatus: some View {
        let running = appState.defaultInput?.isRunning == true
        return Label(running ? "In use" : "Idle", systemImage: running ? "circle.fill" : "circle")
            .font(.caption2.weight(.medium))
            .foregroundStyle(running ? FOHTheme.live : FOHTheme.muted)
    }

    private var activityDescription: String {
        guard monitor.isMonitoring else { return "Paused" }
        return (monitor.samples.last ?? 0) > 0.12 ? "Receiving audio" : "Quiet"
    }
}

private struct WaveformView: View {
    let samples: [Double]

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let spacing: CGFloat = 2
            let width = max(1, (size.width - spacing * CGFloat(samples.count - 1)) / CGFloat(samples.count))
            for (index, sample) in samples.enumerated() {
                let normalized = CGFloat(min(1, max(0.04, sample)))
                let height = max(3, normalized * size.height)
                let rect = CGRect(
                    x: CGFloat(index) * (width + spacing),
                    y: (size.height - height) / 2,
                    width: width,
                    height: height
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: width / 2),
                    with: .color(normalized > 0.82 ? FOHTheme.caution : FOHTheme.signal)
                )
            }
        }
    }
}
