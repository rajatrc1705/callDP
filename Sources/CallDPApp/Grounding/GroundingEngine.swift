import CallDPCore
import Foundation

struct GroundingRequest: Sendable {
    let targetDescription: String
    let candidateQueries: [String]
}

@MainActor
protocol GroundingEngine {
    func detect(in frame: CameraFrame, request: GroundingRequest) async throws -> [DetectionCandidate]
}
