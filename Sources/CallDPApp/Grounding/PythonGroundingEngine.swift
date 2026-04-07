import CoreGraphics
import CoreImage
import Foundation
import ImageIO
#if SWIFT_PACKAGE
import CallDPCore
#endif

@MainActor
final class PythonGroundingEngine: GroundingEngine {
    private let configuration: GroundingWorkerConfiguration
    private let ciContext = CIContext()

    init() {
        configuration = GroundingWorkerConfiguration.live()
    }

    func detect(in frame: CameraFrame, request: GroundingRequest) async throws -> [DetectionCandidate] {
        let encodedFrame = try encode(frame: frame)
        let queries = request.candidateQueries.isEmpty ? [request.targetDescription] : request.candidateQueries
        let workerRequest = GroundingWorkerRequest(
            requestID: UUID().uuidString,
            targetDescription: request.targetDescription,
            candidateQueries: queries,
            scoreThreshold: configuration.scoreThreshold,
            topK: configuration.topK,
            frame: encodedFrame
        )
        let timestamp = frame.timestamp
        let configuration = configuration

        return try await Task.detached(priority: .userInitiated) {
            let response = try GroundingWorkerRunner.run(request: workerRequest, configuration: configuration)
            let payloads = response.detections ?? []

            return payloads.map {
                DetectionCandidate(
                    query: $0.query,
                    boundingBox: $0.boundingBox.clampedToUnitSpace(),
                    confidence: $0.confidence,
                    label: $0.label,
                    timestamp: timestamp
                )
            }
        }.value
    }

    private func encode(frame: CameraFrame) throws -> GroundingWorkerImagePayload {
        let maxInputDimension = configuration.maxInputDimension
        let longestEdge = max(frame.size.width, frame.size.height)
        let scaledImage: CIImage

        if longestEdge > maxInputDimension {
            let scale = maxInputDimension / longestEdge
            scaledImage = frame.image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        } else {
            scaledImage = frame.image
        }

        let extent = scaledImage.extent.integral
        guard extent.isEmpty == false else {
            throw GroundingEngineError.imageEncodingFailed("frame image had an empty extent")
        }

        let options: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: configuration.jpegQuality,
        ]

        guard
            let jpegData = ciContext.jpegRepresentation(
                of: scaledImage,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                options: options
            )
        else {
            throw GroundingEngineError.imageEncodingFailed("failed to build JPEG payload")
        }

        return GroundingWorkerImagePayload(
            jpegBase64: jpegData.base64EncodedString(),
            width: Int(extent.width.rounded()),
            height: Int(extent.height.rounded())
        )
    }
}

private struct GroundingWorkerConfiguration: Sendable {
    let pythonCommand: String
    let scriptURL: URL
    let modelID: String
    let scoreThreshold: Double
    let topK: Int
    let maxInputDimension: Double
    let jpegQuality: Double

    static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> GroundingWorkerConfiguration {
        let locator = GroundingRuntimeLocator(environment: environment)
        return GroundingWorkerConfiguration(
            pythonCommand: locator.pythonCommand(),
            scriptURL: locator.workerScriptURL(),
            modelID: environment["CALLDP_GROUNDING_MODEL"] ?? "google/owlv2-base-patch16-ensemble",
            scoreThreshold: Double(environment["CALLDP_GROUNDING_SCORE_THRESHOLD"] ?? "") ?? 0.12,
            topK: Int(environment["CALLDP_GROUNDING_TOP_K"] ?? "") ?? 3,
            maxInputDimension: Double(environment["CALLDP_GROUNDING_MAX_DIMENSION"] ?? "") ?? 960,
            jpegQuality: Double(environment["CALLDP_GROUNDING_JPEG_QUALITY"] ?? "") ?? 0.82
        )
    }
}

private struct GroundingRuntimeLocator {
    let environment: [String: String]

    func pythonCommand() -> String {
        if let explicitPath = environment["CALLDP_GROUNDING_PYTHON"], explicitPath.isEmpty == false {
            return explicitPath
        }

        let venvPython = repositoryRoot().appendingPathComponent(".venv/bin/python3")
        if FileManager.default.fileExists(atPath: venvPython.path) {
            return venvPython.path
        }

        return "python3"
    }

    func workerScriptURL() -> URL {
        if let explicitPath = environment["CALLDP_GROUNDING_WORKER_PATH"], explicitPath.isEmpty == false {
            return URL(fileURLWithPath: explicitPath)
        }

        return repositoryRoot().appendingPathComponent("Scripts/grounding_worker.py")
    }

