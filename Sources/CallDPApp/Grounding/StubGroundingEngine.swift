import CallDPCore
import Foundation

@MainActor
final class StubGroundingEngine: GroundingEngine {
    func detect(in frame: CameraFrame, request: GroundingRequest) async throws -> [DetectionCandidate] {
        _ = frame
        _ = request
        return []
    }
}
