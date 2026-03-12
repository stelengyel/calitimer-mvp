import SwiftUI

struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var modelContext

    @State private var showingConfigSheet = false
    @StateObject private var skeletonPref = SkeletonPreference()

    var body: some View {
        ZStack {
            // Midnight base
            Color.brandBackground.ignoresSafeArea()

            // Ember gradient hero — subtle glow at ~15% opacity over the midnight base
            // Full-screen coverage; the Start Session button uses full-opacity gradient for contrast
            LinearGradient(
                colors: [.brandEmber, .brandAmber, .brandGold],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(0.15)

            VStack(spacing: 0) {
                Spacer()

                // App name
                Text("CaliTimer")
                    .font(.monoBold(40))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.bottom, 8)

                Text("automatic hold timing")
                    .font(.mono(14))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.bottom, 60)

                Spacer()

                // Start Session CTA — full-opacity brand gradient
                Button {
                    showingConfigSheet = true
                } label: {
                    Text("Start Session")
                        .font(.monoBold(18))
                        .foregroundStyle(Color.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.brandEmber, .brandAmber, .brandGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        coordinator.isDrawerOpen = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(Color.textPrimary)
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showingConfigSheet) {
            SessionConfigSheet(skeletonPref: skeletonPref, indicatorPref: DetectionIndicatorPreference()) { skill, targetDuration in
                let session = Session(skill: skill, targetDuration: targetDuration)
                modelContext.insert(session)
                coordinator.pendingTargetDuration = targetDuration
                coordinator.navigate(to: .liveSession)
            }
            .presentationDetents([.medium])
        }
    }
}
