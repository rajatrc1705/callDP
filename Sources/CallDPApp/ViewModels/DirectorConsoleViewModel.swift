#if SWIFT_PACKAGE
import CallDPCore
#endif
import Combine
import Foundation

@MainActor
final class DirectorConsoleViewModel: ObservableObject {
    @Published private(set) var sessionState: RemoteSessionState
    @Published private(set) var latestAgentSnapshot: RemoteAgentSnapshot?
    @Published private(set) var latestTranscript = ""
    @Published private(set) var lastCommandSummary = "No commands sent yet"
    @Published private(set) var recentLogs: [String] = []

    private let remoteTransport: any RemoteCommandTransport
    private let commandParser: any CommandParsing
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false
    private var lastSnapshotMode: TrackingMode?

    init(
        remoteTransport: any RemoteCommandTransport,
        commandParser: any CommandParsing = HeuristicCommandParser()
    ) {
        self.remoteTransport = remoteTransport
        self.commandParser = commandParser
        sessionState = remoteTransport.currentSessionState
        latestAgentSnapshot = remoteTransport.currentAgentSnapshot
        bindTransport()
    }

    func start() {
        guard hasStarted == false else { return }
        hasStarted = true
        remoteTransport.register(role: .director, name: "Director")
        appendLog("director connected")
    }

    func stop() {
        guard hasStarted else { return }
        hasStarted = false
        remoteTransport.disconnect(role: .director)
    }

    func submitTranscript(_ text: String) {
        latestTranscript = text

        Task {
            let segment = TranscriptSegment(
                text: text,
                isFinal: true,
                timestamp: Date().timeIntervalSince1970
            )

            guard let command = try? await commandParser.parse(transcript: segment) else {
                await MainActor.run {
                    appendLog("unparsed transcript: \(text)")
                }
                return
            }

            await MainActor.run {
                send(command)
            }
        }
    }

    func sendManualCommand(_ command: DirectorCommand) {
        send(command)
    }

    private func bindTransport() {
        remoteTransport.sessionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let previous = sessionState.status
                sessionState = state

                if previous != state.status {
                    appendLog("session -> \(state.status.rawValue)")
                }
            }
            .store(in: &cancellables)

        remoteTransport.agentSnapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                latestAgentSnapshot = snapshot

                if let snapshot {
                    let nextMode = snapshot.sessionState.tracker.mode
                    if lastSnapshotMode != nextMode {
                        appendLog("agent snapshot -> \(nextMode.rawValue)")
                        lastSnapshotMode = nextMode
                    }
                } else {
                    appendLog("agent snapshot cleared")
                    lastSnapshotMode = nil
                }
            }
            .store(in: &cancellables)
    }

    private func send(_ command: DirectorCommand) {
        guard sessionState.status == .active else {
            appendLog("command blocked until camera agent accepts control")
            return
        }

        remoteTransport.send(command)
        lastCommandSummary = describe(command)
        appendLog("sent -> \(lastCommandSummary)")
    }

    private func appendLog(_ line: String) {
        recentLogs.insert(line, at: 0)
        recentLogs = Array(recentLogs.prefix(8))
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
