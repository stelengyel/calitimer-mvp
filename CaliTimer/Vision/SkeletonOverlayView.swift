import SwiftUI
import Vision

/// SwiftUI Canvas renderer for the skeleton overlay.
///
/// Renders 8 joints (wrists, shoulders, hips, ankles) and 8 bone connections
/// in brand ember color on a transparent background.
///
/// Coordinate transform: Vision normalized coords have (0,0) at bottom-left,
/// y increasing upward. SwiftUI Canvas has (0,0) at top-left, y increasing
/// downward. Flip applied: canvasY = (1.0 - normalizedY) * viewSize.height.
struct SkeletonOverlayView: View {

    /// Normalized Vision joint positions. Keys are VNHumanBodyPoseObservation.JointName raw values.
    /// Empty dict = no person detected, nothing is drawn.
    let joints: [String: CGPoint]

    /// Pixel size of the view being overlaid — used for coordinate conversion.
    let viewSize: CGSize

    // MARK: - Bone Connections

    /// 8 bone connections between the 8 tracked joints.
    private static let boneConnections: [(String, String)] = [
        (VNHumanBodyPoseObservation.JointName.leftWrist.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.leftShoulder.rawValue.rawValue),
        (VNHumanBodyPoseObservation.JointName.rightWrist.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.rightShoulder.rawValue.rawValue),
        (VNHumanBodyPoseObservation.JointName.leftShoulder.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.rightShoulder.rawValue.rawValue),   // shoulder crossbar
        (VNHumanBodyPoseObservation.JointName.leftShoulder.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.leftHip.rawValue.rawValue),
        (VNHumanBodyPoseObservation.JointName.rightShoulder.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.rightHip.rawValue.rawValue),
        (VNHumanBodyPoseObservation.JointName.leftHip.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.rightHip.rawValue.rawValue),         // hip crossbar
        (VNHumanBodyPoseObservation.JointName.leftHip.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.leftAnkle.rawValue.rawValue),
        (VNHumanBodyPoseObservation.JointName.rightHip.rawValue.rawValue,
         VNHumanBodyPoseObservation.JointName.rightAnkle.rawValue.rawValue)
    ]

    // MARK: - Style Constants

    private let boneLineWidth: CGFloat = 2
    private let boneOpacity: CGFloat = 0.85
    private let jointRadius: CGFloat = 4

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            guard !joints.isEmpty else { return }

            // Convert normalized Vision point to Canvas point.
            func canvasPoint(from normalized: CGPoint) -> CGPoint {
                CGPoint(
                    x: normalized.x * size.width,
                    y: (1.0 - normalized.y) * size.height
                )
            }

            // --- Draw bones first (behind joints) ---
            for (startKey, endKey) in Self.boneConnections {
                guard let startNorm = joints[startKey],
                      let endNorm = joints[endKey] else {
                    // Skip partial bones gracefully — one or both endpoints missing
                    continue
                }

                let start = canvasPoint(from: startNorm)
                let end = canvasPoint(from: endNorm)

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(Color.brandEmber.opacity(boneOpacity)),
                    lineWidth: boneLineWidth
                )
            }

            // --- Draw joint dots on top ---
            for (_, normalized) in joints {
                let center = canvasPoint(from: normalized)
                let rect = CGRect(
                    x: center.x - jointRadius,
                    y: center.y - jointRadius,
                    width: jointRadius * 2,
                    height: jointRadius * 2
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.brandEmber)
                )
            }
        }
        .frame(width: viewSize.width, height: viewSize.height)
        .allowsHitTesting(false)
    }
}
