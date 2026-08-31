import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isExporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summary

                ForEach(AudioDirection.allCases, id: \.self) { direction in
                    let devices = appState.devices.filter { $0.direction == direction }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(direction.title)
                            .font(.title2.bold())
                        ForEach(devices) { device in
                            DiagnosticDeviceCard(device: device, isDefault: appState.isDefault(device))
                        }
                    }
                }

                eventHistory
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileExporter(
            isPresented: $isExporting,
            document: DiagnosticReportDocument(report: appState.diagnosticReport),
            contentType: .json,
            defaultFilename: "FOH-Diagnostics"
        ) { result in
            if case .failure(let error) = result {
                appState.errorMessage = error.localizedDescription
            }
        }
        .toolbar {
            Button {
                appState.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button {
                isExporting = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hardware diagnostics")
                    .font(.largeTitle.bold())
                Text("Inspect what each connected audio endpoint actually supports.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label("Audio stays local", systemImage: "lock.shield.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(.green)
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryItem("Endpoints", value: "\(appState.devices.count)", icon: "hifispeaker.2")
            summaryItem("Inputs", value: "\(appState.inputDevices.count)", icon: "mic")
            summaryItem("Outputs", value: "\(appState.outputDevices.count)", icon: "speaker.wave.2")
            summaryItem("Events", value: "\(appState.events.count)", icon: "waveform.path.ecg")
        }
    }

    private func summaryItem(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var eventHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Core Audio activity")
                    .font(.title2.bold())
                Spacer()
                Text("Last \(appState.events.count) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.events.isEmpty {
                Text("No events recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.events.reversed()) { event in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: event.kind.systemImage)
                                .foregroundStyle(event.kind.tint)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.message)
                                Text(event.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        if event.id != appState.events.first?.id { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct DiagnosticDeviceCard: View {
    let device: AudioDevice
    let isDefault: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: device.direction.systemImage)
                    .font(.title2)
                    .foregroundStyle(isDefault ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                    Text([device.manufacturer, device.transport.rawValue].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isDefault {
                    Text("DEFAULT")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                statusBadge
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 9) {
                diagnosticRow("Channels", "\(device.channelCount)", "Sample rate", sampleRate)
                diagnosticRow("Volume", capability(device.canSetVolume, readable: device.volume != nil), "Mute", capability(device.canSetMute, readable: device.isMuted != nil))
                diagnosticRow("Input gain", device.direction == .input ? capability(device.canSetGain, readable: device.volume != nil) : "Not applicable", "Running", device.isRunning ? "Yes" : "No")
                diagnosticRow("Core Audio ID", "\(device.objectID)", "UID", device.uid)
            }
            .font(.callout)
            .textSelection(.enabled)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusBadge: some View {
        Label(device.isAlive ? "Available" : "Unavailable", systemImage: device.isAlive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(device.isAlive ? .green : .orange)
    }

    private var sampleRate: String {
        guard let rate = device.nominalSampleRate else { return "Unavailable" }
        return rate.formatted(.number.precision(.fractionLength(0))) + " Hz"
    }

    private func capability(_ writable: Bool, readable: Bool) -> String {
        if writable { return "Read and write" }
        if readable { return "Read only" }
        return "Unavailable"
    }

    private func diagnosticRow(_ firstTitle: String, _ firstValue: String, _ secondTitle: String, _ secondValue: String) -> some View {
        GridRow {
            Text(firstTitle).foregroundStyle(.secondary)
            Text(firstValue)
            Text(secondTitle).foregroundStyle(.secondary)
            Text(secondValue).lineLimit(1).truncationMode(.middle)
        }
    }
}

extension DiagnosticEventKind {
    var systemImage: String {
        switch self {
        case .appStarted: "power"
        case .hardwareChanged: "waveform.path.ecg"
        case .deviceConnected: "plus.circle"
        case .deviceDisconnected: "minus.circle"
        case .defaultInputChanged: "mic"
        case .defaultOutputChanged: "speaker.wave.2"
        case .deviceSelected: "checkmark.circle"
        case .priorityChanged: "arrow.up.arrow.down"
        case .automationChanged: "switch.2"
        case .automaticFallback: "arrow.triangle.branch"
        case .preferredRestored: "arrow.uturn.backward.circle"
        case .applicationDetected: "app.badge"
        case .applicationRuleChanged: "slider.horizontal.3"
        case .applicationRuleApplied: "bolt.circle"
        case .error: "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .error: .red
        case .deviceConnected, .preferredRestored, .applicationRuleApplied: .green
        case .deviceDisconnected: .orange
        case .automaticFallback: .purple
        default: .accentColor
        }
    }
}