    private func repositoryRoot() -> URL {
        let fileURL = URL(fileURLWithPath: #filePath)
        var candidate = fileURL.deletingLastPathComponent()

        for _ in 0..<8 {
            let packageURL = candidate.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageURL.path) {
                return candidate
            }

            candidate.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

private enum GroundingEngineError: LocalizedError {
    case workerScriptMissing(String)
    case workerLaunchFailed(String)
    case workerReturnedError(String)
    case workerExited(code: Int32, details: String)
    case invalidWorkerResponse(String)
    case imageEncodingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .workerScriptMissing(path):
            return "Grounding worker script not found at \(path)."
        case let .workerLaunchFailed(message):
            return "Failed to start the grounding worker: \(message)"
        case let .workerReturnedError(message):
            return "Grounding worker failed: \(message)"
        case let .workerExited(code, details):
            if details.isEmpty {
                return "Grounding worker exited unexpectedly with code \(code)."
            }
            return "Grounding worker exited unexpectedly with code \(code): \(details)"
        case let .invalidWorkerResponse(payload):
            return "Grounding worker returned invalid JSON: \(payload)"
        case let .imageEncodingFailed(reason):
            return "Failed to encode the camera frame for grounding: \(reason)"
        }
    }
}

private struct GroundingWorkerRequest: Encodable, Sendable {
    let type = "detect"
    let requestID: String
    let targetDescription: String
    let candidateQueries: [String]
    let scoreThreshold: Double
    let topK: Int
    let frame: GroundingWorkerImagePayload

    enum CodingKeys: String, CodingKey {
        case type
        case requestID = "request_id"
        case targetDescription = "target_description"
        case candidateQueries = "candidate_queries"
        case scoreThreshold = "score_threshold"
        case topK = "top_k"
        case frame
    }
}

private struct GroundingWorkerImagePayload: Encodable, Sendable {
    let jpegBase64: String
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case jpegBase64 = "jpeg_base64"
        case width
        case height
    }
}

private struct GroundingWorkerEnvelope: Decodable, Sendable {
    let type: String
    let requestID: String?
    let message: String?
    let detections: [GroundingWorkerDetectionPayload]?

    enum CodingKeys: String, CodingKey {
        case type
        case requestID = "request_id"
        case message
        case detections
    }
}

private struct GroundingWorkerDetectionPayload: Decodable, Sendable {
    let query: String
    let label: String
    let confidence: Double
    let bbox: [Double]

    var boundingBox: NormalizedRect {
        guard bbox.count == 4 else {
            return .unit
        }

        return NormalizedRect(x: bbox[0], y: bbox[1], width: bbox[2], height: bbox[3])
    }
}

private enum GroundingWorkerRunner {
    static func run(
        request: GroundingWorkerRequest,
        configuration: GroundingWorkerConfiguration
    ) throws -> GroundingWorkerEnvelope {
        guard FileManager.default.fileExists(atPath: configuration.scriptURL.path) else {
            throw GroundingEngineError.workerScriptMissing(configuration.scriptURL.path)
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            configuration.pythonCommand,
            configuration.scriptURL.path,
            "--model",
            configuration.modelID,
            "--threshold",
            String(configuration.scoreThreshold),
            "--top-k",
            String(configuration.topK),
        ]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw GroundingEngineError.workerLaunchFailed(error.localizedDescription)
        }

        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request) + Data([0x0A])
        try inputPipe.fileHandleForWriting.write(contentsOf: requestData)
        try inputPipe.fileHandleForWriting.close()

        let stdout = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stderrText = String(data: stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw GroundingEngineError.workerExited(code: process.terminationStatus, details: stderrText)
        }

        let lines = stdout
            .split(separator: UInt8(ascii: "\n"))
            .compactMap { String(data: $0, encoding: .utf8) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        let decoder = JSONDecoder()
        var resultEnvelope: GroundingWorkerEnvelope?

        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }
            let envelope = try decoder.decode(GroundingWorkerEnvelope.self, from: data)

            if envelope.type == "result" || envelope.type == "error" {
                resultEnvelope = envelope
            }
        }

        guard let resultEnvelope else {
            throw GroundingEngineError.invalidWorkerResponse(String(data: stdout, encoding: .utf8) ?? "")
        }

        if resultEnvelope.type == "error" {
            throw GroundingEngineError.workerReturnedError(resultEnvelope.message ?? "unknown worker error")
        }

        return resultEnvelope
    }
}
