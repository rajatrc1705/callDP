import Foundation

public struct FramingController: Sendable {
    public var configuration: FramingControllerConfiguration

    public init(configuration: FramingControllerConfiguration = FramingControllerConfiguration()) {
        self.configuration = configuration
    }

    public mutating func apply(
        command: DirectorCommand,
        to crop: inout CropState,
        now: TimeInterval
    ) {
        switch command.intent {
        case .moveFrame:
            guard let direction = command.direction else { return }
            let delta = configuration.manualPanStep * max(0.25, command.amount)
            switch direction {
            case .left:
                crop.center.x -= delta
            case .right:
                crop.center.x += delta
            case .up:
                crop.center.y -= delta
            case .down:
                crop.center.y += delta
            }

        case .zoom:
            let zoomStep = configuration.manualZoomStep * max(0.25, command.amount)
            switch command.zoomMode {
            case .stepIn:
                crop.size = scaledSize(from: crop.size, multiplier: 1 - zoomStep)
            case .stepOut:
                crop.size = scaledSize(from: crop.size, multiplier: 1 + zoomStep)
            case .absolute:
                if let zoomValue = command.zoomValue, zoomValue > 0 {
                    let normalizedSize = (1 / zoomValue).clamped(to: configuration.minCropSize ... configuration.maxCropSize)
                    crop.size = Vector2D(x: normalizedSize, y: normalizedSize)
                }
            case .automatic, .none:
                break
            }

        case .recenter:
            crop.center = Vector2D(x: 0.5, y: 0.5)
            crop.velocity = .zero

        case .focusObject, .stopTracking, .selectCandidate, .lockCurrentTarget:
            break
        }

        crop.size = clampedSize(crop.size)
        crop.center = clampedCenter(crop.center, cropSize: crop.size)
        crop.zoom = 1 / max(crop.size.x, crop.size.y)
        crop.timestamp = now
    }

    public func update(
        crop: CropState,
        tracker: TrackerState,
        now: TimeInterval
    ) -> CropState {
        let deltaTime = max(1.0 / 120.0, now - crop.timestamp)
        let desiredCenter: Vector2D
        let desiredSize: Vector2D

        if let bbox = tracker.bbox, tracker.mode == .tracking || tracker.mode == .reacquiring {
            let predictedTargetCenter = bbox.center + (tracker.velocity * configuration.leadTime)
            let targetSize = desiredSizeForTarget(bbox: bbox, velocity: tracker.velocity, zoomMode: tracker.zoomMode)
            let offset = anchorOffset(anchor: tracker.frameAnchor, cropSize: targetSize)
            desiredCenter = predictedTargetCenter + offset
            desiredSize = targetSize
        } else {
            desiredCenter = Vector2D(x: 0.5, y: 0.5)
            desiredSize = Vector2D(x: configuration.maxCropSize, y: configuration.maxCropSize)
        }

        let stabilizedCenter = isInsideDeadZone(target: desiredCenter, crop: crop)
            ? crop.center
            : desiredCenter

        let delta = stabilizedCenter - crop.center
        let desiredVelocity = delta.limited(to: configuration.maxVelocity)
        let velocityDelta = (desiredVelocity - crop.velocity).limited(to: configuration.maxAcceleration * deltaTime)
        var nextVelocity = crop.velocity + velocityDelta

        if tracker.mode == .idle || tracker.mode == .lostTarget || stabilizedCenter == crop.center {
            nextVelocity = nextVelocity * configuration.dampingFactor
        }

        let nextCenter = clampedCenter(crop.center + (nextVelocity * deltaTime), cropSize: crop.size)
        let sizeBlend = min(1, deltaTime * configuration.sizeLerpRate)
        let nextSize = clampedSize(
            Vector2D(
                x: crop.size.x + ((desiredSize.x - crop.size.x) * sizeBlend),
                y: crop.size.y + ((desiredSize.y - crop.size.y) * sizeBlend)
            )
        )

        return CropState(
            center: clampedCenter(nextCenter, cropSize: nextSize),
            size: nextSize,
            zoom: 1 / max(nextSize.x, nextSize.y),
            velocity: nextVelocity,
            timestamp: now
        )
    }

    private func desiredSizeForTarget(
        bbox: NormalizedRect,
        velocity: Vector2D,
        zoomMode: ZoomMode
    ) -> Vector2D {
        guard zoomMode == .automatic else {
            return Vector2D(x: configuration.maxCropSize, y: configuration.maxCropSize)
        }

        let targetSpan = max(bbox.width, bbox.height) + (configuration.edgePadding * 2)
        let motionBoost = min(velocity.magnitude * configuration.fastMotionZoomOutBoost, 0.25)
        let cropSize = (targetSpan / configuration.preferredTargetFill) + motionBoost
        let clamped = cropSize.clamped(to: configuration.minCropSize ... configuration.maxCropSize)
        return Vector2D(x: clamped, y: clamped)
    }

    private func anchorOffset(anchor: FrameAnchor, cropSize: Vector2D) -> Vector2D {
        switch anchor {
        case .center:
            return .zero
        case .leftThird:
            return Vector2D(x: cropSize.x * 0.17, y: 0)
        case .rightThird:
            return Vector2D(x: -cropSize.x * 0.17, y: 0)
        case .upperHalf:
            return Vector2D(x: 0, y: cropSize.y * 0.12)
        case .lowerHalf:
            return Vector2D(x: 0, y: -cropSize.y * 0.12)
        }
    }

    private func isInsideDeadZone(target: Vector2D, crop: CropState) -> Bool {
        let zoneWidth = crop.size.x * configuration.deadZoneSize.x
        let zoneHeight = crop.size.y * configuration.deadZoneSize.y
        let dx = abs(target.x - crop.center.x)
        let dy = abs(target.y - crop.center.y)
        return dx <= zoneWidth && dy <= zoneHeight
    }

    private func clampedCenter(_ center: Vector2D, cropSize: Vector2D) -> Vector2D {
        let halfWidth = cropSize.x / 2
        let halfHeight = cropSize.y / 2
        return Vector2D(
            x: center.x.clamped(to: halfWidth ... (1 - halfWidth)),
            y: center.y.clamped(to: halfHeight ... (1 - halfHeight))
        )
    }

    private func clampedSize(_ size: Vector2D) -> Vector2D {
        let clampedWidth = size.x.clamped(to: configuration.minCropSize ... configuration.maxCropSize)
        let clampedHeight = size.y.clamped(to: configuration.minCropSize ... configuration.maxCropSize)
        return Vector2D(x: clampedWidth, y: clampedHeight)
    }

    private func scaledSize(from size: Vector2D, multiplier: Double) -> Vector2D {
        let scaled = max(size.x, size.y) * multiplier
        let clamped = scaled.clamped(to: configuration.minCropSize ... configuration.maxCropSize)
        return Vector2D(x: clamped, y: clamped)
    }
}
