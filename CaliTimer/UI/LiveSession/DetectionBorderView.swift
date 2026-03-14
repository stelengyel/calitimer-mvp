import SwiftUI

/// Full-screen glow border that replaces HoldIndicatorView.
/// Amber during .detected (debouncing), green during .timing, hidden during .searching.
/// Visibility is gated by the caller — only render when indicatorPref.isEnabled.
struct DetectionBorderView: View {
    let state: HoldState

    private var isVisible: Bool {
        state == .detected || state == .timing
    }

    private var borderColor: Color {
        state == .timing ? .green : .brandEmber
    }

    var body: some View {
        ZStack {
            if isVisible {
                PulsingBorderLayer(
                    color: borderColor,
                    minOpacity: state == .timing ? 0.75 : 0.65,
                    duration: state == .timing ? 0.9 : 1.4
                )
                // Force recreation when crossing between .detected and .timing
                // so onAppear restarts the pulse with the new duration/colour.
                .id(state == .timing ? 1 : 2)
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
    }
}

/// Inner layer that owns the pulse animation lifecycle.
/// Recreated via .id() whenever state crosses between .detected ↔ .timing,
/// so onAppear always restarts the animation with the correct parameters.
private struct PulsingBorderLayer: View {
    let color: Color
    let minOpacity: Double
    let duration: Double

    @State private var isAnimating = false

    var body: some View {
        Rectangle()
            .stroke(color, lineWidth: 6)
            .shadow(color: color.opacity(0.85), radius: 18)
            .shadow(color: color.opacity(0.40), radius: 45)
            .opacity(isAnimating ? minOpacity : 1.0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration).repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}
