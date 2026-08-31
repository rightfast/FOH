@preconcurrency import AVFoundation
import Foundation

@MainActor
final class OutputTonePlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isAttached = false
    private var stopTask: Task<Void, Never>?

    func play() {
        stop()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let frameCount = AVAudioFrameCount(48_000 * 0.7)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        for channel in 0..<Int(format.channelCount) {
            guard let samples = buffer.floatChannelData?[channel] else { continue }
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / format.sampleRate
                let envelope = min(1, time / 0.04) * min(1, (0.7 - time) / 0.08)
                samples[frame] = Float(sin(2 * .pi * 523.25 * time) * 0.16 * max(0, envelope))
            }
        }

        if !isAttached {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isAttached = true
        }

        do {
            engine.prepare()
            try engine.start()
            player.scheduleBuffer(buffer)
            player.play()
            isPlaying = true
            errorMessage = nil
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        player.stop()
        engine.stop()
        isPlaying = false
    }
}
