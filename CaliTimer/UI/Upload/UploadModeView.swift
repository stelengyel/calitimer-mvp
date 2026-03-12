import SwiftUI

struct UploadModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = VideoImportManager()
    @StateObject private var skeletonPref = SkeletonPreference()
    @StateObject private var indicatorPref = DetectionIndicatorPreference()
    @StateObject private var holdStateMachine = HoldStateMachine()
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

                    // Skeleton overlay — driven by the periodic time observer (same as live mode).
                    if skeletonPref.isEnabled {
                        GeometryReader { geo in
                            SkeletonOverlayView(joints: detectedJoints, viewSize: geo.size)
                        }
                        .allowsHitTesting(false)
                    }

                    // Detection indicator + timer — same UI as live camera mode.
                    if indicatorPref.isEnabled {
                        VStack {
                            VStack(spacing: 4) {
                                HoldIndicatorView(state: holdStateMachine.state)
                                HoldTimerView(
                                    elapsed: holdStateMachine.displayedElapsed,
                                    targetReached: false  // no target in upload mode
                                )
                            }
                            .padding(.top, 60)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GeometryReader { geo in
                    Color.clear.onAppear { overlaySize = geo.size }
                        .onChange(of: geo.size) { _, newSize in overlaySize = newSize }
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
        // Reset state machine when a new video is imported.
        .onChange(of: manager.videoURL) { _, newURL in
            if newURL != nil {
                holdStateMachine.resetForNewScan()
            }
        }
        // Drive skeleton + state machine from the periodic time observer (real-time, same as live mode).
        // No fast scan — the AVPlayerItemVideoOutput fires at ~30fps during playback.
        .onReceive(manager.visionProcessor.$detectedPose) { pose in
            holdStateMachine.process(pose: pose)
            guard let joints = pose?.joints, !joints.isEmpty,
                  overlaySize.width > 0, manager.videoDisplaySize.width > 0 else {
                detectedJoints = [:]
                return
            }
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

    // MARK: - Empty State (no video imported yet)

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
