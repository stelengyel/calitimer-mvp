import SwiftUI

/// Colored detection state dot. Grey=searching, Ember=detected, Green=timing.
/// Pulses (breathing animation) during .timing state only.
/// Per user decision: icon-only, no text label, minimal footprint.
struct HoldIndicatorView: View {
    let state: HoldState
    @State private var isAnimating = false

    private var dotColor: Color {
        switch state {
        case .searching: return Color(red: 0.53, green: 0.53, blue: 0.53)  // neutral grey
        case .detected:  return Color.brandEmber                            // brand orange
        case .timing:    return Color.green
        }
    }

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
            .scaleEffect(isAnimating ? 1.35 : 1.0)
            .opacity(isAnimating ? 0.7 : 1.0)
            .animation(
                isAnimating
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: isAnimating
            )
            .onChange(of: state) { _, newState in
                isAnimating = (newState == .timing)
            }
            .onAppear {
                isAnimating = (state == .timing)
            }
    }
}
