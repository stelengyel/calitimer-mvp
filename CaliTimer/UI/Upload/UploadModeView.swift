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

                    // Skeleton overlay on top of video (during scan and playback)
                    if skeletonPref.isEnabled {
                        GeometryReader { geo in
                            SkeletonOverlayView(joints: detectedJoints, viewSize: geo.size)
                        }
                        .allowsHitTesting(false)
                    }

                    // Detection indicator + timer overlay (shown during scan)
                    if manager.isScanning && indicatorPref.isEnabled {
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

                    // Zone 3: holds results (shown after scan completes)
                    // Per Phase 3 stability contract: this is inner content only — outer ZStack unchanged
                    if !manager.isScanning {
                        VStack {
                            Spacer()
                            holdsResultsView
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 12)
                                .padding(.bottom, 16)
                        }
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
        // Trigger scan automatically when a new video is imported
        .onChange(of: manager.videoURL) { _, newURL in
            if newURL != nil {
                manager.startScan(holdStateMachine: holdStateMachine)
            }
        }
        .onDisappear {
            manager.cancelScan()
        }
        .onReceive(manager.visionProcessor.$detectedPose) { pose in
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

    // MARK: - Zone 3: Holds Results

    @ViewBuilder
    private var holdsResultsView: some View {
        if holdStateMachine.completedHolds.isEmpty && manager.videoURL != nil {
            // Empty state — shown after scan completes with no holds
            Text("No handstand holds detected")
                .font(.mono(14))
                .foregroundStyle(Color.textSecondary.opacity(0.7))
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        } else if !holdStateMachine.completedHolds.isEmpty {
            // Results list — scrollable, max 3 rows visible before scroll
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(holdStateMachine.completedHolds.enumerated()), id: \.element.id) { index, hold in
                        HStack {
                            Text("\(index + 1). \(hold.formattedStart()) - \(hold.formattedEnd()) — \(Int(hold.duration))s")
                                .font(.mono(13))
                                .foregroundStyle(Color.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            Spacer()
                        }
                        if index < holdStateMachine.completedHolds.count - 1 {
                            Divider()
                                .background(Color.textSecondary.opacity(0.15))
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .frame(maxHeight: 150)  // 3 rows approx; scrollable beyond that
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
