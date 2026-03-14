import SwiftUI

/// MM:SS timer display for the active hold.
/// Per user decision: turns green when target duration is reached.
/// Displays 0:00 before first hold; freezes on last hold's final time between holds.
struct HoldTimerView: View {
    let elapsed: TimeInterval
    let targetReached: Bool

    var body: some View {
        Text(formattedElapsed(elapsed))
            .font(.system(size: 44, weight: .bold, design: .monospaced))
            .foregroundStyle(targetReached ? Color.green : Color.white)
            .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 1)
    }

    private func formattedElapsed(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
