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
    /// nonisolated — called from AVCaptureVideoDataOutputSampleBufferDelegate on a background thread.
    /// Outputs normalized Vision coords in raw sensor space (landscape for camera, display-space for video).
    /// Callers are responsible for remapping coords to their view coordinate space.
    nonisolated func process(sampleBuffer: CMSampleBuffer,
                             orientation: CGImagePropertyOrientation = .up) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try requestHandler.perform([request], on: pixelBuffer, orientation: orientation)
        } catch {
            // Failed to perform request — publish nil and return
            print("[Vision] perform error: \(error)")
            Task { @MainActor in
                self.detectedPose = nil
            }
            return
        }

        guard let observations = request.results, let observation = observations.first else {
            Task { @MainActor in
                self.detectedPose = nil
            }
            return
        }

        var joints: [String: CGPoint] = [:]

        for jointName in Self.jointsOfInterest {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > 0.2 else {
                continue
            }
            joints[jointName.rawValue.rawValue] = point.location
        }

        guard !joints.isEmpty else {
            Task { @MainActor in
                self.detectedPose = nil
            }
            return
        }

        let pose = DetectedPose(joints: joints)
        print("[Vision] detected \(joints.count) joints")

        Task { @MainActor in
            self.detectedPose = pose
        }
    }
}
