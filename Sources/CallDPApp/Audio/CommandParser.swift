#if SWIFT_PACKAGE
import CallDPCore
#endif
import Foundation

@MainActor
protocol CommandParsing {
    func parse(transcript: TranscriptSegment) async throws -> DirectorCommand?
}

struct HeuristicCommandParser: CommandParsing {
    func parse(transcript: TranscriptSegment) async throws -> DirectorCommand? {
        let cleaned = transcript.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard cleaned.isEmpty == false else {
            return nil
        }

        if cleaned.hasPrefix("focus on ") {
            let target = String(cleaned.dropFirst("focus on ".count))
            return DirectorCommand.focus(
                on: target,
                candidateQueries: candidateQueries(for: target),
                source: .speech
            )
        }

        if cleaned.hasPrefix("track ") {
            let target = String(cleaned.dropFirst("track ".count))
            return DirectorCommand.focus(
                on: target,
                candidateQueries: candidateQueries(for: target),
                source: .speech
            )
        }

        if cleaned.contains("move left") {
            return DirectorCommand.pan(.left, source: .speech)
        }
        if cleaned.contains("move right") {
            return DirectorCommand.pan(.right, source: .speech)
        }
        if cleaned.contains("move up") {
            return DirectorCommand.pan(.up, source: .speech)
        }
        if cleaned.contains("move down") {
            return DirectorCommand.pan(.down, source: .speech)
        }
        if cleaned.contains("zoom in") {
            return DirectorCommand.zoom(.stepIn, source: .speech)
        }
        if cleaned.contains("zoom out") {
            return DirectorCommand.zoom(.stepOut, source: .speech)
        }
        if cleaned.contains("recenter") || cleaned == "center" {
            return DirectorCommand(intent: .recenter, source: .speech)
        }
        if cleaned.contains("stop tracking") || cleaned == "stop" {
            return DirectorCommand(intent: .stopTracking, source: .speech)
        }

        return nil
    }

    private func candidateQueries(for target: String) -> [String] {
        var queries = [target]

        if target.contains("vessel") || target.contains("cooking") {
            queries.append(contentsOf: ["pot", "pan", "saucepan", "kettle", "bowl"])
        }

        if target.contains("bowl") {
            queries.append(contentsOf: ["mixing bowl", "dish"])
        }

        return Array(NSOrderedSet(array: queries).compactMap { $0 as? String })
    }
}
