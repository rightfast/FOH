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

    func testMeterAttacksFasterThanItReleases() {
        let attack = MicrophoneMonitor.smoothedLevel(previous: 0.1, target: 0.9)
        let release = MicrophoneMonitor.smoothedLevel(previous: 0.9, target: 0.1)

        XCTAssertGreaterThan(attack - 0.1, 0.9 - release)
        XCTAssertGreaterThan(attack, 0.1)
        XCTAssertLessThan(release, 0.9)
    }

    func testMeterSmoothingMovesTowardTargetWithoutOvershooting() {
        let rising = MicrophoneMonitor.smoothedLevel(previous: 0.2, target: 0.8)
        let falling = MicrophoneMonitor.smoothedLevel(previous: 0.8, target: 0.2)

        XCTAssertGreaterThan(rising, 0.2)
        XCTAssertLessThan(rising, 0.8)
        XCTAssertGreaterThan(falling, 0.2)
        XCTAssertLessThan(falling, 0.8)
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
