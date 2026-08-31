import XCTest
@testable import FOH

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
}
