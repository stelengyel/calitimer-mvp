import SwiftUI

/// Centre-screen hold result shown after each confirmed hold.
/// Stateless — the parent owns showResult / resultDuration and drives
/// appearance via withAnimation so insertion and removal use different curves.
struct HoldResultOverlay: View {
    let duration: TimeInterval

    var body: some View {
        Text(formattedDuration(duration))
            .font(.system(size: 96, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
