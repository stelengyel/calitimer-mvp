@preconcurrency import AVFoundation
import SwiftUI

/// Owns the AVCaptureSession for the app's lifetime.
/// @MainActor isolation keeps all UI-facing state on the main actor, matching SwiftUI.
/// AVFoundation session operations that block (startRunning, stopRunning) are dispatched
/// to a background serial queue to avoid blocking the main thread.
/// Note: @CameraActor is reserved for Phase 4 Vision frame processing (VisionProcessor).
@MainActor
final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: - Private serial queue for blocking AVFoundation ops

    private static let queue = DispatchQueue(label: "com.calitimer.camera", qos: .userInitiated)

    // MARK: - Video output queue (separate from camera queue to avoid blocking)

    private static let videoOutputQueue = DispatchQueue(label: "com.calitimer.videoOutput", qos: .userInitiated)

    // MARK: - Session (nonisolated(unsafe) — only touched on queue or during config from MainActor)

    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private var currentInput: AVCaptureDeviceInput?

    // MARK: - Video output (nonisolated(unsafe) — configured on MainActor, read on videoOutputQueue)

    nonisolated(unsafe) private var videoOutput: AVCaptureVideoDataOutput?

    // MARK: - Vision processor

    /// Pose detection engine. Created once; accessible from LiveSessionView via cameraManager.visionProcessor.
    let visionProcessor = VisionProcessor()

    // MARK: - Preview

    /// Live camera preview layer. @MainActor-owned; safe to access in SwiftUI body.
    let previewLayer: AVCaptureVideoPreviewLayer

    // MARK: - State

    /// True when camera permission was denied or restricted.
    @Published var permissionDenied: Bool = false

    /// Current active camera position — used by LiveSessionView to derive Vision orientation.
    @Published var cameraPosition: AVCaptureDevice.Position = .back

    // MARK: - Init

    override init() {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer
        super.init()
    }

    // MARK: - Session Lifecycle

    func startSession() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await configureAndStart()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await configureAndStart()
            } else {
                permissionDenied = true
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            break
        }
    }

    /// Stop the session when the session screen is dismissed.
    func stopSession() {
        let s = session
        Self.queue.async { s.stopRunning() }
    }

    // MARK: - Camera Flip

    /// Atomically swap front ↔ rear camera input.
    func flipCamera() {
        guard let currentInput else { return }
        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            self.currentInput = newInput
            self.cameraPosition = newPosition
        } else {
            session.addInput(currentInput)
        }
        session.commitConfiguration()
    }

    // MARK: - Private

    private func configureAndStart() async {
        guard !session.isRunning else { return }

        session.sessionPreset = .hd1920x1080

        if currentInput == nil {
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device) {
                if session.canAddInput(input) {
                    session.addInput(input)
                    currentInput = input
                    cameraPosition = .back
                }
            }
        }

        // Connect session to preview layer on MainActor before starting
        previewLayer.session = session

        // Add video data output for Vision frame processing
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        // Delegate is nonisolated — CameraManager is @unchecked Sendable, safe
        output.setSampleBufferDelegate(self, queue: Self.videoOutputQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
            self.videoOutput = output
        }

        // startRunning() blocks — dispatch off main thread
        let s = session
        await withCheckedContinuation { continuation in
            Self.queue.async {
                s.startRunning()
                continuation.resume()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called on videoOutputQueue by AVFoundation. Must be nonisolated — not on MainActor.
    /// VisionProcessor.process() is nonisolated, so it can be called directly from here.
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        // App is portrait-only. Both sensors deliver landscape frames needing 90° CW
        // rotation to display as portrait → .right. layerPointConverted handles the
        // front camera's horizontal mirror on the display side automatically.
        let orientation: CGImagePropertyOrientation = .right
        visionProcessor.process(sampleBuffer: sampleBuffer, orientation: orientation)
    }
}
