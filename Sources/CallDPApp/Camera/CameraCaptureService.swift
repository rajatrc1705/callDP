import AVFoundation
import Combine
import CoreImage
import Foundation

@MainActor
final class CameraCaptureService: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning = false
    @Published var errorMessage: String?

    var onFrame: ((CameraFrame) -> Void)?

    private let outputQueue = DispatchQueue(label: "callDP.camera.frames")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var didConfigure = false

    func start() {
        Task {
            let granted = await ensureCameraAccess()
            guard granted else { return }

            configureIfNeeded()
            guard session.isRunning == false else { return }

            session.startRunning()
            isRunning = session.isRunning
        }
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
        isRunning = false
    }

    private func ensureCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            if granted == false {
                errorMessage = "Camera access was denied."
            }
            return granted
        case .denied, .restricted:
            errorMessage = "Camera access is unavailable for this app."
            return false
        @unknown default:
            errorMessage = "Unknown camera permission state."
            return false
        }
    }

    private func configureIfNeeded() {
        guard didConfigure == false else { return }
        didConfigure = true

        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
            errorMessage = "No built-in camera was found."
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            errorMessage = "Failed to create camera input: \(error.localizedDescription)"
            return
        }

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            errorMessage = "Failed to add camera output."
        }
    }
}

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let frame = CameraFrame(
            image: image,
            size: CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)),
            timestamp: timestamp
        )

        Task { @MainActor [weak self] in
            self?.onFrame?(frame)
        }
    }
}
