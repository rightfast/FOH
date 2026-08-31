import Foundation

struct SupportedBrowser: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: Kind

    enum Kind: Sendable {
        case safari
        case chromium
    }

    static let all: [SupportedBrowser] = [
        SupportedBrowser(id: "com.apple.Safari", name: "Safari", kind: .safari),
        SupportedBrowser(id: "com.google.Chrome", name: "Google Chrome", kind: .chromium),
    ]
}

struct BrowserAudioRule: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var browserBundleIdentifiers: Set<String>
    var domains: [String]
    var inputDeviceID: String?
    var outputDeviceID: String?

    static let standard = BrowserAudioRule(
        isEnabled: false,
        browserBundleIdentifiers: Set(SupportedBrowser.all.map(\.id)),
        domains: ["meet.google.com", "zoom.us", "teams.microsoft.com", "riverside.fm"],
        inputDeviceID: nil,
        outputDeviceID: nil
    )
}

enum BrowserDomainPolicy {
    static func normalizedDomain(_ value: String) -> String? {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !candidate.contains("://") { candidate = "https://" + candidate }
        guard let host = URL(string: candidate)?.host?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !host.isEmpty, host.contains(".") else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func matchingDomain(for url: URL, domains: [String]) -> String? {
        guard let rawHost = url.host?.lowercased() else { return nil }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        return domains.first { domain in
            guard let normalized = normalizedDomain(domain) else { return false }
            return host == normalized || host.hasSuffix("." + normalized)
        }
    }
}
