import Foundation
import ImageIO
#if SWIFT_PACKAGE
import CallDPCore
#endif
import Vision

#if SWIFT_PACKAGE
private typealias CoreNormalizedRect = CallDPCore.NormalizedRect
private typealias CoreVector2D = CallDPCore.Vector2D
#else
private typealias CoreNormalizedRect = NormalizedRect
private typealias CoreVector2D = Vector2D
#endif

@MainActor
final class VisionTrackingEngine: TrackingEngine {
    private var sequenceHandler = VNSequenceRequestHandler()
    private var trackingRequest: VNTrackObjectRequest?
    private var previousCenter: CoreVector2D?
    private var previousTimestamp: TimeInterval?

    func beginTracking(target: DetectionCandidate, in frame: CameraFrame) async {
        let observation = VNDetectedObjectObservation(boundingBox: makeVisionBoundingBox(from: target.boundingBox))
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = VNRequestTrackingLevel.accurate

        trackingRequest = request
        sequenceHandler = VNSequenceRequestHandler()
        previousCenter = target.boundingBox.center
        previousTimestamp = frame.timestamp
    }

    func update(with frame: CameraFrame) async -> TrackingObservation? {
        guard let trackingRequest else { return nil }

        do {
            try sequenceHandler.perform([trackingRequest], on: frame.image, orientation: .up)
        } catch {
            return nil
        }

        guard let observation = trackingRequest.results?.first as? VNDetectedObjectObservation else {
            return nil
        }

        trackingRequest.inputObservation = observation

        let normalizedBox = makeNormalizedRect(from: observation.boundingBox)
        let currentCenter = normalizedBox.center
        let velocity = resolvedVelocity(currentCenter: currentCenter, timestamp: frame.timestamp)

        previousCenter = currentCenter
        previousTimestamp = frame.timestamp

        return TrackingObservation(
            boundingBox: normalizedBox,
            confidence: Double(observation.confidence),
            velocity: velocity,
            timestamp: frame.timestamp
        )
    }

    func stopTracking() async {
        trackingRequest?.isLastFrame = true
        trackingRequest = nil
        sequenceHandler = VNSequenceRequestHandler()
        previousCenter = nil
        previousTimestamp = nil
    }

    private func resolvedVelocity(currentCenter: CoreVector2D, timestamp: TimeInterval) -> CoreVector2D {
        guard
            let previousCenter,
            let previousTimestamp
        else {
            return .zero
        }

        let dt = max(0.001, timestamp - previousTimestamp)
        return CoreVector2D(
            x: (currentCenter.x - previousCenter.x) / dt,
            y: (currentCenter.y - previousCenter.y) / dt
        )
    }
}

private func makeNormalizedRect(from visionBoundingBox: CGRect) -> CoreNormalizedRect {
    CoreNormalizedRect(
        x: visionBoundingBox.minX,
        y: 1 - visionBoundingBox.maxY,
        width: visionBoundingBox.width,
        height: visionBoundingBox.height
    )
}

private func makeVisionBoundingBox(from normalizedRect: CoreNormalizedRect) -> CGRect {
    CGRect(
        x: normalizedRect.x,
        y: 1 - normalizedRect.y - normalizedRect.height,
        width: normalizedRect.width,
        height: normalizedRect.height
    )
}
