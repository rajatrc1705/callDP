#if SWIFT_PACKAGE
import CallDPCore
#endif
import Combine
import Foundation
import Network

private struct RemoteRegisterPayload: Codable {
    var role: CallDPRole
    var name: String
}

private enum RemoteEnvelopeKind: String, Codable {
    case register
    case sessionState = "session_state"
    case agentSnapshot = "agent_snapshot"
    case command
}

private struct RemoteEnvelope: Codable {
    var kind: RemoteEnvelopeKind
    var register: RemoteRegisterPayload?
    var sessionState: RemoteSessionState?
    var agentSnapshot: RemoteAgentSnapshot?
    var command: DirectorCommand?

    static func register(_ payload: RemoteRegisterPayload) -> RemoteEnvelope {
        RemoteEnvelope(kind: .register, register: payload)
    }

    static func sessionState(_ payload: RemoteSessionState) -> RemoteEnvelope {
        RemoteEnvelope(kind: .sessionState, sessionState: payload)
    }

    static func agentSnapshot(_ payload: RemoteAgentSnapshot) -> RemoteEnvelope {
        RemoteEnvelope(kind: .agentSnapshot, agentSnapshot: payload)
    }

    static func command(_ payload: DirectorCommand) -> RemoteEnvelope {
        RemoteEnvelope(kind: .command, command: payload)
    }

    init(
        kind: RemoteEnvelopeKind,
        register: RemoteRegisterPayload? = nil,
        sessionState: RemoteSessionState? = nil,
        agentSnapshot: RemoteAgentSnapshot? = nil,
        command: DirectorCommand? = nil
    ) {
        self.kind = kind
        self.register = register
        self.sessionState = sessionState
        self.agentSnapshot = agentSnapshot
        self.command = command
    }
}

@MainActor
final class NetworkRemoteCommandTransport: ObservableObject, RemoteCommandTransport {
    @Published private(set) var sessionState = RemoteSessionState()
    @Published private(set) var agentSnapshot: RemoteAgentSnapshot?
    @Published private(set) var statusText = "Idle"
    @Published private(set) var peerText = "No peer"
    @Published private(set) var listenPort: UInt16?
    @Published private(set) var isHosting = false
    @Published private(set) var isConnected = false
    @Published private(set) var lastErrorMessage: String?

