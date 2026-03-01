import SwiftUI

struct LiveSessionView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Camera feed placeholder — dark rectangle
                // Phase 2 drops CameraPreviewView (UIViewRepresentable) directly here
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.85))

                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.textSecondary)
                        Text("Camera feed")
                            .font(.mono(13))
                            .foregroundStyle(Color.textSecondary)
                        Text("Phase 2")
                            .font(.mono(11))
                            .foregroundStyle(Color.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()

                // Placeholder controls area
                // Phase 2 adds real Start/End session controls here
                VStack(spacing: 16) {
                    Text("Session Controls")
                        .font(.mono(12))
                        .foregroundStyle(Color.textSecondary.opacity(0.5))

                    Button {
                        coordinator.popToRoot()
                    } label: {
                        Text("End Session")
                            .font(.monoBold(16))
                            .foregroundStyle(Color.brandEmber)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.brandEmber, lineWidth: 1)
                            )
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .toolbar(.hidden, for: .navigationBar)  // Full-screen — no nav chrome (iOS 16+, preferred over navigationBarHidden)
    }
}
