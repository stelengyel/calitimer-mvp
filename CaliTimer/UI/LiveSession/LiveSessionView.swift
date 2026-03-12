import SwiftUI
import AVFoundation

struct LiveSessionView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

    // CameraManager is ObservableObject — @StateObject so @Published changes trigger re-renders
    @StateObject private var cameraManager = CameraManager()
    @State private var showingConfigSheet = false

    // Skeleton overlay preference — shared with SessionConfigSheet
    @StateObject private var skeletonPref = SkeletonPreference()

    // Hold state machine — drives indicator dot and timer display
    @StateObject private var holdStateMachine = HoldStateMachine()

    // Detection indicator visibility preference — shared with SessionConfigSheet and Settings
    @StateObject private var indicatorPref = DetectionIndicatorPreference()

    // Drives SkeletonOverlayView re-renders — updated via onReceive below
    @State private var detectedJoints: [String: CGPoint] = [:]

    private var targetReached: Bool {
        guard let target = holdStateMachine.targetDuration else { return false }
        return holdStateMachine.displayedElapsed >= target && holdStateMachine.state == .timing
    }

    var body: some View {
        ZStack {
            // Layer 0: Camera preview — full bleed, edge-to-edge
            if cameraManager.permissionDenied {
                // Permission denied inline fallback — not a full-screen takeover
                permissionDeniedView
            } else {
                CameraPreviewView(previewLayer: cameraManager.previewLayer)
                    .ignoresSafeArea()
            }

            // Layer 0.5: Skeleton overlay — between camera and controls
            if skeletonPref.isEnabled {
                GeometryReader { geo in
                    SkeletonOverlayView(joints: detectedJoints, viewSize: geo.size)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Layer 1: Overlaid controls
            VStack {
                // Detection indicator + timer cluster — top-center, above flip button row
                if indicatorPref.isEnabled {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            HoldIndicatorView(state: holdStateMachine.state)
                            HoldTimerView(
                                elapsed: holdStateMachine.displayedElapsed,
                                targetReached: targetReached
                            )
                        }
                        .padding(.top, 64)  // clear safe area / notch
                        Spacer()
                    }
                }

                // Top row: flip button (top-right)
                HStack {
                    Spacer()
                    Button {
                        cameraManager.flipCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                }

                Spacer()

                // Bottom row: End Session (left, small) + gear icon (right)
                HStack {
                    Button("End Session") {
                        coordinator.popToRoot()
                    }
                    .font(.mono(14))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.leading, 24)
                    .padding(.bottom, 48)

                    Spacer()

                    Button {
                        showingConfigSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Consume target set in pre-session config sheet.
            // coordinator.pendingTargetDuration is nil if no target was set (or if navigated without config).
            holdStateMachine.targetDuration = coordinator.pendingTargetDuration
            coordinator.pendingTargetDuration = nil
            await cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onReceive(cameraManager.visionProcessor.$detectedPose) { pose in
            guard let joints = pose?.joints, !joints.isEmpty else {
                detectedJoints = [:]
                return
            }
            // Vision is given .right orientation → returns portrait coords:
            // (0,0)=bottom-left, (1,1)=top-right of portrait.
            // layerPointConverted expects landscape capture device coords (0,0)=top-left.
            // Invert 90° CW rotation: cx = 1-vy, cy = 1-vx.
            // layerPointConverted handles resizeAspectFill crop and front camera mirror.
            let layer = cameraManager.previewLayer
            let bounds = layer.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }
            detectedJoints = joints.mapValues { pt in
                // Both cameras use .right orientation → Vision returns portrait coords.
                // Invert 90° CW rotation to get landscape capture device coords.
                // layerPointConverted handles front camera mirror automatically.
                let capturePoint = CGPoint(x: 1.0 - pt.y, y: 1.0 - pt.x)
                let layerPoint = layer.layerPointConverted(fromCaptureDevicePoint: capturePoint)
                return CGPoint(
                    x: layerPoint.x / bounds.width,
                    y: 1.0 - layerPoint.y / bounds.height
                )
            }
            // Wave 0 verification: confirm actual Vision joint key strings
            // Guarded behind #if DEBUG — removed from release builds after key strings empirically verified
            #if DEBUG
            HandstandClassifier.debugPrintKeys(pose)
            #endif
            // Process pose through state machine
            holdStateMachine.process(pose: pose)
        }
        .sheet(isPresented: $showingConfigSheet) {
            SessionConfigSheet(skeletonPref: skeletonPref, indicatorPref: indicatorPref) { skill, targetDuration in
                // Mid-session config update — session already created; just update in-memory
                // Full session mutation deferred to Phase 6 when holds relationship exists
                holdStateMachine.targetDuration = targetDuration
            }
            .presentationDetents([.medium])
        }
    }

    private var permissionDeniedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "camera.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.textSecondary)
                Text("Camera access required")
                    .font(.monoBold(16))
                    .foregroundStyle(Color.textPrimary)
                Text("CaliTimer needs camera access to detect handstand holds.")
                    .font(.mono(13))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Open Settings") {
                    Task {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            await UIApplication.shared.open(url)
                        }
                    }
                }
                .font(.monoBold(15))
                .foregroundStyle(Color.brandEmber)
                .padding(.top, 8)
            }
        }
    }
}
