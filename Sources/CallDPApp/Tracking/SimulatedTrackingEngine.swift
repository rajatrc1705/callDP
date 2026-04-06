import CallDPCore
import Foundation

@MainActor
final class SimulatedTrackingEngine: TrackingEngine {
    private let simulation: SimulationController
    private var trackedTargetID: UUID?

    init(simulation: SimulationController) {
        self.simulation = simulation
    }

    func beginTracking(target: DetectionCandidate, in frame: CameraFrame) async {
        _ = frame
        trackedTargetID = target.id
    }

    func update(with frame: CameraFrame) async -> TrackingObservation? {
        simulation.currentObservation(for: trackedTargetID, timestamp: frame.timestamp)
    }

    func stopTracking() async {
        trackedTargetID = nil
    }
}
