import Foundation

/// A top-left-origin rectangle in normalized unit coordinates.
public struct NormalizedRect: Sendable, Codable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let unit = NormalizedRect(x: 0, y: 0, width: 1, height: 1)

    public var center: Vector2D {
        Vector2D(x: x + (width / 2), y: y + (height / 2))
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }

    public func clampedToUnitSpace() -> NormalizedRect {
        let clampedWidth = width.clamped(to: 0.001 ... 1)
        let clampedHeight = height.clamped(to: 0.001 ... 1)
        let clampedX = x.clamped(to: 0 ... max(0, 1 - clampedWidth))
        let clampedY = y.clamped(to: 0 ... max(0, 1 - clampedHeight))
        return NormalizedRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }

    public static func centered(at center: Vector2D, size: Vector2D) -> NormalizedRect {
        NormalizedRect(
            x: center.x - (size.x / 2),
            y: center.y - (size.y / 2),
            width: size.x,
            height: size.y
        )
    }
}
