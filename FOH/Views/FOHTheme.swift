import AppKit
import SwiftUI

enum FOHTheme {
    static let signal = adaptive(light: 0xC84E24, dark: 0xF07145)
    static let live = adaptive(light: 0x286247, dark: 0x63B58C)
    static let caution = adaptive(light: 0x9B5A18, dark: 0xE0A253)
    static let danger = adaptive(light: 0xA43F3B, dark: 0xE57A74)
    static let canvas = adaptive(light: 0xF2EBDD, dark: 0x1D1C1A)
    static let panel = adaptive(light: 0xF8F4EA, dark: 0x252421)
    static let raised = adaptive(light: 0xFFFDF7, dark: 0x2D2B27)
    static let ink = adaptive(light: 0x252522, dark: 0xF1EBDD)
    static let muted = adaptive(light: 0x6E695F, dark: 0xAAA398)
    static let rule = adaptive(light: 0xCEC5B5, dark: 0x4B4842)

    static let panelRadius: CGFloat = 7
    static let pageWidth: CGFloat = 920
    static let formLabelWidth: CGFloat = 108
    static let controlRowHeight: CGFloat = 62

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return nsColor(match == .darkAqua ? dark : light)
        })
    }

    private static func nsColor(_ value: UInt32) -> NSColor {
        NSColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct FOHPageHeader: View {
    let title: String
    let detail: String
    var status: String?
    var statusKind: FOHStatusKind = .ready

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(FOHTheme.ink)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(FOHTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let status { FOHStatusMark(status, kind: statusKind) }
        }
    }
}

enum FOHStatusKind {
    case ready, active, available, paused, warning

    var color: Color {
        switch self {
        case .ready, .active: FOHTheme.live
        case .available: FOHTheme.muted
        case .paused, .warning: FOHTheme.caution
        }
    }

    var symbol: String {
        switch self {
        case .ready, .active: "checkmark"
        case .available: "circle"
        case .paused: "pause.fill"
        case .warning: "exclamationmark"
        }
    }
}

struct FOHStatusMark: View {
    let title: String
    let kind: FOHStatusKind

    init(_ title: String, kind: FOHStatusKind) {
        self.title = title
        self.kind = kind
    }

    var body: some View {
        Label(title, systemImage: kind.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(kind.color)
            .labelStyle(.titleAndIcon)
    }
}

struct FOHPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(FOHTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: FOHTheme.panelRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FOHTheme.panelRadius, style: .continuous)
                    .stroke(FOHTheme.rule, lineWidth: 0.7)
            }
    }
}

struct FOHSectionRule: View {
    var body: some View {
        Rectangle().fill(FOHTheme.rule).frame(height: 0.7)
    }
}

extension View {
    func fohCanvas() -> some View {
        self
            .background(FOHTheme.canvas)
            .tint(FOHTheme.signal)
            .foregroundStyle(FOHTheme.ink)
    }
}
