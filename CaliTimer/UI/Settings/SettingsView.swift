import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "gearshape")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.textSecondary)
                Text("Settings coming soon")
                    .font(.mono(16))
                    .foregroundStyle(Color.textSecondary)
                Text("Settings are added when their features land")
                    .font(.mono(12))
                    .foregroundStyle(Color.textSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.brandBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
