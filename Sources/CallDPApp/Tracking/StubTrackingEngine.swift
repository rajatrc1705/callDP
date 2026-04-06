import CallDPCore
import Foundation

@MainActor
final class StubTrackingEngine: TrackingEngine {
    private var currentTarget: DetectionCandidate?

    func beginTracking(target: DetectionCandidate, in frame: CameraFrame) async {
        _ = frame
        currentTarget = target
    }

    func update(with frame: CameraFrame) async -> TrackingObservation? {
        guard let currentTarget else { return nil }

        return TrackingObservation(
            boundingBox: currentTarget.boundingBox,
            confidence: max(0.65, currentTarget.confidence - 0.1),
            velocity: .zero,
            timestamp: frame.timestamp
        )
    }

    func stopTracking() async {
        currentTarget = nil
    }
}
