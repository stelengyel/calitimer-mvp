import Vision
import CoreMedia
import CoreGraphics
import Combine

// MARK: - DetectedPose

/// Sendable struct holding normalized joint positions from Vision.
/// Keys are VNHumanBodyPoseObservation.JointName raw values (Strings).
/// Values are normalized Vision CGPoints: (0,0) = bottom-left, (1,1) = top-right.
struct DetectedPose: Sendable {
    // Key: VNHumanBodyPoseObservation.JointName.rawValue (String)
    // Value: normalized Vision CGPoint (0,0 = bottom-left)
    let joints: [String: CGPoint]
}

// MARK: - VisionProcessor

/// MainActor-isolated pose detection engine.
/// Creates a VNSequenceRequestHandler once per session (not per frame) to prevent jitter.
/// Publishes DetectedPose? to MainActor via Task { @MainActor in }.
@MainActor
final class VisionProcessor: ObservableObject {

    // Created once, reused per-frame — prevents jitter and CPU waste.
    // nonisolated(unsafe) because VNSequenceRequestHandler is not Sendable;
    // safe here — only accessed from process() which is always called serially
    // on the AVCaptureVideoDataOutput queue or the upload periodic observer queue.
    nonisolated(unsafe) let requestHandler = VNSequenceRequestHandler()

    @Published var detectedPose: DetectedPose? = nil

    // MARK: - Joints of Interest

    /// The 8 joints relevant to handstand detection. Others are ignored.
    private nonisolated static let jointsOfInterest: [VNHumanBodyPoseObservation.JointName] = [
        .leftWrist,
        .rightWrist,
        .leftShoulder,
        .rightShoulder,
        .leftHip,
        .rightHip,
        .leftAnkle,
        .rightAnkle
    ]

    // MARK: - Processing

    /// Process a single camera frame for human body pose.
    /// nonisolated — called from AVCaptureVideoDataOutputSampleBufferDelegate on a background thread,
    /// or from AVAssetReaderScanner on a Task background thread.
    /// Returns the detected pose synchronously so callers that need it immediately (e.g. scanner)
    /// can use it without a MainActor round-trip. Also publishes to $detectedPose for UI subscribers.
    /// Outputs normalized Vision coords in raw sensor space (landscape for camera, display-space for video).
    /// Callers are responsible for remapping coords to their view coordinate space.
    @discardableResult
    nonisolated func process(sampleBuffer: CMSampleBuffer,
                             orientation: CGImagePropertyOrientation = .up) -> DetectedPose? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try requestHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch {
            print("[Vision] perform error: \(error)")
            Task { @MainActor in self.detectedPose = nil }
            return nil
        }

        guard let observations = request.results, let observation = observations.first else {
            Task { @MainActor in self.detectedPose = nil }
            return nil
        }

        var joints: [String: CGPoint] = [:]

        for jointName in Self.jointsOfInterest {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.1 else {
                continue
            }
            joints[jointName.rawValue.rawValue] = point.location
        }

        guard !joints.isEmpty else {
            Task { @MainActor in self.detectedPose = nil }
            return nil
        }

        let pose = DetectedPose(joints: joints)
        Task { @MainActor in self.detectedPose = pose }
        return pose
    }
}
