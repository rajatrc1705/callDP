import Foundation

struct TranscriptSegment: Sendable {
    let text: String
    let isFinal: Bool
    let timestamp: TimeInterval
}

enum AudioInputState: Sendable, Equatable {
    case manualOnly
    case starting
    case listening
    case stopped
    case error(String)

    var title: String {
        switch self {
        case .manualOnly:
            return "Manual only"
        case .starting:
            return "Starting"
        case .listening:
            return "Listening"
        case .stopped:
            return "Stopped"
        case .error:
            return "Error"
        }
    }

    var detail: String {
        switch self {
        case .manualOnly:
            return "Live speech is not active in this backend mode. Use injected transcripts instead."
        case .starting:
            return "Preparing microphone and speech recognition."
        case .listening:
            return "Microphone is active. Final utterances will be parsed into camera commands."
        case .stopped:
            return "Speech capture is currently off."
        case let .error(message):
            return message
        }
    }

    var isListening: Bool {
        if case .listening = self {
            return true
        }
        return false
    }
}

protocol AudioTranscribing: AnyObject, Sendable {
    var onTranscript: ((TranscriptSegment) -> Void)? { get set }
    var onStateChange: ((AudioInputState) -> Void)? { get set }
    func start() async throws
    func stop() async
}

final class StubAudioTranscriber: AudioTranscribing, @unchecked Sendable {
    var onTranscript: ((TranscriptSegment) -> Void)?
    var onStateChange: ((AudioInputState) -> Void)?

    func start() async throws {
        onStateChange?(.manualOnly)
    }

    func stop() async {
        onStateChange?(.stopped)
    }

    func inject(text: String) {
        let segment = TranscriptSegment(
            text: text,
            isFinal: true,
            timestamp: Date().timeIntervalSince1970
        )
        onTranscript?(segment)
    }
}
