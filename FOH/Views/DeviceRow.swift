import SwiftUI

struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: device.direction.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? FOHTheme.signal : FOHTheme.muted)

                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(capabilitySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FOHTheme.live)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? FOHTheme.signal.opacity(0.07) : Color.clear)
            .overlay(alignment: .leading) {
                if isSelected { Rectangle().fill(FOHTheme.signal).frame(width: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(device.name), \(isSelected ? "selected" : "available")")
    }

    private var capabilitySummary: String {
        var details = [device.transport.rawValue]
        if device.canSetVolume { details.append(device.direction == .input ? "gain" : "volume") }
        if device.canSetMute { details.append("mute") }
        return details.joined(separator: " · ")
    }
}
