import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    FOHPageHeader(title: "Activity history", detail: "A local record of device changes and decisions FOH made this session.")
                    Spacer()
                    Button("Clear", role: .destructive) { appState.clearHistory() }
                        .disabled(appState.events.isEmpty)
                }

                if appState.events.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Device changes and automatic actions will appear here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.events.reversed()) { event in
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: event.kind.systemImage)
                                    .foregroundStyle(event.kind.tint)
                                    .frame(width: 28, height: 28)
                                    .background(event.kind.tint.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.message)
                                    Text(event.timestamp, format: .dateTime.month().day().hour().minute().second())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 13)
                            if event.id != appState.events.first?.id { Divider().padding(.leading, 42) }
                        }
                    }
                    .padding(.horizontal, 18)
                    .background(FOHTheme.panel)
                    .overlay { RoundedRectangle(cornerRadius: FOHTheme.panelRadius).stroke(FOHTheme.rule, lineWidth: 0.7) }
                    .clipShape(RoundedRectangle(cornerRadius: FOHTheme.panelRadius))
                }
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .fohCanvas()
    }
}
