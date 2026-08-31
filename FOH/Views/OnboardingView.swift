import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private let steps = ["Welcome", "Devices", "Apps", "Privacy", "Ready"]

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                header
                ZStack {
                    page.id(step).transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                footer
            }
        }
        .frame(width: 720, height: 560)
        .interactiveDismissDisabled()
    }

    private var backdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [Color.accentColor.opacity(0.16), .clear], center: .topTrailing, startRadius: 24, endRadius: 470)
            Circle().fill(Color.purple.opacity(0.08)).frame(width: 300).blur(radius: 70).offset(x: -310, y: 240)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 22) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.gradient)
                    Image(systemName: "slider.horizontal.3").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)
                Text("FOH").font(.headline.weight(.bold))
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 7) {
                        ZStack {
                            Circle().fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.15)).frame(width: 22, height: 22)
                            if index < step {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            } else {
                                Text("\(index + 1)").font(.caption2.weight(.bold)).foregroundStyle(index == step ? .white : .secondary)
                            }
                        }
                        if index == step { Text(steps[index]).font(.caption.weight(.semibold)).transition(.opacity) }
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: step)
        }
        .padding(.horizontal, 28)
        .frame(height: 66)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.6) }
    }

    @ViewBuilder private var page: some View {
        switch step {
        case 0: welcome
        case 1: devices
        case 2: automations
        case 3: privacy
        default: ready
        }
    }

    private var footer: some View {
        HStack {
            Button("Back") { move(to: step - 1) }.disabled(step == 0)
            Spacer()
            Text(step == 4 ? "You can change any of this later." : "Takes about a minute")
                .font(.caption).foregroundStyle(.tertiary)
            Button(step == 4 ? "Take the stage" : "Continue") {
                step == 4 ? appState.completeOnboarding() : move(to: step + 1)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28).frame(height: 72).background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
    }

    private var welcome: some View {
        HStack(spacing: 44) {
            VStack(alignment: .leading, spacing: 18) {
                eyebrow("YOUR MAC, IN HARMONY")
                Text("Sound check,\nwithout the scramble.")
                    .font(.system(size: 38, weight: .bold, design: .rounded)).tracking(-0.7)
                Text("FOH keeps the right microphone and headphones ready—at your desk, on a call, or wherever work takes you.")
                    .font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Label("Everything stays on your Mac", systemImage: "lock.fill")
                    .font(.callout.weight(.medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MiniMixingDesk().frame(width: 245, height: 270)
        }
        .padding(.horizontal, 48).padding(.vertical, 34)
    }

    private var devices: some View {
        standardPage(eyebrow: "CONNECTED GEAR", title: "Set it once. FOH keeps watch.", detail: "We found \(appState.inputDevices.count) microphone \(optionWord(appState.inputDevices.count)) and \(appState.outputDevices.count) listening \(optionWord(appState.outputDevices.count)).") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    summaryPill(icon: "mic.fill", count: appState.inputDevices.count, label: "Microphones")
                    summaryPill(icon: "headphones", count: appState.outputDevices.count, label: "Listening")
                }
                settingRow(icon: "cable.connector", title: "Follow connected devices", detail: "Move to the best available device when your setup changes.", isOn: $appState.automaticSwitching)
                settingRow(icon: "arrow.uturn.backward.circle", title: "Welcome favorites back", detail: "Restore a preferred device when it reconnects.", isOn: $appState.restoresPreferredDevice)
            }
        }
    }

    private var automations: some View {
        standardPage(eyebrow: "SMART PRESETS", title: "Ready when the call starts.", detail: "Turn on presets for apps you use. Apps that aren’t installed stay visible, so you’ll know what FOH can support.") {
            ScrollView {
                VStack(spacing: 9) {
                    ForEach(appState.applicationRules.filter(\.isPreset)) { rule in
                        let installed = appState.isApplicationInstalled(rule)
                        Toggle(isOn: Binding(get: { rule.isEnabled }, set: { appState.setApplicationRuleEnabled(rule.id, isEnabled: $0) })) {
                            HStack(spacing: 12) {
                                Image(systemName: installed ? "video.fill" : "square.dashed")
                                    .foregroundStyle(installed ? Color.accentColor : Color.secondary)
                                    .frame(width: 28, height: 28).background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rule.displayName).font(.callout.weight(.semibold))
                                    Text(installed ? "Ready to configure" : "Not installed on this Mac").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .toggleStyle(.switch).disabled(!installed).opacity(installed ? 1 : 0.52)
                        .padding(.horizontal, 14).frame(height: 54)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
            .frame(maxHeight: 218)
        }
    }

    private var privacy: some View {
        standardPage(eyebrow: "PRIVATE BY DESIGN", title: "Your audio is yours.", detail: "FOH works locally, without an account or cloud service. It listens for devices—not to you.") {
            HStack(spacing: 12) {
                privacyCard(icon: "waveform", title: "No recordings", detail: "Activity is measured only when its meter is visible.")
                privacyCard(icon: "person.crop.circle.badge.xmark", title: "No account", detail: "Open the app and get to work. Nothing to sign into.")
                privacyCard(icon: "lock.shield.fill", title: "Safe diagnostics", detail: "Exports omit device names and stable identifiers.")
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 22) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle().stroke(Color.accentColor.opacity(0.12 - Double(index) * 0.025), lineWidth: 1)
                        .frame(width: CGFloat(126 + index * 42), height: CGFloat(126 + index * 42))
                }
                Circle().fill(Color.green.gradient).frame(width: 88, height: 88)
                    .shadow(color: Color.green.opacity(0.28), radius: 24, y: 8)
                Image(systemName: "checkmark").font(.system(size: 35, weight: .bold)).foregroundStyle(.white)
            }
            VStack(spacing: 8) {
                Text("Your stage is ready.").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("FOH is standing by in your menu bar.").font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 24) {
                readyFeature(icon: "menubar.rectangle", title: "Quick changes")
                readyFeature(icon: "slider.horizontal.3", title: "One-click Scenes")
                readyFeature(icon: "checkmark.bubble", title: "Call Check")
            }
        }
    }

    private func standardPage<Content: View>(eyebrow: String, title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                self.eyebrow(eyebrow)
                Text(title).font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-0.4)
                Text(detail).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(.horizontal, 54).padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text).font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(Color.accentColor)
    }

    private func settingRow(icon: String, title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 13) {
                Image(systemName: icon).font(.title3).foregroundStyle(Color.accentColor).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch).padding(.horizontal, 16).frame(height: 62)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func summaryPill(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
            Text("\(count)").font(.headline.monospacedDigit())
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).frame(height: 38)
        .background(Color.accentColor.opacity(0.09), in: Capsule())
    }

    private func privacyCard(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38).background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func readyFeature(icon: String, title: String) -> some View {
        Label(title, systemImage: icon).font(.callout.weight(.medium)).foregroundStyle(.secondary)
    }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
    }

    private func move(to value: Int) {
        let update = { step = min(max(value, 0), 4) }
        if reduceMotion { update() } else { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { update() } }
    }

    private func optionWord(_ count: Int) -> String { count == 1 ? "option" : "options" }
}

private struct MiniMixingDesk: View {
    private let channels: [(String, CGFloat, Color)] = [("MIC", 0.68, .cyan), ("OUT", 0.42, .purple)]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28).fill(.regularMaterial).shadow(color: .black.opacity(0.14), radius: 28, y: 14)
            RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.18), lineWidth: 1)
            HStack(spacing: 30) {
                ForEach(Array(channels.enumerated()), id: \.offset) { _, channel in
                    VStack(spacing: 12) {
                        Circle().fill(channel.2).frame(width: 7, height: 7).shadow(color: channel.2.opacity(0.7), radius: 5)
                        Text(channel.0).font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(.secondary)
                        ZStack(alignment: .bottom) {
                            Capsule().fill(Color.primary.opacity(0.11)).frame(width: 5, height: 135)
                            Capsule().fill(channel.2.gradient).frame(width: 5, height: 135 * channel.1)
                            RoundedRectangle(cornerRadius: 5).fill(.thickMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.3)))
                                .shadow(color: .black.opacity(0.18), radius: 4, y: 2).frame(width: 35, height: 18)
                                .offset(y: -124 * channel.1 + 9)
                        }
                        Text("\(Int(channel.1 * 100))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A two-channel mixing desk for microphone and listening devices")
    }
}
