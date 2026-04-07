import AVFoundation
import Foundation
import Speech

enum AppleSpeechTranscriberError: LocalizedError {
    case speechAuthorizationDenied
    case microphoneAuthorizationDenied
    case recognizerUnavailable
    case unsupportedLocale
    case inputUnavailable

    var errorDescription: String? {
        switch self {
        case .speechAuthorizationDenied:
            return "Speech recognition permission was denied."
        case .microphoneAuthorizationDenied:
            return "Microphone permission was denied."
        case .recognizerUnavailable:
            return "Speech recognition is currently unavailable for the selected locale."
        case .unsupportedLocale:
            return "The current locale is not supported by Apple speech recognition."
        case .inputUnavailable:
            return "No microphone input is available for live transcription."
        }
    }
}

final class AppleSpeechTranscriber: NSObject, AudioTranscribing, @unchecked Sendable {
    var onTranscript: ((TranscriptSegment) -> Void)?
    var onStateChange: ((AudioInputState) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?
    private let requestBridge = SpeechRequestBridge()
    private var audioRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isRunning = false
    private var hasInstalledTap = false

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale)
        super.init()
    }

    func start() async throws {
        guard isRunning == false else { return }
        emitState(.starting)

        do {
            try await ensureSpeechAuthorization()
            try await ensureMicrophoneAuthorization()

            guard let recognizer else {
                throw AppleSpeechTranscriberError.unsupportedLocale
            }

            guard recognizer.isAvailable else {
                throw AppleSpeechTranscriberError.recognizerUnavailable
            }

            try installAudioTapIfNeeded()
            startRecognitionTask(using: recognizer)

            if audioEngine.isRunning == false {
                audioEngine.prepare()
                try audioEngine.start()
            }

            isRunning = true
            emitState(.listening)
        } catch {
            emitState(.error(error.localizedDescription))
            throw error
        }
    }

    func stop() async {
        isRunning = false

        recognitionTask?.cancel()
        recognitionTask = nil

        audioRequest?.endAudio()
        audioRequest = nil
        requestBridge.setRequest(nil)

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }

        emitState(.stopped)
    }

    private func ensureSpeechAuthorization() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }

            guard status == .authorized else {
                throw AppleSpeechTranscriberError.speechAuthorizationDenied
            }
        case .denied, .restricted:
            throw AppleSpeechTranscriberError.speechAuthorizationDenied
        @unknown default:
            throw AppleSpeechTranscriberError.speechAuthorizationDenied
        }
    }

    private func ensureMicrophoneAuthorization() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else {
                throw AppleSpeechTranscriberError.microphoneAuthorizationDenied
            }
        case .denied, .restricted:
            throw AppleSpeechTranscriberError.microphoneAuthorizationDenied
        @unknown default:
            throw AppleSpeechTranscriberError.microphoneAuthorizationDenied
        }
    }

    private func installAudioTapIfNeeded() throws {
        guard hasInstalledTap == false else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw AppleSpeechTranscriberError.inputUnavailable
        }

        inputNode.removeTap(onBus: 0)
        let requestBridge = requestBridge
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            requestBridge.append(buffer)
        }
        hasInstalledTap = true
    }

    private func startRecognitionTask(using recognizer: SFSpeechRecognizer) {
        recognitionTask?.cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        audioRequest = request
        requestBridge.setRequest(request)
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.scheduleRecognitionResultHandling(result, error: error)
        }
    }

    private func scheduleRecognitionResultHandling(
        _ result: SFSpeechRecognitionResult?,
        error: Error?
    ) {
        let transcriptText = result?.bestTranscription.formattedString
        let isFinal = result?.isFinal ?? false
        let didError = error != nil

        DispatchQueue.main.async { [weak self] in
            self?.handleRecognitionResult(
                transcriptText: transcriptText,
                isFinal: isFinal,
                didError: didError
            )
        }
    }

    private func handleRecognitionResult(
        transcriptText: String?,
        isFinal: Bool,
        didError: Bool
    ) {
        if let transcriptText {
            onTranscript?(
                TranscriptSegment(
                    text: transcriptText,
                    isFinal: isFinal,
                    timestamp: Date().timeIntervalSince1970
                )
            )
        }

        let shouldRestart = isRunning && (isFinal || didError)
        guard shouldRestart else { return }

        recognitionTask?.cancel()
        recognitionTask = nil
        audioRequest?.endAudio()
        audioRequest = nil
        requestBridge.setRequest(nil)

        if didError {
            emitState(.starting)
        }

        if recognizer?.isAvailable == true, let recognizer {
            startRecognitionTask(using: recognizer)
            emitState(.listening)
        } else if didError {
            emitState(.error(AppleSpeechTranscriberError.recognizerUnavailable.localizedDescription))
        }
    }

    private func emitState(_ state: AudioInputState) {
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(state)
        }
    }
}

private final class SpeechRequestBridge {
    private let lock = NSLock()
    private weak var request: SFSpeechAudioBufferRecognitionRequest?

    func setRequest(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = request
        lock.unlock()
        request?.append(buffer)
    }
}
