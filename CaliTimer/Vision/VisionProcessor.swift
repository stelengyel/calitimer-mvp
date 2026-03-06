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

/// CameraActor-isolated pose detection engine.
/// Creates a VNSequenceRequestHandler once per session (not per frame) to prevent jitter.
/// Publishes DetectedPose? to MainActor via nonisolated(unsafe) + Task { @MainActor in }.
@CameraActor
final class VisionProcessor: ObservableObject {

    // Created once, reused per-frame — prevents jitter and CPU waste.
    private let requestHandler = VNSequenceRequestHandler()

    // Published from CameraActor, read on MainActor.
    // nonisolated(unsafe) allows SwiftUI bindings to read without crossing actor.
    @Published nonisolated(unsafe) var detectedPose: DetectedPose? = nil

    // MARK: - Joints of Interest

    /// The 8 joints relevant to handstand detection. Others are ignored.
    private static let jointsOfInterest: [VNHumanBodyPoseObservation.JointName] = [
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
    /// Isolated to @CameraActor — called from AVCaptureVideoDataOutputSampleBufferDelegate.
    func process(sampleBuffer: CMSampleBuffer) {
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try requestHandler.perform([request], on: sampleBuffer)
        } catch {
            // Failed to perform request — publish nil and return
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
            joints[jointName.rawValue] = point.location
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
