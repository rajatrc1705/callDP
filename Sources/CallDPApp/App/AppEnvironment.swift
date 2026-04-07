import Foundation

enum BackendMode: String, CaseIterable, Identifiable {
    case mock
    case simulated
    case apple
    case grounded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mock:
            return "Mock"
        case .simulated:
            return "Simulated"
        case .apple:
            return "Apple"
        case .grounded:
            return "Grounded"
        }
    }

    var supportsLiveSpeech: Bool {
        switch self {
        case .mock, .simulated:
            return false
        case .apple, .grounded:
            return true
        }
    }
}

@MainActor
struct AppEnvironment {
    let audioTranscriber: any AudioTranscribing
    let commandParser: any CommandParsing
    let groundingEngine: any GroundingEngine
    let trackingEngine: any TrackingEngine

    static func make(mode: BackendMode, simulation: SimulationController) -> AppEnvironment {
        let parser = HeuristicCommandParser()

        switch mode {
        case .mock:
            return AppEnvironment(
                audioTranscriber: StubAudioTranscriber(),
                commandParser: parser,
                groundingEngine: StubGroundingEngine(),
                trackingEngine: StubTrackingEngine()
            )
        case .simulated:
            return AppEnvironment(
                audioTranscriber: StubAudioTranscriber(),
                commandParser: parser,
                groundingEngine: SimulatedGroundingEngine(simulation: simulation),
                trackingEngine: SimulatedTrackingEngine(simulation: simulation)
            )
        case .apple:
            return AppEnvironment(
                audioTranscriber: AppleSpeechTranscriber(),
                commandParser: parser,
                groundingEngine: SimulatedGroundingEngine(simulation: simulation),
                trackingEngine: VisionTrackingEngine()
            )
        case .grounded:
            return AppEnvironment(
                audioTranscriber: AppleSpeechTranscriber(),
                commandParser: parser,
                groundingEngine: PythonGroundingEngine(),
                trackingEngine: VisionTrackingEngine()
            )
        }
    }
}
