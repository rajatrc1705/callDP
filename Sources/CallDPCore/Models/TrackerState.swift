import Foundation

public enum TrackingMode: String, Codable, Sendable, CaseIterable {
    case idle
    case detecting
    case tracking
    case lostTarget = "lost_target"
    case reacquiring
}

public struct TrackerState: Sendable, Codable, Hashable {
    public var mode: TrackingMode
    public var targetID: UUID?
    public var bbox: NormalizedRect?
    public var confidence: Double
    public var velocity: Vector2D
    public var lastSeenTimestamp: TimeInterval
    public var activeDescription: String?
    public var candidateQueries: [String]
    public var frameAnchor: FrameAnchor
    public var zoomMode: ZoomMode

    public init(
        mode: TrackingMode = .idle,
        targetID: UUID? = nil,
        bbox: NormalizedRect? = nil,
        confidence: Double = 0,
        velocity: Vector2D = .zero,
        lastSeenTimestamp: TimeInterval = 0,
        activeDescription: String? = nil,
        candidateQueries: [String] = [],
        frameAnchor: FrameAnchor = .center,
        zoomMode: ZoomMode = .automatic
    ) {
        self.mode = mode
        self.targetID = targetID
        self.bbox = bbox
        self.confidence = confidence
        self.velocity = velocity
        self.lastSeenTimestamp = lastSeenTimestamp
        self.activeDescription = activeDescription
        self.candidateQueries = candidateQueries
        self.frameAnchor = frameAnchor
        self.zoomMode = zoomMode
    }
}
