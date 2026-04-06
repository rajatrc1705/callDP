import Foundation

public struct DetectionCandidate: Identifiable, Sendable, Codable, Hashable {
    public var id: UUID
    public var query: String
    public var boundingBox: NormalizedRect
    public var confidence: Double
    public var label: String
    public var timestamp: TimeInterval

    public init(
        id: UUID = UUID(),
        query: String,
        boundingBox: NormalizedRect,
        confidence: Double,
        label: String,
        timestamp: TimeInterval
    ) {
        self.id = id
        self.query = query
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.label = label
        self.timestamp = timestamp
    }
}

public struct TrackingObservation: Sendable, Codable, Hashable {
    public var boundingBox: NormalizedRect
    public var confidence: Double
    public var velocity: Vector2D
    public var timestamp: TimeInterval

    public init(
        boundingBox: NormalizedRect,
        confidence: Double,
        velocity: Vector2D,
        timestamp: TimeInterval
    ) {
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.velocity = velocity
        self.timestamp = timestamp
    }
}
