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
    private static let wristKeys    = ["left_wrist_2_joint",    "right_wrist_2_joint"]
    private static let ankleKeys    = ["left_ankle_joint",      "right_ankle_joint"]
    private static let shoulderKeys = ["left_shoulder_1_joint", "right_shoulder_1_joint"]
    private static let hipKeys      = ["left_upLeg_joint",      "right_upLeg_joint"]

    /// Returns true when the pose represents a handstand (inverted).
    ///
    /// Primary check: wrist Y < ankle Y in Vision normalized space (0=bottom).
    /// Fallback: shoulder Y < hip Y — used when wrists/ankles are absent or low-confidence
    /// in an inverted pose, which is common because Vision is trained on upright people.
    ///
    /// Returns false for nil pose (no person detected).
    static func isHandstand(_ pose: DetectedPose?) -> Bool {
        guard let joints = pose?.joints else { return false }

        // Primary: wrist below ankle — lenient 1+1 minimum
        let wristY   = wristKeys.compactMap   { joints[$0]?.y }.min()
        let ankleY   = ankleKeys.compactMap   { joints[$0]?.y }.max()
        if let wy = wristY, let ay = ankleY {
            #if DEBUG
            debugLog("wristY=\(String(format:"%.3f",wy)) ankleY=\(String(format:"%.3f",ay)) → \(wy < ay ? "HANDSTAND" : "upright") [wrist/ankle]")
            #endif
            return wy < ay
        }

        // Fallback: shoulder below hip — used when wrist/ankle not detected
        // In a handstand: shoulders are near the floor (low Y), hips are high (high Y)
        let shoulderY = shoulderKeys.compactMap { joints[$0]?.y }.min()
        let hipY      = hipKeys.compactMap      { joints[$0]?.y }.max()
        guard let sy = shoulderY, let hy = hipY else {
            #if DEBUG
            debugLog("insufficient joints (wrist=\(wristY != nil), ankle=\(ankleY != nil), shoulder=\(shoulderY != nil), hip=\(hipY != nil))")
            #endif
            return false
        }
        #if DEBUG
        debugLog("shoulderY=\(String(format:"%.3f",sy)) hipY=\(String(format:"%.3f",hy)) → \(sy < hy ? "HANDSTAND" : "upright") [shoulder/hip fallback]")
        #endif
        return sy < hy
    }

    // Throttled debug log — prints at most once per second to avoid flooding console.
    nonisolated(unsafe) private static var lastLogTime: Date = .distantPast
    private static func debugLog(_ msg: String) {
        let now = Date()
        guard now.timeIntervalSince(lastLogTime) >= 1.0 else { return }
        lastLogTime = now
        print("[HandstandClassifier] \(msg)")
    }

    /// Debug helper — call from onReceive in LiveSessionView to confirm actual Vision key strings.
    /// Remove or guard behind #if DEBUG before shipping.
    static func debugPrintKeys(_ pose: DetectedPose?) {
        if let keys = pose?.joints.keys {
            print("[HandstandClassifier] joint keys: \(Array(keys).sorted())")
        }
    }
}
