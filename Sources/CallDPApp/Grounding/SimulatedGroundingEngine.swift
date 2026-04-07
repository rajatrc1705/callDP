#if SWIFT_PACKAGE
import CallDPCore
#endif
import Foundation

@MainActor
final class SimulatedGroundingEngine: GroundingEngine {
    private let simulation: SimulationController

    init(simulation: SimulationController) {
        self.simulation = simulation
    }

    func detect(in frame: CameraFrame, request: GroundingRequest) async throws -> [DetectionCandidate] {
        let queries = request.candidateQueries.isEmpty ? [request.targetDescription] : request.candidateQueries
        return simulation.currentDetections(matching: queries, timestamp: frame.timestamp)
    }
}
