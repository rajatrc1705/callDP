import AppKit
#if SWIFT_PACKAGE
import CallDPCore
#endif
import Combine
import Foundation

@MainActor
final class CameraAgentViewModel: ObservableObject {
    @Published var backendMode: BackendMode
    @Published private(set) var sessionState = DirectorSessionState()
    @Published private(set) var processedImage: NSImage?
    @Published private(set) var latestTranscript = ""
    @Published private(set) var latestTranscriptIsFinal = true
    @Published private(set) var lastCommandSummary = "No commands yet"
    @Published private(set) var recentLogs: [String] = []
    @Published private(set) var lastDetections: [DetectionCandidate] = []
    @Published private(set) var sourceFrameSize: CGSize = .zero
    @Published private(set) var remoteSessionState = RemoteSessionState()
    @Published private(set) var audioInputState: AudioInputState = .stopped
    @Published private(set) var groundingStatusSummary = "Synthetic detections"

    let cameraCapture: CameraCaptureService
    let simulation: SimulationController

    private let remoteTransport: any RemoteCommandTransport
    private var environment: AppEnvironment
    private var stateMachine = DirectorStateMachine()
    private var framingController = FramingController()
    private let renderer = ReframedPreviewRenderer()

    private var latestFrame: CameraFrame?
    private var processingDetection = false
    private var processingTracking = false
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

    init(
        remoteTransport: any RemoteCommandTransport,
        cameraCapture: CameraCaptureService = CameraCaptureService(),
        simulation: SimulationController = SimulationController(),
        backendMode: BackendMode = .simulated
    ) {
        self.remoteTransport = remoteTransport
        self.cameraCapture = cameraCapture
        self.simulation = simulation
        self.backendMode = backendMode
        environment = AppEnvironment.make(mode: backendMode, simulation: simulation)
        remoteSessionState = remoteTransport.currentSessionState
        groundingStatusSummary = groundingSummary(for: backendMode)

        bindEnvironment()
        bindTransport()

        cameraCapture.onFrame = { [weak self] frame in
            self?.handle(frame: frame)
        }
    }

    func start() {
        guard hasStarted == false else { return }
        hasStarted = true

        remoteTransport.register(role: .cameraAgent, name: "Camera Agent")
        cameraCapture.start()
        publishSnapshot()

        Task {
            await startAudioTranscriber()
        }
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false

        cameraCapture.stop()
        remoteTransport.disconnect(role: .cameraAgent)

        Task {
            await environment.audioTranscriber.stop()
            await environment.trackingEngine.stopTracking()
        }
    }

    func acceptRemoteControl() {
        remoteTransport.acceptControl()
        appendLog("remote control accepted")
    }

    func pauseRemoteControl() {
        remoteTransport.pauseControl()
        appendLog("remote control paused")
    }

    func resumeRemoteControl() {
        remoteTransport.resumeControl()
        appendLog("remote control resumed")
    }

    func disconnectRemoteControl() {
        remoteTransport.endSession(for: .cameraAgent)
        appendLog("director disconnected")
    }

    func setBackendMode(_ mode: BackendMode) {
        guard backendMode != mode else { return }

        Task { @MainActor in
            await environment.audioTranscriber.stop()
            await environment.trackingEngine.stopTracking()

            backendMode = mode
            environment = AppEnvironment.make(mode: mode, simulation: simulation)
            resetPerceptionState()
            bindEnvironment()
            appendLog("backend -> \(mode.title)")

            if hasStarted {
                await startAudioTranscriber()
            }

            publishSnapshot()
        }
    }

    func submitTranscript(_ text: String) {
        if let transcriber = environment.audioTranscriber as? StubAudioTranscriber {
            transcriber.inject(text: text)
            return
        }

        Task {
            await consumeTranscript(
                TranscriptSegment(
                    text: text,
                    isFinal: true,
                    timestamp: Date().timeIntervalSince1970
                )
            )
        }
    }

    func sendManualCommand(_ command: DirectorCommand) {
        apply(command: command, timestamp: latestFrame?.timestamp ?? Date().timeIntervalSince1970)
    }

    func startSpeechListening() {
        Task {
            await startAudioTranscriber()
        }
    }

    func stopSpeechListening() {
        Task {
            await environment.audioTranscriber.stop()
        }
    }

