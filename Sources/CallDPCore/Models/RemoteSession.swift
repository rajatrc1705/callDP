import Foundation

public enum CallDPRole: String, Codable, Sendable, CaseIterable, Identifiable {
    case director
    case cameraAgent = "camera_agent"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .director:
            return "Director"
        case .cameraAgent:
            return "Camera Agent"
        }
    }
}

public enum RemoteSessionStatus: String, Codable, Sendable, CaseIterable {
    case idle
    case waitingForPeer = "waiting_for_peer"
    case pendingConsent = "pending_consent"
    case active
    case paused

    public var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .waitingForPeer:
            return "Waiting For Peer"
        case .pendingConsent:
            return "Pending Consent"
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        }
    }
}

public struct VideoFrameSize: Sendable, Codable, Hashable {
    public var width: Int
    public var height: Int

    public init(width: Int = 0, height: Int = 0) {
        self.width = width
        self.height = height
    }

    public static let zero = VideoFrameSize()
}

public struct RemoteAgentSnapshot: Sendable, Codable, Hashable {
    public var sessionState: DirectorSessionState
    public var latestTranscript: String
    public var lastCommandSummary: String
    public var groundingStatusSummary: String
    public var recentLogs: [String]
    public var sourceFrameSize: VideoFrameSize
    public var backendLabel: String

    public init(
        sessionState: DirectorSessionState,
        latestTranscript: String,
        lastCommandSummary: String,
        groundingStatusSummary: String,
        recentLogs: [String],
        sourceFrameSize: VideoFrameSize,
        backendLabel: String
    ) {
        self.sessionState = sessionState
        self.latestTranscript = latestTranscript
        self.lastCommandSummary = lastCommandSummary
        self.groundingStatusSummary = groundingStatusSummary
        self.recentLogs = recentLogs
        self.sourceFrameSize = sourceFrameSize
        self.backendLabel = backendLabel
    }
}

public struct RemoteSessionState: Sendable, Codable, Hashable {
    public var status: RemoteSessionStatus
    public var directorConnected: Bool
    public var agentConnected: Bool
    public var directorName: String?
    public var agentName: String?
    public var updatedAt: TimeInterval

    public init(
        status: RemoteSessionStatus = .idle,
        directorConnected: Bool = false,
        agentConnected: Bool = false,
        directorName: String? = nil,
        agentName: String? = nil,
        updatedAt: TimeInterval = 0
    ) {
        self.status = status
        self.directorConnected = directorConnected
        self.agentConnected = agentConnected
        self.directorName = directorName
        self.agentName = agentName
        self.updatedAt = updatedAt
    }

    public var controlEnabled: Bool {
        status == .active
    }

    public var statusSummary: String {
        switch status {
        case .idle:
            return "No peers connected"
        case .waitingForPeer:
            if directorConnected {
                return "Waiting for camera agent"
            }

            if agentConnected {
                return "Waiting for director"
            }

            return "Waiting for peer"
        case .pendingConsent:
            return "Camera agent must accept control"
        case .active:
            return "Remote direction is active"
        case .paused:
            return "Remote direction is paused"
        }
    }
}
