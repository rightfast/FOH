@preconcurrency import AVFoundation
import Foundation

private final class WeakMicrophoneMonitorBox: @unchecked Sendable {
    weak var value: MicrophoneMonitor?

    init(_ value: MicrophoneMonitor) {
        self.value = value
    }
}

@MainActor
final class MicrophoneMonitor: ObservableObject, @unchecked Sendable {
    enum Authorization: Equatable {
        case notDetermined
        case denied
        case authorized
    }

    @Published private(set) var samples: [Double] = Array(repeating: 0.04, count: 28)
    @Published private(set) var isMonitoring = false
    @Published private(set) var authorization: Authorization
    @Published private(set) var errorMessage: String?
    @Published private(set) var isEnabled: Bool

    private let engine = AVAudioEngine()
    private let defaults: UserDefaults
    private var visibleConsumerCount = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: "inputActivityEnabled")
        authorization = Self.currentAuthorization
    }

    func enable() {
        switch authorization {
        case .authorized:
            setEnabled(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.authorization = granted ? .authorized : .denied
                    if granted { self.setEnabled(true) }
                }
            }
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

    func restartForInputDeviceChange() {
        guard isMonitoring else { return }
        stop()
        if visibleConsumerCount > 0 { start() }
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
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = error.localizedDescription
            isMonitoring = false
        }
    }

    func stop() {
        guard isMonitoring else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isMonitoring = false
        samples = Array(repeating: 0.04, count: samples.count)
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
            Task { @MainActor in monitorBox.value?.append(level) }
        }
    }

    private static var currentAuthorization: Authorization {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
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

    private func append(_ level: Double) {
        samples.removeFirst()
        samples.append(max(0.04, level))
    }
}
