@preconcurrency import AVFoundation
import Foundation

typealias MicrophonePermissionRequester = @Sendable (@escaping @Sendable (Bool) -> Void) -> Void

private final class WeakMicrophoneMonitorBox: @unchecked Sendable {
    weak var value: MicrophoneMonitor?

    init(_ value: MicrophoneMonitor) {
        self.value = value
    }
}

/// Coalesces the much faster audio callback cadence into one peak per display frame.
private final class MicrophoneLevelAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var peak = 0.0

    func push(_ level: Double) {
        lock.lock()
        peak = max(peak, level)
        lock.unlock()
    }

    func consumePeak() -> Double {
        lock.lock()
        defer { lock.unlock() }
        let value = peak
        peak = 0
        return value
    }
}

@MainActor
final class MicrophoneMonitor: ObservableObject, @unchecked Sendable {
    private static let sampleFloor = 0.04
    private static let sampleCount = 28
    private static let displayFrameDuration = Duration.milliseconds(16)
    private nonisolated static let attack = 0.58
    private nonisolated static let release = 0.14

    enum Authorization: Equatable {
        case notDetermined
        case denied
        case authorized
    }

    @Published private(set) var samples: [Double] = Array(repeating: sampleFloor, count: sampleCount)
    @Published private(set) var isMonitoring = false
    @Published private(set) var authorization: Authorization
    @Published private(set) var errorMessage: String?
    @Published private(set) var isEnabled: Bool

    private let engine = AVAudioEngine()
    private let defaults: UserDefaults
    private let permissionRequester: MicrophonePermissionRequester
    private let levelAccumulator = MicrophoneLevelAccumulator()
    private var visibleConsumerCount = 0
    private var displayTask: Task<Void, Never>?
    private var displayedLevel = sampleFloor

    init(
        defaults: UserDefaults = .standard,
        initialAuthorization: Authorization? = nil,
        permissionRequester: @escaping MicrophonePermissionRequester = MicrophoneMonitor.requestSystemPermission
    ) {
        self.defaults = defaults
        self.permissionRequester = permissionRequester
        isEnabled = defaults.bool(forKey: "inputActivityEnabled")
        authorization = initialAuthorization ?? Self.currentAuthorization
    }

    func enable() {
        switch authorization {
        case .authorized:
            setEnabled(true)
        case .notDetermined:
            Self.requestPermission(using: permissionRequester, for: self)
        case .denied:
            break
        }
    }

    func disable() {
        setEnabled(false)
    }

    func beginVisiblePresentation() {
        visibleConsumerCount += 1
        if isEnabled && authorization == .authorized { start() }
    }

    func endVisiblePresentation() {
        visibleConsumerCount = max(0, visibleConsumerCount - 1)
        if visibleConsumerCount == 0 { stop() }
    }

    func start() {
        guard !isMonitoring,
              isEnabled,
              authorization == .authorized,
              visibleConsumerCount > 0 else { return }

        let inputNode = engine.inputNode
        inputNode.installTap(
            onBus: 0,
            bufferSize: 512,
            format: nil,
            block: Self.makeTap(for: self)
        )

        do {
            engine.prepare()
            try engine.start()
            isMonitoring = true
            errorMessage = nil
            startDisplayLoop()
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = error.localizedDescription
            isMonitoring = false
        }
    }

    func stop() {
        guard isMonitoring else { return }
        displayTask?.cancel()
        displayTask = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isMonitoring = false
        displayedLevel = Self.sampleFloor
        samples = Array(repeating: Self.sampleFloor, count: Self.sampleCount)
    }

    nonisolated static func normalizedLevel(samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0.0) { partial, sample in
            partial + Double(sample * sample)
        }
        let rms = sqrt(sum / Double(samples.count))
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        return min(1, max(0, (decibels + 60) / 60))
    }

    private nonisolated static func normalizedLevel(buffer: AVAudioPCMBuffer) -> Double {
        guard let channels = buffer.floatChannelData,
              buffer.frameLength > 0 else { return 0 }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        var sum = 0.0
        var sampleCount = 0
        for channel in 0..<channelCount {
            let values = UnsafeBufferPointer(start: channels[channel], count: frameCount)
            for value in values {
                sum += Double(value * value)
                sampleCount += 1
            }
        }
        guard sampleCount > 0, sum > 0 else { return 0 }
        let decibels = 20 * log10(sqrt(sum / Double(sampleCount)))
        return min(1, max(0, (decibels + 60) / 60))
    }

    private nonisolated static func makeTap(for monitor: MicrophoneMonitor) -> AVAudioNodeTapBlock {
        let monitorBox = WeakMicrophoneMonitorBox(monitor)
        return { buffer, _ in
            let level = normalizedLevel(buffer: buffer)
            monitorBox.value?.levelAccumulator.push(level)
        }
    }

    nonisolated static func smoothedLevel(previous: Double, target: Double) -> Double {
        let coefficient = target > previous ? attack : release
        return previous + (target - previous) * coefficient
    }

    private static var currentAuthorization: Authorization {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    /// TCC invokes its reply on a background queue. Constructing this callback
    /// outside MainActor isolation prevents Swift 6 from trapping before the
    /// callback can explicitly hop back to the main actor.
    private nonisolated static func requestPermission(
        using requester: @escaping MicrophonePermissionRequester,
        for monitor: MicrophoneMonitor
    ) {
        let monitorBox = WeakMicrophoneMonitorBox(monitor)
        requester { granted in
            Task { @MainActor in
                guard let monitor = monitorBox.value else { return }
                monitor.authorization = granted ? .authorized : .denied
                if granted { monitor.setEnabled(true) }
            }
        }
    }

    nonisolated static func requestSystemPermission(
        _ completion: @escaping @Sendable (Bool) -> Void
    ) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }

    private func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: "inputActivityEnabled")
        if enabled {
            start()
        } else {
            stop()
        }
    }

    private func startDisplayLoop() {
        displayTask?.cancel()
        displayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.displayFrameDuration)
                guard !Task.isCancelled, let self else { return }
                let target = self.levelAccumulator.consumePeak()
                self.displayedLevel = Self.smoothedLevel(previous: self.displayedLevel, target: target)
                self.append(self.displayedLevel)
            }
        }
    }

    private func append(_ level: Double) {
        samples.removeFirst()
        samples.append(max(Self.sampleFloor, level))
    }
}
