import Testing
@testable import CallDPCore

struct DirectorStateMachineTests {
    @Test
    func focusCommandTransitionsIntoDetecting() {
        var machine = DirectorStateMachine()
        var state = DirectorSessionState()

        let transitions = machine.apply(
            command: .focus(on: "cooking vessel", candidateQueries: ["pot", "pan"]),
            to: &state,
            now: 1
        )

        #expect(state.tracker.mode == .detecting)
        #expect(state.tracker.activeDescription == "cooking vessel")
        #expect(transitions.first?.to == .detecting)
    }

    @Test
    func confidentDetectionLocksTracking() {
        var machine = DirectorStateMachine()
        var state = DirectorSessionState()

        _ = machine.apply(
            command: .focus(on: "bowl", candidateQueries: ["bowl"]),
            to: &state,
            now: 1
        )

        let detections = [
            DetectionCandidate(
                query: "bowl",
                boundingBox: NormalizedRect(x: 0.45, y: 0.35, width: 0.2, height: 0.2),
                confidence: 0.92,
                label: "bowl",
                timestamp: 2
            ),
        ]

        let transitions = machine.applyDetections(detections, to: &state, now: 2)

        #expect(state.tracker.mode == .tracking)
        #expect(state.tracker.bbox == detections[0].boundingBox)
        #expect(transitions.first?.to == .tracking)
    }

    @Test
    func stopTrackingReturnsToIdle() {
        var machine = DirectorStateMachine()
        var state = DirectorSessionState(
            tracker: TrackerState(mode: .tracking, bbox: NormalizedRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2))
        )

        let transitions = machine.apply(
            command: DirectorCommand(intent: .stopTracking),
            to: &state,
            now: 4
        )

        #expect(state.tracker.mode == .idle)
        #expect(state.tracker.bbox == nil)
        #expect(transitions.first?.to == .idle)
    }
}
