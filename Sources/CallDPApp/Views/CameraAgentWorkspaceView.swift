#if SWIFT_PACKAGE
import CallDPCore
#endif
import SwiftUI

struct CameraAgentWindowContainer: View {
    @ObservedObject var runtime: AppRuntime
    @StateObject private var networkTransport = NetworkRemoteCommandTransport()
    @State private var transportMode: RemoteTransportMode = .loopback

    var body: some View {
        CameraAgentWorkspaceView(
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

struct CameraAgentWorkspaceView: View {
    @StateObject private var viewModel: CameraAgentViewModel
    @Binding private var transportMode: RemoteTransportMode
    @ObservedObject private var networkTransport: NetworkRemoteCommandTransport
    @State private var portInput = "6438"

    init(
        transport: any RemoteCommandTransport,
        transportMode: Binding<RemoteTransportMode>,
        networkTransport: NetworkRemoteCommandTransport
    ) {
        _viewModel = StateObject(wrappedValue: CameraAgentViewModel(remoteTransport: transport))
        _transportMode = transportMode
        self.networkTransport = networkTransport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            HStack(alignment: .top, spacing: 20) {
                previewColumn
                sidePanelScroll
                    .frame(width: 380)
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
                Text("Camera Agent")
                    .font(.largeTitle.weight(.semibold))
                Text("Local camera runtime with remote-directed reframing.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            microphoneBadge

            Picker("Backend", selection: Binding(
                get: { viewModel.backendMode },
                set: { viewModel.setBackendMode($0) }
            )) {
                ForEach(BackendMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
        }
    }

    private var microphoneBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: microphoneSymbolName)
                .imageScale(.medium)
            Text(viewModel.audioInputState.title)
                .font(.system(.subheadline, design: .monospaced))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(microphoneBadgeColor.opacity(0.14))
        .foregroundStyle(microphoneBadgeColor)
        .clipShape(Capsule())
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

    private var sidePanelScroll: some View {
        ScrollView {
            sidePanel
        }
        .scrollIndicators(.visible)
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            transportPanel
            remoteControlPanel
            speechPanel
            statusPanel
            SimulationControlPanel(viewModel: viewModel, simulation: viewModel.simulation)
            logPanel
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
                        TextField("Port", text: $portInput)
                            .textFieldStyle(.roundedBorder)
                        Button(networkTransport.isHosting ? "Restart Host" : "Start Host") {
                            startHosting()
                        }
                        if networkTransport.isHosting || networkTransport.isConnected {
                            Button("Stop") {
                                networkTransport.stopNetworking()
                            }
                        }
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

    private var remoteControlPanel: some View {
        GroupBox("Remote Control") {
            VStack(alignment: .leading, spacing: 10) {
                row(label: "Status", value: viewModel.remoteSessionState.status.title)
                row(label: "Summary", value: viewModel.remoteSessionState.statusSummary)
                row(label: "Director", value: viewModel.remoteSessionState.directorName ?? "not connected")

                HStack {
                    if viewModel.remoteSessionState.status == .pendingConsent {
                        Button("Accept") {
                            viewModel.acceptRemoteControl()
                        }
                    }

                    if viewModel.remoteSessionState.status == .active {
                        Button("Pause") {
                            viewModel.pauseRemoteControl()
                        }
                    }

                    if viewModel.remoteSessionState.status == .paused {
                        Button("Resume") {
                            viewModel.resumeRemoteControl()
                        }
                    }

                    if viewModel.remoteSessionState.status != .idle {
                        Button("Disconnect") {
                            viewModel.disconnectRemoteControl()
                        }
                    }
                }
            }
        }
    }

    private var statusPanel: some View {
        GroupBox("Agent State") {
            VStack(alignment: .leading, spacing: 10) {
                statusRows
                detectionButtons
            }
        }
    }

    private var speechPanel: some View {
        GroupBox("Speech") {
            VStack(alignment: .leading, spacing: 10) {
                row(label: "Status", value: viewModel.audioInputState.title)
                Text(viewModel.audioInputState.detail)
                    .font(.caption)
                    .foregroundStyle(viewModel.audioInputState.isListening ? .green : .secondary)

                if viewModel.backendMode.supportsLiveSpeech {
                    HStack {
                        Button("Start Listening") {
                            viewModel.startSpeechListening()
                        }
                        .disabled(viewModel.audioInputState == .starting || viewModel.audioInputState.isListening)

                        Button("Stop Listening") {
                            viewModel.stopSpeechListening()
                        }
                        .disabled(viewModel.audioInputState.isListening == false && viewModel.audioInputState != .starting)
                    }
                }
            }
        }
    }

    private var statusRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(label: "Tracker", value: viewModel.sessionState.tracker.mode.rawValue)
            row(label: "Command", value: viewModel.lastCommandSummary)
            transcriptRow
            row(label: "Grounding", value: viewModel.groundingStatusSummary)
            row(label: "Crop", value: cropSummary)
            row(label: "Source", value: sourceSummary)
        }
    }

    private var transcriptRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TRANSCRIPT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(viewModel.latestTranscriptIsFinal ? "FINAL" : "PARTIAL")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(transcriptBadgeColor.opacity(0.14))
                    .foregroundStyle(transcriptBadgeColor)
                    .clipShape(Capsule())
            }

            if viewModel.latestTranscript.isEmpty {
                Text("none")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.latestTranscript)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(viewModel.latestTranscriptIsFinal ? Color.primary : Color.orange)
            }
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

    private var microphoneBadgeColor: Color {
        switch viewModel.audioInputState {
        case .manualOnly:
            return .secondary
        case .starting:
            return .yellow
        case .listening:
            return .green
        case .stopped:
            return .secondary
        case .error:
            return .red
        }
    }

    private var microphoneSymbolName: String {
        switch viewModel.audioInputState {
        case .manualOnly, .stopped:
            return "mic.slash.fill"
        case .starting:
            return "waveform"
        case .listening:
            return "mic.fill"
        case .error:
            return "exclamationmark.mic.fill"
        }
    }

    private var transcriptBadgeColor: Color {
        viewModel.latestTranscriptIsFinal ? .green : .orange
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

    private func startHosting() {
        guard let port = UInt16(portInput) else { return }
        try? networkTransport.startHosting(on: port)
    }
}
