import Foundation

enum BackendMode: String, CaseIterable, Identifiable {
    case mock
    case simulated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mock:
            return "Mock"
        case .simulated:
            return "Simulated"
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
        let transcriber = StubAudioTranscriber()
        let parser = HeuristicCommandParser()

        switch mode {
        case .mock:
            return AppEnvironment(
                audioTranscriber: transcriber,
                commandParser: parser,
                groundingEngine: StubGroundingEngine(),
                trackingEngine: StubTrackingEngine()
            )
        case .simulated:
            return AppEnvironment(
                audioTranscriber: transcriber,
                commandParser: parser,
                groundingEngine: SimulatedGroundingEngine(simulation: simulation),
                trackingEngine: SimulatedTrackingEngine(simulation: simulation)
            )
        }
    }
}
