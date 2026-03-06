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

    // Drives SkeletonOverlayView re-renders — updated via onReceive below
    @State private var detectedJoints: [String: CGPoint] = [:]

    // Session config passed from HomeView via AppCoordinator (or stored there)
    var sessionSkill: String = "Handstand"
    var sessionTargetDuration: TimeInterval? = nil

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
            // startSession() is @MainActor async — hops to background queue for startRunning()
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
            // AVCaptureVideoDataOutput delivers native landscape sensor buffers.
            // AVCaptureVideoPreviewLayer auto-rotates the preview but Vision coords are raw.
            // Remap landscape Vision coords → portrait Vision coords so SkeletonOverlayView
            // renders correctly over the portrait preview.
            //
            // Back camera (90° CCW to portrait): new_vx = 1-vy, new_vy = vx
            // Front camera (90° CW + mirror):    new_vx = 1-vy, new_vy = 1-vx
            detectedJoints = joints.mapValues { pt in
                CGPoint(x: 1 - pt.y, y: 1 - pt.x)
            }
        }
        .sheet(isPresented: $showingConfigSheet) {
            SessionConfigSheet(skeletonPref: skeletonPref) { skill, targetDuration in
                // Mid-session config update — session already created; just update in-memory
                // Full session mutation deferred to Phase 6 when holds relationship exists
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
