#if SWIFT_PACKAGE
import CallDPCore
#endif
import SwiftUI

struct ContentView: View {
    @ObservedObject var runtime: AppRuntime
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CallDP")
                    .font(.largeTitle.weight(.semibold))
                Text("Remote-directed camera reframing for Mac-to-Mac calls.")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Launch Windows") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Use one window as the Director and another as the Camera Agent. The loopback transport lets you test the full control flow on a single Mac.")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button("Open Director") {
                            openWindow(id: AppWindowID.director)
                        }

                        Button("Open Camera Agent") {
                            openWindow(id: AppWindowID.cameraAgent)
                        }
                    }
                }
            }

            GroupBox("Loopback Session") {
                VStack(alignment: .leading, spacing: 10) {
                    row(label: "Status", value: runtime.loopbackTransport.sessionState.status.title)
                    row(label: "Summary", value: runtime.loopbackTransport.sessionState.statusSummary)
                    row(label: "Director", value: runtime.loopbackTransport.sessionState.directorName ?? "not connected")
                    row(label: "Camera Agent", value: runtime.loopbackTransport.sessionState.agentName ?? "not connected")
                }
            }

            GroupBox("Current Product Slice") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Launch a Camera Agent window and let it accept remote control.")
                    Text("2. Launch a Director window and send commands over the loopback transport.")
                    Text("3. Validate that the agent preview reframes without any real network or model dependencies.")
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 680, minHeight: 420)
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
}
