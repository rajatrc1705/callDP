import CoreGraphics
import CoreImage
import Foundation

struct CameraFrame: @unchecked Sendable {
    let image: CIImage
    let size: CGSize
    let timestamp: TimeInterval
}
