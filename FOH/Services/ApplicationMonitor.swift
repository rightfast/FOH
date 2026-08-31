import AppKit
import Foundation

protocol ApplicationMonitoring: AnyObject, Sendable {
    var onLaunch: (@Sendable (String) -> Void)? { get set }
    var onTerminate: (@Sendable (String) -> Void)? { get set }
    func startObserving()
    func isRunning(bundleIdentifier: String) -> Bool
    func applicationURL(bundleIdentifier: String) -> URL?
}

final class ApplicationMonitor: ApplicationMonitoring, @unchecked Sendable {
    var onLaunch: (@Sendable (String) -> Void)?
    var onTerminate: (@Sendable (String) -> Void)?

    private let workspace: NSWorkspace
    private var observers: [NSObjectProtocol] = []

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func startObserving() {
        guard observers.isEmpty else { return }
        let center = workspace.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let identifier = Self.bundleIdentifier(from: notification) else { return }
            self?.onLaunch?(identifier)
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let identifier = Self.bundleIdentifier(from: notification) else { return }
            self?.onTerminate?(identifier)
        })
    }

    func isRunning(bundleIdentifier: String) -> Bool {
        workspace.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func applicationURL(bundleIdentifier: String) -> URL? {
        workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    deinit {
        let center = workspace.notificationCenter
        observers.forEach(center.removeObserver)
    }

    private static func bundleIdentifier(from notification: Notification) -> String? {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return application?.bundleIdentifier
    }
}
