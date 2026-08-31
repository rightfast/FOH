import Foundation

struct CoreAudioError: LocalizedError, Equatable {
    let operation: String
    let status: OSStatus

    var errorDescription: String? {
        "\(operation) failed (Core Audio status \(status))."
    }
}

