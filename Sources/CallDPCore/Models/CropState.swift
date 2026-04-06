import Foundation

public struct CropState: Sendable, Codable, Hashable {
    public var center: Vector2D
    public var size: Vector2D
    public var zoom: Double
    public var velocity: Vector2D
    public var timestamp: TimeInterval

    public init(
        center: Vector2D = Vector2D(x: 0.5, y: 0.5),
        size: Vector2D = Vector2D(x: 1, y: 1),
        zoom: Double = 1,
        velocity: Vector2D = .zero,
        timestamp: TimeInterval = 0
    ) {
        self.center = center
        self.size = size
        self.zoom = zoom
        self.velocity = velocity
        self.timestamp = timestamp
    }

    public var rect: NormalizedRect {
        NormalizedRect.centered(at: center, size: size).clampedToUnitSpace()
    }

    public static func neutral(timestamp: TimeInterval = 0) -> CropState {
        CropState(timestamp: timestamp)
    }
}
