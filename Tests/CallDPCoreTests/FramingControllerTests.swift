import Testing
@testable import CallDPCore

struct FramingControllerTests {
    @Test
    func keepsFrameStableInsideDeadZone() {
        let controller = FramingController()
        let crop = CropState(center: Vector2D(x: 0.5, y: 0.5), size: Vector2D(x: 0.7, y: 0.7), timestamp: 0)
        let tracker = TrackerState(
            mode: .tracking,
            bbox: NormalizedRect(x: 0.44, y: 0.44, width: 0.12, height: 0.12),
            confidence: 0.9,
            velocity: .zero
        )

        let next = controller.update(crop: crop, tracker: tracker, now: 1.0 / 60.0)

        #expect(abs(next.center.x - 0.5) < 0.005)
        #expect(abs(next.center.y - 0.5) < 0.005)
    }

    @Test
    func movesTowardOffCenterTarget() {
        let controller = FramingController()
        let crop = CropState(center: Vector2D(x: 0.5, y: 0.5), size: Vector2D(x: 0.8, y: 0.8), timestamp: 0)
        let tracker = TrackerState(
            mode: .tracking,
            bbox: NormalizedRect(x: 0.72, y: 0.4, width: 0.12, height: 0.12),
            confidence: 0.9,
            velocity: .zero
        )

        let next = controller.update(crop: crop, tracker: tracker, now: 1.0 / 30.0)

        #expect(next.center.x > crop.center.x)
    }

    @Test
    func zoomsInForSmallTarget() {
        let controller = FramingController()
        let crop = CropState(center: Vector2D(x: 0.5, y: 0.5), size: Vector2D(x: 1, y: 1), timestamp: 0)
        let tracker = TrackerState(
            mode: .tracking,
            bbox: NormalizedRect(x: 0.48, y: 0.46, width: 0.08, height: 0.08),
            confidence: 0.9,
            velocity: .zero,
            zoomMode: .automatic
        )

        let next = controller.update(crop: crop, tracker: tracker, now: 1.0 / 15.0)

        #expect(next.size.x < crop.size.x)
        #expect(next.zoom > crop.zoom)
    }

    @Test
    func manualPanCreatesHeadroomWhenCropIsFullFrame() {
        var controller = FramingController()
        var crop = CropState(center: Vector2D(x: 0.5, y: 0.5), size: Vector2D(x: 1, y: 1), timestamp: 0)

        controller.apply(
            command: .pan(.left, source: .keyboard),
            to: &crop,
            now: 1.0
        )

        #expect(crop.size.x < 1.0)
        #expect(crop.center.x < 0.5)
        #expect(crop.zoom > 1.0)
    }

    @Test
    func manualFramingPersistsWhileTrackerIsIdle() {
        let controller = FramingController()
        let crop = CropState(
            center: Vector2D(x: 0.42, y: 0.5),
            size: Vector2D(x: 0.82, y: 0.82),
            zoom: 1 / 0.82,
            velocity: .zero,
            timestamp: 1.0
        )
        let tracker = TrackerState(mode: .idle)

        let next = controller.update(crop: crop, tracker: tracker, now: 1.0 + (1.0 / 30.0))

        #expect(abs(next.center.x - crop.center.x) < 0.001)
        #expect(abs(next.size.x - crop.size.x) < 0.001)
    }
}
