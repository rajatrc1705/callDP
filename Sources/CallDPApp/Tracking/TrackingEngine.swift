import CallDPCore
import Foundation

@MainActor
protocol TrackingEngine {
    func beginTracking(target: DetectionCandidate, in frame: CameraFrame) async
    func update(with frame: CameraFrame) async -> TrackingObservation?
    func stopTracking() async
}
