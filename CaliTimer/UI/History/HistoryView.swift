import SwiftUI

struct HistoryView: View {
    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.textSecondary)
                Text("No sessions yet")
                    .font(.monoBold(20))
                    .foregroundStyle(Color.textPrimary)
                Text("Complete a session to see your history")
                    .font(.mono(14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.brandBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // Note: .navigationBarTitleDisplayMode(.inline) + custom background requires toolbarBackground
    }
}
