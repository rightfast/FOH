import XCTest
@testable import FOH

@MainActor
final class MicrophoneMonitorTests: XCTestCase {
    func testSilenceProducesZeroLevel() {
        XCTAssertEqual(MicrophoneMonitor.normalizedLevel(samples: [0, 0, 0]), 0)
        XCTAssertEqual(MicrophoneMonitor.normalizedLevel(samples: []), 0)
    }

    func testFullScaleSignalProducesMaximumLevel() {
        XCTAssertEqual(MicrophoneMonitor.normalizedLevel(samples: [1, -1, 1, -1]), 1)
    }

    func testModerateSignalProducesIntermediateLevel() {
        let level = MicrophoneMonitor.normalizedLevel(samples: [0.01, -0.01, 0.01, -0.01])

        XCTAssertGreaterThan(level, 0)
        XCTAssertLessThan(level, 1)
        XCTAssertEqual(level, 1.0 / 3.0, accuracy: 0.001)
    }

    func testBackgroundPermissionReplyReturnsToMainActor() async throws {
        let suiteName = "MicrophoneMonitorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let monitor = MicrophoneMonitor(
            defaults: defaults,
            initialAuthorization: .notDetermined,
            permissionRequester: { completion in
                DispatchQueue.global().async {
                    completion(true)
                }
            }
        )

        monitor.enable()
        for _ in 0..<20 where !monitor.isEnabled {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(monitor.authorization, .authorized)
        XCTAssertTrue(monitor.isEnabled)
        XCTAssertFalse(monitor.isMonitoring)
    }
}
