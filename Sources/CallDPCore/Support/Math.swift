import CoreGraphics
import Foundation

public struct Vector2D: Sendable, Codable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2D(x: 0, y: 0)

    public var magnitude: Double {
        sqrt((x * x) + (y * y))
    }

    public func limited(to maxMagnitude: Double) -> Vector2D {
        guard magnitude > maxMagnitude, magnitude > 0 else {
            return self
        }

        let scale = maxMagnitude / magnitude
        return self * scale
    }
}

public extension Vector2D {
    static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: Vector2D, rhs: Double) -> Vector2D {
        Vector2D(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

public extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

public extension CGSize {
    var aspectRatio: Double {
        guard height > 0 else { return 1 }
        return width / height
    }
}
