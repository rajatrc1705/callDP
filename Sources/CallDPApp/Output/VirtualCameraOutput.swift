import CoreVideo
import Foundation

protocol VirtualCameraPublishing {
    func start() async throws
    func publishFrame(_ frame: CVPixelBuffer, at timestamp: TimeInterval) async
    func stop() async
}

final class StubVirtualCameraOutput: VirtualCameraPublishing {
    func start() async throws {}
    func publishFrame(_ frame: CVPixelBuffer, at timestamp: TimeInterval) async {
        _ = frame
        _ = timestamp
    }

    func stop() async {}
}
