import AVFoundation
import SwiftUI

/// Owns the AVCaptureSession for the app's lifetime.
/// Isolated entirely to CameraActor — AVCaptureSession is NOT Sendable
/// and must never cross actor boundaries to SwiftUI views.
@CameraActor
final class CameraManager: NSObject, ObservableObject {
    // MARK: - Session

    private let session = AVCaptureSession()
    private var currentInput: AVCaptureDeviceInput?

    // MARK: - Preview

    /// Initialized in init() before actor isolation matters.
    /// Pass this reference to CameraPreviewView — never pass the session itself.
    nonisolated let previewLayer: AVCaptureVideoPreviewLayer

    // MARK: - State (published to MainActor UI)

    /// True when camera permission was denied or restricted.
    @MainActor var permissionDenied: Bool = false

    // MARK: - Init

    override init() {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer
        super.init()
    }

    // MARK: - Session Lifecycle

    /// Call from LiveSessionView.task — hops to CameraActor automatically.
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
                await MainActor.run { permissionDenied = true }
            }
        case .denied, .restricted:
            await MainActor.run { permissionDenied = true }
        @unknown default:
            break
        }
    }

    /// Stop the session when the session screen is dismissed.
    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    // MARK: - Camera Flip

    /// Atomically swap front ↔ rear camera input.
    /// Uses beginConfiguration/commitConfiguration — required for atomic reconfiguration.
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
        } else {
            // Restore original on failure
            session.addInput(currentInput)
        }
        session.commitConfiguration()
    }

    // MARK: - Private

    private func configureAndStart() async {
        guard !session.isRunning else { return }

        // Configure session preset for 1080p — appropriate for handstand detection in Phase 4+
        // 4K omitted: thermal overhead not justified for Phase 2 preview-only
        session.sessionPreset = .hd1920x1080

        // Add rear camera input by default
        if currentInput == nil {
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device) {
                if session.canAddInput(input) {
                    session.addInput(input)
                    currentInput = input
                }
            }
        }

        // Connect session to preview layer
        previewLayer.session = session

        // startRunning() is blocking — safe here because we are on CameraActor (not MainActor)
        session.startRunning()
    }
}
