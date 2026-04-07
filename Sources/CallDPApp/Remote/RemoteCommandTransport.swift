#if SWIFT_PACKAGE
import CallDPCore
#endif
import Combine
import Foundation

@MainActor
protocol RemoteCommandTransport: AnyObject {
    var currentSessionState: RemoteSessionState { get }
    var currentAgentSnapshot: RemoteAgentSnapshot? { get }
    var sessionStatePublisher: AnyPublisher<RemoteSessionState, Never> { get }
    var agentSnapshotPublisher: AnyPublisher<RemoteAgentSnapshot?, Never> { get }
    var incomingCommandPublisher: AnyPublisher<DirectorCommand, Never> { get }

    func register(role: CallDPRole, name: String)
    func acceptControl()
    func pauseControl()
    func resumeControl()
    func endSession(for role: CallDPRole)
    func disconnect(role: CallDPRole)
    func send(_ command: DirectorCommand)
    func publishAgentSnapshot(_ snapshot: RemoteAgentSnapshot)
}

@MainActor
final class LoopbackRemoteCommandTransport: ObservableObject, RemoteCommandTransport {
    @Published private(set) var sessionState = RemoteSessionState()
    @Published private(set) var agentSnapshot: RemoteAgentSnapshot?

    private let sessionStateSubject = CurrentValueSubject<RemoteSessionState, Never>(RemoteSessionState())
    private let agentSnapshotSubject = CurrentValueSubject<RemoteAgentSnapshot?, Never>(nil)
    private let incomingCommandSubject = PassthroughSubject<DirectorCommand, Never>()

    var currentSessionState: RemoteSessionState { sessionState }
    var currentAgentSnapshot: RemoteAgentSnapshot? { agentSnapshot }
    var sessionStatePublisher: AnyPublisher<RemoteSessionState, Never> { sessionStateSubject.eraseToAnyPublisher() }
    var agentSnapshotPublisher: AnyPublisher<RemoteAgentSnapshot?, Never> { agentSnapshotSubject.eraseToAnyPublisher() }
    var incomingCommandPublisher: AnyPublisher<DirectorCommand, Never> { incomingCommandSubject.eraseToAnyPublisher() }

    func register(role: CallDPRole, name: String) {
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
    }

    func acceptControl() {
        guard sessionState.directorConnected, sessionState.agentConnected else { return }
        var next = sessionState
        next.status = .active
        commit(next)
    }

    func pauseControl() {
        guard sessionState.status == .active else { return }
        var next = sessionState
        next.status = .paused
        commit(next)
    }

    func resumeControl() {
        guard sessionState.directorConnected, sessionState.agentConnected else { return }
        guard sessionState.status == .paused else { return }
        var next = sessionState
        next.status = .active
        commit(next)
    }

    func disconnect(role: CallDPRole) {
        var next = sessionState

        switch role {
        case .director:
            next.directorConnected = false
            next.directorName = nil
        case .cameraAgent:
            next.agentConnected = false
            next.agentName = nil
            agentSnapshot = nil
            agentSnapshotSubject.send(nil)
        }

        next.status = resolveRemoteSessionStatus(
            preserving: .idle,
            directorConnected: next.directorConnected,
            agentConnected: next.agentConnected
        )
        commit(next)
    }

    func endSession(for role: CallDPRole) {
        var next = sessionState

        switch role {
        case .director:
            next.agentConnected = false
            next.agentName = nil
            agentSnapshot = nil
            agentSnapshotSubject.send(nil)
        case .cameraAgent:
            next.directorConnected = false
            next.directorName = nil
        }

        next.status = resolveRemoteSessionStatus(
            preserving: .idle,
            directorConnected: next.directorConnected,
            agentConnected: next.agentConnected
        )
        commit(next)
    }

    func send(_ command: DirectorCommand) {
        guard sessionState.status == .active else { return }
        incomingCommandSubject.send(command)
    }

    func publishAgentSnapshot(_ snapshot: RemoteAgentSnapshot) {
        guard sessionState.agentConnected else { return }
        agentSnapshot = snapshot
        agentSnapshotSubject.send(snapshot)
    }

    private func commit(_ next: RemoteSessionState) {
        var next = next
        next.updatedAt = Date().timeIntervalSince1970
        sessionState = next
        sessionStateSubject.send(next)
    }
}

func resolveRemoteSessionStatus(
    preserving previous: RemoteSessionStatus,
    directorConnected: Bool,
    agentConnected: Bool
) -> RemoteSessionStatus {
    switch (directorConnected, agentConnected) {
    case (false, false):
        return .idle
    case (true, false), (false, true):
        return .waitingForPeer
    case (true, true):
        if previous == .active || previous == .paused {
            return previous
        }
        return .pendingConsent
    }
}
