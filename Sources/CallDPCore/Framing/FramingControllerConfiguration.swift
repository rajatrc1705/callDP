import Foundation

public struct FramingControllerConfiguration: Sendable, Codable, Hashable {
    public var deadZoneSize: Vector2D
    public var maxVelocity: Double
    public var maxAcceleration: Double
    public var dampingFactor: Double
    public var leadTime: Double
    public var minCropSize: Double
    public var maxCropSize: Double
    public var preferredTargetFill: Double
    public var fastMotionZoomOutBoost: Double
    public var edgePadding: Double
    public var manualPanStep: Double
    public var manualZoomStep: Double
    public var sizeLerpRate: Double

    public init(
        deadZoneSize: Vector2D = Vector2D(x: 0.08, y: 0.08),
        maxVelocity: Double = 0.9,
        maxAcceleration: Double = 3.25,
        dampingFactor: Double = 0.82,
        leadTime: Double = 0.18,
        minCropSize: Double = 0.3,
        maxCropSize: Double = 1,
        preferredTargetFill: Double = 0.34,
        fastMotionZoomOutBoost: Double = 0.2,
        edgePadding: Double = 0.05,
        manualPanStep: Double = 0.08,
        manualZoomStep: Double = 0.1,
        sizeLerpRate: Double = 2.5
    ) {
        self.deadZoneSize = deadZoneSize
        self.maxVelocity = maxVelocity
        self.maxAcceleration = maxAcceleration
        self.dampingFactor = dampingFactor
        self.leadTime = leadTime
        self.minCropSize = minCropSize
        self.maxCropSize = maxCropSize
        self.preferredTargetFill = preferredTargetFill
        self.fastMotionZoomOutBoost = fastMotionZoomOutBoost
        self.edgePadding = edgePadding
        self.manualPanStep = manualPanStep
        self.manualZoomStep = manualZoomStep
        self.sizeLerpRate = sizeLerpRate
    }
}
