import AppKit
import CallDPCore
import CoreImage
import Foundation

@MainActor
final class ReframedPreviewRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func render(frame: CameraFrame, crop: CropState) -> NSImage? {
        let extent = frame.image.extent
        guard extent.width > 0, extent.height > 0 else {
            return nil
        }

        let rect = crop.rect
        let cropRect = CGRect(
            x: extent.minX + (extent.width * rect.x),
            y: extent.minY + (extent.height * (1 - rect.y - rect.height)),
            width: extent.width * rect.width,
            height: extent.height * rect.height
        ).integral

        guard let cgImage = context.createCGImage(frame.image.cropped(to: cropRect), from: cropRect) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cropRect.width, height: cropRect.height))
    }
}
