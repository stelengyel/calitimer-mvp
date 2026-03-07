import SwiftUI

struct UploadModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = VideoImportManager()
    @StateObject private var skeletonPref = SkeletonPreference()
    @State private var showPicker = false
    @State private var detectedJoints: [String: CGPoint] = [:]
    @State private var overlaySize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = manager.player {
                ZStack {
                    VideoPlayerView(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Skeleton overlay on top of video — same pattern as LiveSessionView.
                    // Controlled by the same SkeletonPreference toggle.
                    if skeletonPref.isEnabled {
                        GeometryReader { geo in
                            SkeletonOverlayView(joints: detectedJoints, viewSize: geo.size)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GeometryReader { geo in
                    Color.clear.onAppear { overlaySize = geo.size }
                        .onChange(of: geo.size) { overlaySize = $0 }
                })
            } else {
                emptyState
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showPicker = true } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPicker) {
            PHPickerSheet(isPresented: $showPicker, manager: manager)
        }
        .onReceive(manager.visionProcessor.$detectedPose) { pose in
            guard let joints = pose?.joints, !joints.isEmpty,
                  overlaySize.width > 0, manager.videoDisplaySize.width > 0 else {
                detectedJoints = [:]
                return
            }
            // Vision is given the correct pixel orientation, so it returns portrait coords:
            // (0,0)=bottom-left, (1,1)=top-right of portrait display.
            // Map directly into the resizeAspect video rect within the overlay view.
            let d = manager.videoDisplaySize
            let s = overlaySize
            let scale = min(s.width / d.width, s.height / d.height)
            let vr = CGRect(x: (s.width - d.width * scale) / 2,
                            y: (s.height - d.height * scale) / 2,
                            width: d.width * scale, height: d.height * scale)
            detectedJoints = joints.mapValues { pt in
                let ox = vr.minX + pt.x * vr.width
                let oy = vr.minY + (1.0 - pt.y) * vr.height
                return CGPoint(x: ox / s.width, y: 1.0 - oy / s.height)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.textSecondary.opacity(0.35))
            Text("Import a video to begin")
                .font(.mono(14))
                .foregroundStyle(Color.textSecondary.opacity(0.6))
            Button { showPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(Color.brandEmber)
                    Text("Import Video")
                        .font(.monoBold(15))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.brandEmber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brandEmber.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }
}
