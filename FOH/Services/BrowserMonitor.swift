import AppKit
import Foundation
import OSLog

struct BrowserPageSnapshot: Equatable, Sendable {
    let browserBundleIdentifier: String?
    let url: URL?
    let permissionDenied: Bool

    static let inactive = BrowserPageSnapshot(browserBundleIdentifier: nil, url: nil, permissionDenied: false)
}

@MainActor
protocol BrowserMonitoring: AnyObject {
    var onChange: ((BrowserPageSnapshot) -> Void)? { get set }
    func startObserving()
    func stopObserving()
    func checkNow()
}

@MainActor
final class BrowserMonitor: BrowserMonitoring {
    var onChange: ((BrowserPageSnapshot) -> Void)?

    private let workspace: NSWorkspace
    private let logger = Logger(subsystem: "studio.rightfast.foh", category: "BrowserMonitor")
    private var timer: Timer?
    private var lastSnapshot = BrowserPageSnapshot.inactive

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func startObserving() {
        guard timer == nil else { return }
        logger.debug("Browser monitoring started")
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkNow() }
        }
        checkNow()
    }

    func stopObserving() {
        timer?.invalidate()
        timer = nil
        logger.debug("Browser monitoring stopped")
        publish(.inactive)
    }

    func checkNow() {
        let bundleIdentifier = workspace.frontmostApplication?.bundleIdentifier
        logger.debug("Frontmost application: \(bundleIdentifier ?? "none", privacy: .public)")
        guard let bundleIdentifier,
              let browser = SupportedBrowser.all.first(where: { $0.id == bundleIdentifier }) else {
            publish(.inactive)
            return
        }

        var error: NSDictionary?
        let result = NSAppleScript(source: script(for: browser))?.executeAndReturnError(&error)
        let errorNumber = error?[NSAppleScript.errorNumber] as? Int
        if let errorNumber {
            logger.error("Browser AppleScript failed with code \(errorNumber, privacy: .public)")
        }
        let url = result?.stringValue.flatMap(URL.init(string:))
        publish(BrowserPageSnapshot(
            browserBundleIdentifier: bundleIdentifier,
            url: url,
            permissionDenied: errorNumber == -1743
        ))
    }

    private func publish(_ snapshot: BrowserPageSnapshot) {
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        onChange?(snapshot)
    }

    private func script(for browser: SupportedBrowser) -> String {
        switch browser.kind {
        case .safari:
            return """
            tell application id "com.apple.Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        case .chromium:
            return """
            tell application id "com.google.Chrome"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        }
    }
}