    private func bindEnvironment() {
        environment.audioTranscriber.onTranscript = { [weak self] segment in
            guard let self else { return }
            Task { @MainActor in
                await self.consumeTranscript(segment)
            }
        }

        environment.audioTranscriber.onStateChange = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                self.audioInputState = state
            }
        }
    }

    private func bindTransport() {
        cancellables.removeAll()

        remoteTransport.sessionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let previous = remoteSessionState.status
                remoteSessionState = state

                if previous != state.status {
                    appendLog("session -> \(state.status.rawValue)")
                }
            }
            .store(in: &cancellables)

        remoteTransport.incomingCommandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                guard let self else { return }
                apply(command: command, timestamp: latestFrame?.timestamp ?? Date().timeIntervalSince1970)
            }
            .store(in: &cancellables)
    }

    private func consumeTranscript(_ segment: TranscriptSegment) async {
        latestTranscript = segment.text
        latestTranscriptIsFinal = segment.isFinal
        publishSnapshot()

        guard segment.isFinal else { return }

        guard let command = try? await environment.commandParser.parse(transcript: segment) else {
            appendLog("unparsed transcript: \(segment.text)")
            return
        }

        apply(command: command, timestamp: segment.timestamp)
    }

    private func handle(frame: CameraFrame) {
        latestFrame = frame
        sourceFrameSize = frame.size

        sessionState.crop = framingController.update(
            crop: sessionState.crop,
            tracker: sessionState.tracker,
            now: frame.timestamp
        )
        processedImage = renderer.render(frame: frame, crop: sessionState.crop)

        switch sessionState.tracker.mode {
        case .tracking:
            requestTrackingUpdate(for: frame)
        case .detecting, .reacquiring:
            requestDetection(for: frame)
        case .idle, .lostTarget:
            break
        }

        publishSnapshot()
    }

    private func requestDetection(for frame: CameraFrame) {
        guard processingDetection == false else { return }
        guard let description = sessionState.tracker.activeDescription else { return }

        processingDetection = true

        Task { @MainActor in
            defer { processingDetection = false }

            let request = GroundingRequest(
                targetDescription: description,
                candidateQueries: sessionState.tracker.candidateQueries
            )
            groundingStatusSummary = "Detecting \(description)"

            do {
                let detections = try await environment.groundingEngine.detect(in: frame, request: request)
                let transitions = stateMachine.applyDetections(detections, to: &sessionState, now: frame.timestamp)
                lastDetections = sessionState.candidateDetections
                groundingStatusSummary = detections.isEmpty
                    ? "No matches for \(description)"
                    : "Found \(detections.count) candidate\(detections.count == 1 ? "" : "s")"
                emit(transitions)

                if sessionState.tracker.mode == .tracking, let locked = sessionState.candidateDetections.first {
                    await environment.trackingEngine.beginTracking(target: locked, in: frame)
                    appendLog("locked target: \(locked.label) @ \(String(format: "%.2f", locked.confidence))")
                }
            } catch {
                groundingStatusSummary = "Error: \(error.localizedDescription)"
                appendLog("grounding error -> \(error.localizedDescription)")
            }

            publishSnapshot()
        }
    }

    private func requestTrackingUpdate(for frame: CameraFrame) {
        guard processingTracking == false else { return }

        processingTracking = true

        Task { @MainActor in
            defer { processingTracking = false }

            let observation = await environment.trackingEngine.update(with: frame)
            let transitions = stateMachine.applyTrackingObservation(observation, to: &sessionState, now: frame.timestamp)
            emit(transitions)

            if let observation {
                appendLog("tracking \(String(format: "%.2f", observation.confidence))")
            }

            publishSnapshot()
        }
    }

    private func apply(command: DirectorCommand, timestamp: TimeInterval) {
        let transitions = stateMachine.apply(command: command, to: &sessionState, now: timestamp)

        switch command.intent {
        case .moveFrame, .zoom, .recenter:
            framingController.apply(command: command, to: &sessionState.crop, now: timestamp)
        case .stopTracking:
            Task { await environment.trackingEngine.stopTracking() }
        case .selectCandidate:
            if
                let index = command.selectedCandidateIndex,
                sessionState.candidateDetections.indices.contains(index),
                let frame = latestFrame
            {
                let selected = sessionState.candidateDetections[index]
                Task { @MainActor in
                    await environment.trackingEngine.beginTracking(target: selected, in: frame)
                }
            }
        case .focusObject, .lockCurrentTarget:
            break
        }

        lastCommandSummary = describe(command)
        lastDetections = sessionState.candidateDetections
        emit(transitions)
        publishSnapshot()
    }

    private func emit(_ transitions: [DirectorTransition]) {
        for transition in transitions {
            appendLog("\(transition.from.rawValue) -> \(transition.to.rawValue) [\(transition.reason)]")
        }
    }

    private func startAudioTranscriber() async {
        do {
            try await environment.audioTranscriber.start()
            appendLog("audio -> listening")
        } catch {
            audioInputState = .error(error.localizedDescription)
            appendLog("audio error -> \(error.localizedDescription)")
        }
    }

    private func resetPerceptionState() {
        sessionState.tracker = TrackerState()
        sessionState.candidateDetections = []
        lastDetections = []
        latestTranscript = ""
        latestTranscriptIsFinal = true
        lastCommandSummary = "No commands yet"
        audioInputState = .stopped
        groundingStatusSummary = groundingSummary(for: backendMode)
    }

    private func appendLog(_ line: String) {
        recentLogs.insert(line, at: 0)
        recentLogs = Array(recentLogs.prefix(8))
        publishSnapshot()
    }

    private func groundingSummary(for mode: BackendMode) -> String {
        switch mode {
        case .mock:
            return "Stub grounding"
        case .simulated:
            return "Synthetic detections"
        case .apple:
            return "Synthetic detections"
        case .grounded:
            return "Model worker idle"
        }
    }

    private func publishSnapshot() {
        remoteTransport.publishAgentSnapshot(
            RemoteAgentSnapshot(
                sessionState: sessionState,
                latestTranscript: latestTranscript,
                lastCommandSummary: lastCommandSummary,
                groundingStatusSummary: groundingStatusSummary,
                recentLogs: recentLogs,
                sourceFrameSize: VideoFrameSize(
                    width: Int(sourceFrameSize.width),
                    height: Int(sourceFrameSize.height)
                ),
                backendLabel: backendMode.title
            )
        )
    }

    private func describe(_ command: DirectorCommand) -> String {
        switch command.intent {
        case .focusObject:
            return "Focus on \(command.targetDescription ?? "target")"
        case .moveFrame:
            return "Move \(command.direction?.rawValue ?? "frame")"
        case .zoom:
            return "Zoom \(command.zoomMode.rawValue)"
        case .recenter:
            return "Recenter"
        case .stopTracking:
            return "Stop tracking"
        case .selectCandidate:
            return "Select candidate \(command.selectedCandidateIndex ?? 0)"
        case .lockCurrentTarget:
            return "Lock current target"
        }
    }
}
