#if SWIFT_PACKAGE
import CallDPCore
#endif
import SwiftUI

struct DirectorWindowContainer: View {
    @ObservedObject var runtime: AppRuntime
    @StateObject private var networkTransport = NetworkRemoteCommandTransport()
    @State private var transportMode: RemoteTransportMode = .loopback

    var body: some View {
        DirectorWorkspaceView(
            transport: activeTransport,
            transportMode: $transportMode,
            networkTransport: networkTransport
        )
        .id(transportMode.rawValue)
    }

    private var activeTransport: any RemoteCommandTransport {
        switch transportMode {
        case .loopback:
            runtime.loopbackTransport
        case .network:
            networkTransport
        }
    }
}

struct DirectorWorkspaceView: View {
    @StateObject private var viewModel: DirectorConsoleViewModel
    @Binding private var transportMode: RemoteTransportMode
    @ObservedObject private var networkTransport: NetworkRemoteCommandTransport
    @State private var transcriptInput = "focus on the cooking vessel"
    @State private var hostInput = "127.0.0.1"
    @State private var portInput = "6438"

    init(
        transport: any RemoteCommandTransport,
        transportMode: Binding<RemoteTransportMode>,
        networkTransport: NetworkRemoteCommandTransport
    ) {
        _viewModel = StateObject(wrappedValue: DirectorConsoleViewModel(remoteTransport: transport))
        _transportMode = transportMode
        self.networkTransport = networkTransport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            HStack(alignment: .top, spacing: 20) {
                commandPanelScroll
                    .frame(minWidth: 360, maxWidth: 420)
                agentPanelScroll
            }
        }
        .padding(20)
        .frame(minWidth: 1180, minHeight: 760)
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
                Text("Director Console")
                    .font(.largeTitle.weight(.semibold))
                Text("Issue framing commands and monitor the paired camera agent.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(viewModel.sessionState.status.title)
                .font(.headline.monospaced())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial)
                .clipShape(Capsule())
        }
    }

    private var commandPanelScroll: some View {
        ScrollView {
            commandPanel
        }
        .scrollIndicators(.visible)
    }

    private var commandPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            transportPanel

            GroupBox("Session") {
                VStack(alignment: .leading, spacing: 10) {
                    row(label: "Summary", value: viewModel.sessionState.statusSummary)
                    row(label: "Camera Agent", value: viewModel.sessionState.agentName ?? "not connected")
                    row(label: "Last Command", value: viewModel.lastCommandSummary)
                    row(label: "Transcript", value: viewModel.latestTranscript.isEmpty ? "none" : viewModel.latestTranscript)
                }
            }

            GroupBox("Direct Commands") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        TextField("Transcript", text: $transcriptInput)
                        Button("Send") {
                            viewModel.submitTranscript(transcriptInput)
                        }
                        .disabled(viewModel.sessionState.status != .active)
                    }

                    HStack {
                        Button("Left") { viewModel.sendManualCommand(.pan(.left, source: .keyboard)) }
                        Button("Right") { viewModel.sendManualCommand(.pan(.right, source: .keyboard)) }
                        Button("Up") { viewModel.sendManualCommand(.pan(.up, source: .keyboard)) }
                        Button("Down") { viewModel.sendManualCommand(.pan(.down, source: .keyboard)) }
                    }
                    .disabled(viewModel.sessionState.status != .active)

                    HStack {
                        Button("Zoom In") { viewModel.sendManualCommand(.zoom(.stepIn, source: .keyboard)) }
                        Button("Zoom Out") { viewModel.sendManualCommand(.zoom(.stepOut, source: .keyboard)) }
                        Button("Recenter") { viewModel.sendManualCommand(DirectorCommand(intent: .recenter, source: .keyboard)) }
                        Button("Stop") { viewModel.sendManualCommand(DirectorCommand(intent: .stopTracking, source: .keyboard)) }
                    }
                    .disabled(viewModel.sessionState.status != .active)
                }
            }

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
                .frame(height: 240)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var transportPanel: some View {
        GroupBox("Transport") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Transport", selection: $transportMode) {
                    ForEach(RemoteTransportMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if transportMode == .loopback {
                    Text("Using the in-app loopback transport for same-machine testing.")
                        .foregroundStyle(.secondary)
                } else {
                    row(label: "Status", value: networkTransport.statusText)
                    row(label: "Peer", value: networkTransport.peerText)

                    HStack {
                        TextField("Host", text: $hostInput)
                            .textFieldStyle(.roundedBorder)
                        TextField("Port", text: $portInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                    }

                    HStack {
                        Button("Connect") {
                            connectToAgent()
                        }
                        Button("Disconnect") {
                            networkTransport.stopNetworking()
                        }
                        .disabled(networkTransport.isConnected == false && networkTransport.isHosting == false)
                    }

                    if let error = networkTransport.lastErrorMessage, error.isEmpty == false {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var agentPanelScroll: some View {
        ScrollView {
            agentPanel
        }
        .scrollIndicators(.visible)
    }

    private var agentPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Camera Agent Snapshot") {
                if let snapshot = viewModel.latestAgentSnapshot {
                    VStack(alignment: .leading, spacing: 10) {
                        row(label: "Tracker", value: snapshot.sessionState.tracker.mode.rawValue)
                        row(label: "Backend", value: snapshot.backendLabel)
                        row(label: "Grounding", value: snapshot.groundingStatusSummary)
                        row(label: "Command", value: snapshot.lastCommandSummary)
                        row(label: "Transcript", value: snapshot.latestTranscript.isEmpty ? "none" : snapshot.latestTranscript)
                        row(label: "Source", value: "\(snapshot.sourceFrameSize.width) × \(snapshot.sourceFrameSize.height)")
                        candidateButtons(snapshot: snapshot)
                    }
                } else {
                    Text("No camera agent snapshot yet.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Agent Logs") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.latestAgentSnapshot?.recentLogs ?? [], id: \.self) { line in
                            Text(line)
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func candidateButtons(snapshot: RemoteAgentSnapshot) -> some View {
        if snapshot.sessionState.candidateDetections.isEmpty == false {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Candidates")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(snapshot.sessionState.candidateDetections.enumerated()), id: \.element.id) { index, detection in
                    Button("\(index + 1). \(detection.label) \(Int(detection.confidence * 100))%") {
                        viewModel.sendManualCommand(
                            DirectorCommand(
                                intent: .selectCandidate,
                                selectedCandidateIndex: index,
                                source: .keyboard
                            )
                        )
                    }
                    .disabled(viewModel.sessionState.status != .active)
                }
            }
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

    private func connectToAgent() {
        guard let port = UInt16(portInput) else { return }
        networkTransport.connect(to: hostInput, port: port)
    }
}
