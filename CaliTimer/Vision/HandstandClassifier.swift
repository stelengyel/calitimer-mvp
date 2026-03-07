import Foundation

/// Pure handstand detection classifier. No state, no side effects.
/// Per user decision: minimum 1 wrist + 1 ankle, lenient for side-on camera angles.
/// Stricter 4-joint requirement explicitly rejected — see CONTEXT.md.
/// Threshold is flagged as tunable: adjust wristKeys/ankleKeys if false positives emerge.
enum HandstandClassifier {

    // Vision normalized space: (0,0)=bottom-left, (1,1)=top-right.
    // In a handstand, wrists are near the floor (low Y) and ankles near top (high Y).
    // Therefore: wristY < ankleY encodes inversion.

    // EMPIRICALLY DETERMINED: verify by running debugPrintKeys() against live camera.
    // These are VNHumanBodyPoseObservation.JointName.rawValue.rawValue strings.
    private static let wristKeys = ["left_wrist_2_joint", "right_wrist_2_joint"]
    private static let ankleKeys = ["left_ankle_joint", "right_ankle_joint"]

    /// Returns true when the pose represents a handstand (inverted: wrist Y < ankle Y).
    /// Returns false for nil pose (no person detected).
    static func isHandstand(_ pose: DetectedPose?) -> Bool {
        guard let joints = pose?.joints else { return false }
        // Take the minimum wrist Y and maximum ankle Y for the lenient 1+1 check.
        // Requires at least one wrist key AND at least one ankle key to be present.
        let wristY = wristKeys.compactMap { joints[$0]?.y }.min()
        let ankleY = ankleKeys.compactMap { joints[$0]?.y }.max()
        guard let wy = wristY, let ay = ankleY else { return false }
        return wy < ay
    }

    /// Debug helper — call from onReceive in LiveSessionView to confirm actual Vision key strings.
    /// Remove or guard behind #if DEBUG before shipping.
    static func debugPrintKeys(_ pose: DetectedPose?) {
        if let keys = pose?.joints.keys {
            print("[HandstandClassifier] joint keys: \(Array(keys).sorted())")
        }
    }
}
