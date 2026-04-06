import Foundation

struct TranscriptSegment: Sendable {
    let text: String
    let isFinal: Bool
    let timestamp: TimeInterval
}

@MainActor
protocol AudioTranscribing: AnyObject {
    var onTranscript: ((TranscriptSegment) -> Void)? { get set }
    func start() async throws
    func stop() async
}

@MainActor
final class StubAudioTranscriber: AudioTranscribing {
    var onTranscript: ((TranscriptSegment) -> Void)?

    func start() async throws {}

    func stop() async {}

    func inject(text: String) {
        let segment = TranscriptSegment(
            text: text,
            isFinal: true,
            timestamp: Date().timeIntervalSince1970
        )
        onTranscript?(segment)
    }
}
