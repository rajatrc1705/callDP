import Foundation

public enum DirectorIntent: String, Codable, Sendable, CaseIterable {
    case focusObject = "focus_object"
    case moveFrame = "move_frame"
    case zoom
    case recenter
    case stopTracking = "stop_tracking"
    case selectCandidate = "select_candidate"
    case lockCurrentTarget = "lock_current_target"
}

public enum CommandSource: String, Codable, Sendable {
    case speech
    case simulation
    case keyboard
    case system
}

public enum PanDirection: String, Codable, Sendable, CaseIterable {
    case left
    case right
    case up
    case down
}

public enum FrameAnchor: String, Codable, Sendable, CaseIterable {
    case center
    case leftThird = "left_third"
    case rightThird = "right_third"
    case upperHalf = "upper_half"
    case lowerHalf = "lower_half"
}

public enum ZoomMode: String, Codable, Sendable, CaseIterable {
    case automatic = "auto"
    case stepIn = "in"
    case stepOut = "out"
    case absolute
    case none
}

public struct DirectorCommand: Identifiable, Sendable, Codable, Hashable {
    public var id: UUID
    public var intent: DirectorIntent
    public var targetDescription: String?
    public var candidateQueries: [String]
    public var direction: PanDirection?
    public var amount: Double
    public var frameAnchor: FrameAnchor
    public var zoomMode: ZoomMode
    public var zoomValue: Double?
    public var tracking: Bool
    public var selectedCandidateIndex: Int?
    public var transcript: String?
    public var source: CommandSource

    public init(
        id: UUID = UUID(),
        intent: DirectorIntent,
        targetDescription: String? = nil,
        candidateQueries: [String] = [],
        direction: PanDirection? = nil,
        amount: Double = 1,
        frameAnchor: FrameAnchor = .center,
        zoomMode: ZoomMode = .none,
        zoomValue: Double? = nil,
        tracking: Bool = true,
        selectedCandidateIndex: Int? = nil,
        transcript: String? = nil,
        source: CommandSource = .system
    ) {
        self.id = id
        self.intent = intent
        self.targetDescription = targetDescription
        self.candidateQueries = candidateQueries
        self.direction = direction
        self.amount = amount
        self.frameAnchor = frameAnchor
        self.zoomMode = zoomMode
        self.zoomValue = zoomValue
        self.tracking = tracking
        self.selectedCandidateIndex = selectedCandidateIndex
        self.transcript = transcript
        self.source = source
    }
}

public extension DirectorCommand {
    static func focus(
        on targetDescription: String,
        candidateQueries: [String],
        source: CommandSource = .simulation
    ) -> DirectorCommand {
        DirectorCommand(
            intent: .focusObject,
            targetDescription: targetDescription,
            candidateQueries: candidateQueries,
            frameAnchor: .center,
            zoomMode: .automatic,
            tracking: true,
            transcript: targetDescription,
            source: source
        )
    }

    static func pan(
        _ direction: PanDirection,
        amount: Double = 1,
        source: CommandSource = .simulation
    ) -> DirectorCommand {
        DirectorCommand(
            intent: .moveFrame,
            direction: direction,
            amount: amount,
            source: source
        )
    }

    static func zoom(
        _ mode: ZoomMode,
        amount: Double = 1,
        zoomValue: Double? = nil,
        source: CommandSource = .simulation
    ) -> DirectorCommand {
        DirectorCommand(
            intent: .zoom,
            amount: amount,
            zoomMode: mode,
            zoomValue: zoomValue,
            source: source
        )
    }
}
