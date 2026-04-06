import CallDPCore
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DirectorViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            HStack(alignment: .top, spacing: 20) {
                previewColumn
                sidePanel
                    .frame(width: 360)
            }
        }
        .padding(20)
        .frame(minWidth: 1380, minHeight: 860)
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CallDP Director Prototype")
                    .font(.largeTitle.weight(.semibold))
                Text("Language-grounded digital reframing pipeline for macOS camera feeds.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Backend", selection: Binding(
                get: { viewModel.backendMode },
                set: { viewModel.setBackendMode($0) }
            )) {
                ForEach(BackendMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            previewCard(
                title: "Raw Camera Feed",
                subtitle: "Built-in camera input with debug overlays for detections and crop.",
                content: {
                    ZStack {
                        CameraPreviewView(session: viewModel.cameraCapture.session)
                            .background(Color.black)

                        DebugOverlayView(
                            cropRect: viewModel.sessionState.crop.rect,
                            detections: viewModel.lastDetections,
                            tracker: viewModel.sessionState.tracker,
                            lastCommandSummary: viewModel.lastCommandSummary
                        )
                    }
                }
            )

            previewCard(
                title: "Reframed Output",
                subtitle: "Deterministic crop controller output intended for future virtual camera publishing.",
                content: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black)

                        if let image = viewModel.processedImage {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        } else {
                            VStack(spacing: 10) {
                                Text("Waiting for frames")
                                    .font(.headline)
                                Text(viewModel.cameraCapture.errorMessage ?? "Grant camera access or keep the app running until frames arrive.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            )
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            statusPanel
            SimulationControlPanel(viewModel: viewModel, simulation: viewModel.simulation)
            logPanel
        }
    }

    private var statusPanel: some View {
        GroupBox("Director State") {
            VStack(alignment: .leading, spacing: 10) {
                statusRows
                detectionButtons
            }
        }
    }

    private var statusRows: some View {
        Group {
            row(label: "Tracker", value: viewModel.sessionState.tracker.mode.rawValue)
            row(label: "Command", value: viewModel.lastCommandSummary)
            row(label: "Transcript", value: viewModel.latestTranscript.isEmpty ? "none" : viewModel.latestTranscript)
            row(label: "Crop", value: cropSummary)
            row(label: "Source", value: sourceSummary)
        }
    }

    @ViewBuilder
    private var detectionButtons: some View {
        if viewModel.lastDetections.isEmpty == false {
            Divider()

            ForEach(Array(viewModel.lastDetections.enumerated()), id: \.element.id) { index, detection in
                Button(candidateTitle(index: index, detection: detection)) {
                    viewModel.sendManualCommand(selectCandidateCommand(index: index))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var logPanel: some View {
        GroupBox("Logs") {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(viewModel.recentLogs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 160)
        }
    }

    private func previewCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.25))
                )
        }
    }

    private func row(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private var cropSummary: String {
        let rect = viewModel.sessionState.crop.rect
        return "\(format(rect.x)), \(format(rect.y)) / \(format(rect.width))"
    }

    private var sourceSummary: String {
        "\(Int(viewModel.sourceFrameSize.width)) × \(Int(viewModel.sourceFrameSize.height))"
    }

    private func candidateTitle(index: Int, detection: DetectionCandidate) -> String {
        "\(index + 1). \(detection.label) \(Int(detection.confidence * 100))%"
    }

    private func selectCandidateCommand(index: Int) -> DirectorCommand {
        DirectorCommand(
            intent: .selectCandidate,
            selectedCandidateIndex: index,
            source: .keyboard
        )
    }
}