    private let sessionStateSubject = CurrentValueSubject<RemoteSessionState, Never>(RemoteSessionState())
    private let agentSnapshotSubject = CurrentValueSubject<RemoteAgentSnapshot?, Never>(nil)
    private let incomingCommandSubject = PassthroughSubject<DirectorCommand, Never>()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "callDP.remote.network")

    private var listener: NWListener?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var localRole: CallDPRole?
    private var localName: String?
    private var latestPublishedSnapshot: RemoteAgentSnapshot?

    var currentSessionState: RemoteSessionState { sessionState }
    var currentAgentSnapshot: RemoteAgentSnapshot? { agentSnapshot }
    var sessionStatePublisher: AnyPublisher<RemoteSessionState, Never> { sessionStateSubject.eraseToAnyPublisher() }
    var agentSnapshotPublisher: AnyPublisher<RemoteAgentSnapshot?, Never> { agentSnapshotSubject.eraseToAnyPublisher() }
    var incomingCommandPublisher: AnyPublisher<DirectorCommand, Never> { incomingCommandSubject.eraseToAnyPublisher() }

    func register(role: CallDPRole, name: String) {
        localRole = role
        localName = name

        var next = sessionState

        switch role {
        case .director:
            next.directorConnected = true
            next.directorName = name
        case .cameraAgent:
            next.agentConnected = true
            next.agentName = name
        }

        next.status = resolveRemoteSessionStatus(
            preserving: sessionState.status,
            directorConnected: next.directorConnected,
            agentConnected: next.agentConnected
        )
        commit(next)
        sendRegistrationIfPossible()
    }

    func acceptControl() {
        guard localRole == .cameraAgent else { return }
        guard sessionState.directorConnected, sessionState.agentConnected else { return }
        var next = sessionState
        next.status = .active
        commit(next)
        broadcastSessionState()
    }

    func pauseControl() {
        guard localRole == .cameraAgent else { return }
        guard sessionState.status == .active else { return }
        var next = sessionState
        next.status = .paused
        commit(next)
        broadcastSessionState()
    }

    func resumeControl() {
        guard localRole == .cameraAgent else { return }
        guard sessionState.directorConnected, sessionState.agentConnected else { return }
        guard sessionState.status == .paused else { return }
        var next = sessionState
        next.status = .active
        commit(next)
        broadcastSessionState()
    }

    func endSession(for role: CallDPRole) {
        switch role {
        case .director:
            cancelConnectionKeepingListener()
            clearPeerStateBecauseConnectionEnded()
        case .cameraAgent:
            guard localRole == .cameraAgent else { return }
            cancelConnectionKeepingListener()
            clearPeerStateBecauseConnectionEnded()
        }
    }

    func disconnect(role: CallDPRole) {
        guard role == localRole else { return }
        stopAllNetworking()
        localRole = nil
        localName = nil
        commit(RemoteSessionState())
        agentSnapshot = nil
        agentSnapshotSubject.send(nil)
        statusText = "Idle"
        peerText = "No peer"
        lastErrorMessage = nil
    }

    func send(_ command: DirectorCommand) {
        guard localRole == .director else { return }
        guard sessionState.status == .active else { return }
        sendEnvelope(.command(command))
    }

    func publishAgentSnapshot(_ snapshot: RemoteAgentSnapshot) {
        latestPublishedSnapshot = snapshot

        guard localRole == .cameraAgent else { return }
        guard isConnected else { return }
        sendEnvelope(.agentSnapshot(snapshot))
    }

    func startHosting(on port: UInt16) throws {
        stopAllNetworking()

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            lastErrorMessage = "Invalid port"
            statusText = "Invalid host port"
            return
        }
        let listener = try NWListener(using: .tcp, on: nwPort)
        self.listener = listener
        listenPort = port
        statusText = "Starting listener on \(port)"
        lastErrorMessage = nil

        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleListenerState(state, expected: listener)
            }
        }

        listener.newConnectionHandler = { [weak self] newConnection in
            Task { @MainActor in
                self?.acceptIncomingConnection(newConnection)
            }
        }

        listener.start(queue: queue)
    }

    func connect(to host: String, port: UInt16) {
        cancelConnectionKeepingListener()
        lastErrorMessage = nil
        statusText = "Connecting to \(host):\(port)"

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            lastErrorMessage = "Invalid port"
            statusText = "Invalid remote port"
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        self.connection = connection
        receiveBuffer = Data()
        startConnection(connection)
    }

    func stopNetworking() {
        stopAllNetworking()
        clearPeerStateBecauseConnectionEnded()
        statusText = "Idle"
    }

    private func handleListenerState(_ state: NWListener.State, expected listener: NWListener) {
        guard self.listener === listener else { return }

        switch state {
        case .ready:
            isHosting = true
            statusText = "Hosting on port \(listenPort ?? 0)"
        case .failed(let error):
            isHosting = false
            lastErrorMessage = error.localizedDescription
            statusText = "Listener failed"
            self.listener?.cancel()
            self.listener = nil
        case .cancelled:
            isHosting = false
            if statusText.hasPrefix("Hosting") {
                statusText = "Idle"
            }
        default:
            break
        }
    }

    private func acceptIncomingConnection(_ newConnection: NWConnection) {
        cancelConnectionKeepingListener()
        connection = newConnection
        receiveBuffer = Data()
        statusText = "Incoming connection"
        startConnection(newConnection)
    }

    private func startConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state, expected: connection)
            }
        }
        connection.start(queue: queue)
        receiveNextChunk(for: connection)
    }

    private func handleConnectionState(_ state: NWConnection.State, expected connection: NWConnection) {
        guard self.connection === connection else { return }

        switch state {
        case .ready:
            isConnected = true
            peerText = connection.endpoint.debugDescription
            statusText = localRole == .cameraAgent ? "Director connected" : "Connected to camera agent"
            sendRegistrationIfPossible()
            if localRole == .cameraAgent {
                broadcastSessionState()
                if let latestPublishedSnapshot {
                    sendEnvelope(.agentSnapshot(latestPublishedSnapshot))
                }
            }
        case .waiting(let error):
            statusText = "Waiting for network"
            lastErrorMessage = error.localizedDescription
        case .failed(let error):
            lastErrorMessage = error.localizedDescription
            statusText = "Connection failed"
            cancelConnectionKeepingListener()
            clearPeerStateBecauseConnectionEnded()
        case .cancelled:
            cancelConnectionKeepingListener()
            clearPeerStateBecauseConnectionEnded()
        default:
            break
        }
    }

    private func receiveNextChunk(for connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                guard self.connection === connection else { return }

                if let data, data.isEmpty == false {
                    self.receiveBuffer.append(data)
                    self.processReceiveBuffer()
                }

                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    self.statusText = "Receive failed"
                    self.cancelConnectionKeepingListener()
                    self.clearPeerStateBecauseConnectionEnded()
                    return
                }

                if isComplete {
                    self.cancelConnectionKeepingListener()
                    self.clearPeerStateBecauseConnectionEnded()
                    return
                }

                self.receiveNextChunk(for: connection)
            }
        }
    }

    private func processReceiveBuffer() {
        while let delimiterIndex = receiveBuffer.firstIndex(of: 0x0A) {
            let line = receiveBuffer.prefix(upTo: delimiterIndex)
            receiveBuffer.removeSubrange(...delimiterIndex)

            guard line.isEmpty == false else { continue }

            do {
                let envelope = try decoder.decode(RemoteEnvelope.self, from: Data(line))
                handle(envelope: envelope)
            } catch {
                lastErrorMessage = "Failed to decode remote message"
                statusText = "Protocol error"
            }
        }
    }

    private func handle(envelope: RemoteEnvelope) {
        switch envelope.kind {
        case .register:
            guard let payload = envelope.register else { return }
            handleRegistration(payload)

        case .sessionState:
            guard let state = envelope.sessionState else { return }
            commit(state)

        case .agentSnapshot:
            guard let snapshot = envelope.agentSnapshot else { return }
            agentSnapshot = snapshot
            agentSnapshotSubject.send(snapshot)

        case .command:
            guard localRole == .cameraAgent else { return }
            guard sessionState.status == .active else { return }
            guard let command = envelope.command else { return }
            incomingCommandSubject.send(command)
        }
    }

    private func handleRegistration(_ payload: RemoteRegisterPayload) {
        var next = sessionState

        switch payload.role {
        case .director:
            next.directorConnected = true
            next.directorName = payload.name
        case .cameraAgent:
            next.agentConnected = true
            next.agentName = payload.name
        }

        next.status = resolveRemoteSessionStatus(
            preserving: sessionState.status,
            directorConnected: next.directorConnected,
            agentConnected: next.agentConnected
        )
        commit(next)

        if localRole == .cameraAgent {
            broadcastSessionState()
            if let latestPublishedSnapshot {
                sendEnvelope(.agentSnapshot(latestPublishedSnapshot))
            }
        }
    }

    private func sendRegistrationIfPossible() {
        guard isConnected else { return }
        guard let localRole, let localName else { return }
        sendEnvelope(.register(RemoteRegisterPayload(role: localRole, name: localName)))
    }

    private func broadcastSessionState() {
        guard localRole == .cameraAgent else { return }
        guard isConnected else { return }
        sendEnvelope(.sessionState(sessionState))
    }

    private func sendEnvelope(_ envelope: RemoteEnvelope) {
        guard let connection else { return }

        do {
            var data = try encoder.encode(envelope)
            data.append(0x0A)

            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastErrorMessage = error.localizedDescription
                        self.statusText = "Send failed"
                    }
                }
            })
        } catch {
            lastErrorMessage = "Failed to encode remote message"
            statusText = "Protocol error"
        }
    }

    private func clearPeerStateBecauseConnectionEnded() {
        isConnected = false
        peerText = "No peer"
        agentSnapshot = nil
        agentSnapshotSubject.send(nil)

        guard let localRole else {
            commit(RemoteSessionState())
            return
        }

        var next = sessionState

        switch localRole {
        case .director:
            next.directorConnected = true
            next.directorName = localName
            next.agentConnected = false
            next.agentName = nil
        case .cameraAgent:
            next.agentConnected = true
            next.agentName = localName
            next.directorConnected = false
            next.directorName = nil
        }

        next.status = resolveRemoteSessionStatus(
            preserving: .idle,
            directorConnected: next.directorConnected,
            agentConnected: next.agentConnected
        )
        commit(next)

        if isHosting {
            statusText = "Hosting on port \(listenPort ?? 0)"
        } else if localRole == .director {
            statusText = "Disconnected"
        }
    }

    private func cancelConnectionKeepingListener() {
        connection?.cancel()
        connection = nil
        receiveBuffer = Data()
        isConnected = false
    }

    private func stopAllNetworking() {
        connection?.cancel()
        listener?.cancel()
        connection = nil
        listener = nil
        receiveBuffer = Data()
        isConnected = false
        isHosting = false
        listenPort = nil
    }

    private func commit(_ next: RemoteSessionState) {
        var next = next
        next.updatedAt = Date().timeIntervalSince1970
        sessionState = next
        sessionStateSubject.send(next)
    }
}
