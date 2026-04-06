import Foundation

public struct DirectorTransition: Sendable, Codable, Hashable {
    public var from: TrackingMode
    public var to: TrackingMode
    public var reason: String
    public var timestamp: TimeInterval

    public init(from: TrackingMode, to: TrackingMode, reason: String, timestamp: TimeInterval) {
        self.from = from
        self.to = to
        self.reason = reason
        self.timestamp = timestamp
    }
}

public struct DirectorSessionState: Sendable, Codable, Hashable {
    public var tracker: TrackerState
    public var crop: CropState
    public var lastCommand: DirectorCommand?
    public var candidateDetections: [DetectionCandidate]

    public init(
        tracker: TrackerState = TrackerState(),
        crop: CropState = .neutral(),
        lastCommand: DirectorCommand? = nil,
        candidateDetections: [DetectionCandidate] = []
    ) {
        self.tracker = tracker
        self.crop = crop
        self.lastCommand = lastCommand
        self.candidateDetections = candidateDetections
    }
}

public struct DirectorStateMachine: Sendable {
    public var detectionThreshold: Double
    public var trackingThreshold: Double
    public var lostTargetTimeout: TimeInterval

    public init(
        detectionThreshold: Double = 0.55,
        trackingThreshold: Double = 0.4,
        lostTargetTimeout: TimeInterval = 0.75
    ) {
        self.detectionThreshold = detectionThreshold
        self.trackingThreshold = trackingThreshold
        self.lostTargetTimeout = lostTargetTimeout
    }

    public mutating func apply(
        command: DirectorCommand,
        to state: inout DirectorSessionState,
        now: TimeInterval
    ) -> [DirectorTransition] {
        state.lastCommand = command
        state.tracker.frameAnchor = command.frameAnchor
        state.tracker.zoomMode = command.zoomMode

        switch command.intent {
        case .focusObject:
            state.tracker.activeDescription = command.targetDescription
            state.tracker.candidateQueries = command.candidateQueries.isEmpty
                ? [command.targetDescription].compactMap { $0 }
                : command.candidateQueries
            state.tracker.confidence = 0
            state.tracker.bbox = nil
            state.candidateDetections = []
            return transition(to: .detecting, reason: "focus_object", state: &state, now: now)

        case .stopTracking:
            let previousMode = state.tracker.mode
            state.tracker = TrackerState()
            state.tracker.mode = previousMode
            state.candidateDetections = []
            return transition(to: .idle, reason: "stop_tracking", state: &state, now: now)

        case .selectCandidate:
            guard
                let selectedIndex = command.selectedCandidateIndex,
                state.candidateDetections.indices.contains(selectedIndex)
            else {
                return []
            }

            let selected = state.candidateDetections[selectedIndex]
            state.tracker.targetID = selected.id
            state.tracker.bbox = selected.boundingBox
            state.tracker.confidence = selected.confidence
            state.tracker.velocity = .zero
            state.tracker.lastSeenTimestamp = now
            return transition(to: .tracking, reason: "candidate_selected", state: &state, now: now)

        case .lockCurrentTarget:
            guard state.tracker.bbox != nil else { return [] }
            return transition(to: .tracking, reason: "lock_current_target", state: &state, now: now)

        case .moveFrame, .zoom, .recenter:
            return []
        }
    }

    public mutating func applyDetections(
        _ detections: [DetectionCandidate],
        to state: inout DirectorSessionState,
        now: TimeInterval
    ) -> [DirectorTransition] {
        let ranked = rankDetections(detections)
        state.candidateDetections = ranked

        guard let best = ranked.first, best.confidence >= detectionThreshold else {
            return transition(to: .lostTarget, reason: "no_detection_confident_enough", state: &state, now: now)
        }

        state.tracker.targetID = best.id
        state.tracker.bbox = best.boundingBox
        state.tracker.confidence = best.confidence
        state.tracker.velocity = .zero
        state.tracker.lastSeenTimestamp = now
        return transition(to: .tracking, reason: "detection_locked", state: &state, now: now)
    }

    public mutating func applyTrackingObservation(
        _ observation: TrackingObservation?,
        to state: inout DirectorSessionState,
        now: TimeInterval
    ) -> [DirectorTransition] {
        guard let observation else {
            return handleTrackingLoss(for: &state, now: now)
        }

        guard observation.confidence >= trackingThreshold else {
            return handleTrackingLoss(for: &state, now: now)
        }

        state.tracker.bbox = observation.boundingBox
        state.tracker.confidence = observation.confidence
        state.tracker.velocity = observation.velocity
        state.tracker.lastSeenTimestamp = now
        return transition(to: .tracking, reason: "tracking_update", state: &state, now: now)
    }

    private func handleTrackingLoss(
        for state: inout DirectorSessionState,
        now: TimeInterval
    ) -> [DirectorTransition] {
        let elapsed = now - state.tracker.lastSeenTimestamp
        let nextMode: TrackingMode = elapsed >= lostTargetTimeout ? .lostTarget : .reacquiring
        return transition(to: nextMode, reason: "tracking_confidence_low", state: &state, now: now)
    }

    private func transition(
        to newMode: TrackingMode,
        reason: String,
        state: inout DirectorSessionState,
        now: TimeInterval
    ) -> [DirectorTransition] {
        let previous = state.tracker.mode
        state.tracker.mode = newMode
        guard previous != newMode else { return [] }
        return [DirectorTransition(from: previous, to: newMode, reason: reason, timestamp: now)]
    }

    private func rankDetections(_ detections: [DetectionCandidate]) -> [DetectionCandidate] {
        detections.sorted { lhs, rhs in
            let lhsScore = lhs.confidence - distanceToCenter(lhs.boundingBox.center)
            let rhsScore = rhs.confidence - distanceToCenter(rhs.boundingBox.center)
            return lhsScore > rhsScore
        }
    }

    private func distanceToCenter(_ point: Vector2D) -> Double {
        let dx = point.x - 0.5
        let dy = point.y - 0.5
        return sqrt((dx * dx) + (dy * dy)) * 0.35
    }
}
