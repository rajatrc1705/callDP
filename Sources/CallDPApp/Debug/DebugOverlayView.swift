#if SWIFT_PACKAGE
import CallDPCore
#endif
import SwiftUI

struct DebugOverlayView: View {
    let cropRect: NormalizedRect
    let detections: [DetectionCandidate]
    let tracker: TrackerState
    let lastCommandSummary: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(rect(for: cropRect, in: proxy.size))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))

                ForEach(detections) { detection in
                    let rect = rect(for: detection.boundingBox, in: proxy.size)

                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(tracker.targetID == detection.id ? Color.green : Color.blue, lineWidth: 2)

                    Text("\(detection.label) \(Int(detection.confidence * 100))%")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.7))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .offset(x: rect.minX + 6, y: rect.minY + 6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("mode: \(tracker.mode.rawValue)")
                    Text("command: \(lastCommandSummary)")
                    Text("confidence: \(String(format: "%.2f", tracker.confidence))")
                }
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .padding(10)
                .background(.black.opacity(0.7))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)
            }
        }
        .allowsHitTesting(false)
    }

    private func rect(for normalizedRect: NormalizedRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalizedRect.x * size.width,
            y: normalizedRect.y * size.height,
            width: normalizedRect.width * size.width,
            height: normalizedRect.height * size.height
        )
    }
}
