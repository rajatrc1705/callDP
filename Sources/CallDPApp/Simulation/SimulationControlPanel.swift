import CallDPCore
import SwiftUI

struct SimulationControlPanel: View {
    @ObservedObject var viewModel: DirectorViewModel
    @ObservedObject var simulation: SimulationController
    @State private var transcriptInput = "focus on the cooking vessel"

    var body: some View {
        GroupBox("Simulation") {
            VStack(alignment: .leading, spacing: 14) {
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
