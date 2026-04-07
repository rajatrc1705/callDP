#if SWIFT_PACKAGE
import CallDPCore
#endif
import Combine
import Foundation

@MainActor
final class SimulationController: ObservableObject {
    @Published var targetDescription = "cooking vessel"
    @Published var primaryLabel = "pot"
    @Published var query = "pot"
    @Published var centerX = 0.52
    @Published var centerY = 0.48
    @Published var boxWidth = 0.22
    @Published var boxHeight = 0.22
    @Published var confidence = 0.92
    @Published var animateMotion = true
    @Published var horizontalAmplitude = 0.14
    @Published var verticalAmplitude = 0.06
    @Published var motionPeriod = 7.0

    let targetID = UUID()

    func currentDetections(matching queries: [String], timestamp: TimeInterval) -> [DetectionCandidate] {
        guard queryMatches(queries) else {
            return []
        }

        return [
            DetectionCandidate(
                id: targetID,
                query: query,
                boundingBox: currentBoundingBox(at: timestamp),
                confidence: confidence,
                label: primaryLabel,
                timestamp: timestamp
            ),
        ]
    }

    func currentObservation(for targetID: UUID?, timestamp: TimeInterval) -> TrackingObservation? {
        guard targetID == nil || targetID == self.targetID else {
            return nil
        }

        return TrackingObservation(
            boundingBox: currentBoundingBox(at: timestamp),
            confidence: confidence,
            velocity: currentVelocity(at: timestamp),
            timestamp: timestamp
        )
    }

    private func queryMatches(_ queries: [String]) -> Bool {
        guard queries.isEmpty == false else { return true }
        let haystack = [targetDescription, primaryLabel, query].joined(separator: " ").lowercased()
        return queries.contains { haystack.contains($0.lowercased()) || $0.lowercased().contains(primaryLabel.lowercased()) }
    }

    private func currentBoundingBox(at timestamp: TimeInterval) -> NormalizedRect {
        let center = currentCenter(at: timestamp)
        return NormalizedRect(
            x: center.x - (boxWidth / 2),
            y: center.y - (boxHeight / 2),
            width: boxWidth,
            height: boxHeight
        ).clampedToUnitSpace()
    }

    private func currentCenter(at timestamp: TimeInterval) -> Vector2D {
        guard animateMotion, motionPeriod > 0 else {
            return Vector2D(x: centerX, y: centerY)
        }

        let omega = (2 * Double.pi) / motionPeriod
        return Vector2D(
            x: centerX + (horizontalAmplitude * sin(omega * timestamp)),
            y: centerY + (verticalAmplitude * cos(omega * timestamp))
        )
    }

    private func currentVelocity(at timestamp: TimeInterval) -> Vector2D {
        guard animateMotion, motionPeriod > 0 else {
            return .zero
        }

        let omega = (2 * Double.pi) / motionPeriod
        return Vector2D(
            x: horizontalAmplitude * omega * cos(omega * timestamp),
            y: -verticalAmplitude * omega * sin(omega * timestamp)
        )
    }
}
