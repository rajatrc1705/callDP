#if SWIFT_PACKAGE
import CallDPCore
#endif
import SwiftUI

struct SimulationControlPanel: View {
    @ObservedObject var viewModel: CameraAgentViewModel
    @ObservedObject var simulation: SimulationController
    @State private var transcriptInput = "focus on the cooking vessel"

    var body: some View {
        GroupBox(panelTitle) {
            VStack(alignment: .leading, spacing: 14) {
                Text(panelSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Transcript", text: $transcriptInput)
                    Button("Send") {
                        viewModel.submitTranscript(transcriptInput)
                    }
                }

                HStack {
                    Button("Left") { viewModel.sendManualCommand(.pan(.left, source: .keyboard)) }
                    Button("Right") { viewModel.sendManualCommand(.pan(.right, source: .keyboard)) }
                    Button("Up") { viewModel.sendManualCommand(.pan(.up, source: .keyboard)) }
                    Button("Down") { viewModel.sendManualCommand(.pan(.down, source: .keyboard)) }
                }

                HStack {
                    Button("Zoom In") { viewModel.sendManualCommand(.zoom(.stepIn, source: .keyboard)) }
                    Button("Zoom Out") { viewModel.sendManualCommand(.zoom(.stepOut, source: .keyboard)) }
                    Button("Recenter") { viewModel.sendManualCommand(DirectorCommand(intent: .recenter, source: .keyboard)) }
                    Button("Stop") { viewModel.sendManualCommand(DirectorCommand(intent: .stopTracking, source: .keyboard)) }
                }

                Divider()

                LabeledContent("Description") {
                    TextField("Target description", text: $simulation.targetDescription)
                }

                LabeledContent("Label") {
                    TextField("Primary label", text: $simulation.primaryLabel)
                }

                LabeledContent("Animate") {
                    Toggle("Motion", isOn: $simulation.animateMotion)
                        .toggleStyle(.switch)
                }

                sliderRow(title: "Center X", value: $simulation.centerX, range: 0.1 ... 0.9)
                sliderRow(title: "Center Y", value: $simulation.centerY, range: 0.1 ... 0.9)
                sliderRow(title: "Width", value: $simulation.boxWidth, range: 0.08 ... 0.5)
                sliderRow(title: "Height", value: $simulation.boxHeight, range: 0.08 ... 0.5)
                sliderRow(title: "Confidence", value: $simulation.confidence, range: 0.2 ... 0.99)
                sliderRow(title: "Horizontal Amp", value: $simulation.horizontalAmplitude, range: 0 ... 0.3)
                sliderRow(title: "Vertical Amp", value: $simulation.verticalAmplitude, range: 0 ... 0.2)
            }
        }
    }

    private var panelTitle: String {
        switch viewModel.backendMode {
        case .mock, .simulated:
            return "Simulation"
        case .apple, .grounded:
            return "Manual Commands & Target Injection"
        }
    }

    private var panelSubtitle: String {
        switch viewModel.backendMode {
        case .mock:
            return "Inject transcripts and synthetic detections into the fully stubbed backend."
        case .simulated:
            return "Inject transcripts and synthetic detections into the simulated grounding and tracking pipeline."
        case .apple:
            return "Speech uses Apple recognition and tracking uses Vision. Synthetic detections still seed target lock until the grounding model is replaced."
        case .grounded:
            return "Speech uses Apple recognition, tracking uses Vision, and focus-on commands use the local Python grounding worker. Synthetic target injection remains available for debugging."
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range)
        }
    }
}
