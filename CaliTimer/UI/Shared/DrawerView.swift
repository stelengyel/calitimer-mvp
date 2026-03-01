import SwiftUI

struct DrawerView: View {
    @Environment(AppCoordinator.self) private var coordinator
    private let drawerWidth: CGFloat = 260

    var body: some View {
        ZStack(alignment: .leading) {
            // Dim overlay — ONLY in hierarchy when drawer is open.
            // If always present (even transparent), it blocks the NavigationStack's swipe-back gesture.
            if coordinator.isDrawerOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            coordinator.isDrawerOpen = false
                        }
                    }
                    .transition(.opacity)
            }

            // Drawer panel
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // App name in drawer header
                    Text("CaliTimer")
                        .font(.monoBold(20))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.top, 72)
                        .padding(.bottom, 40)
                        .padding(.horizontal, 24)

                    // Nav items
                    DrawerNavItem(label: "History", icon: "clock.fill") {
                        coordinator.navigate(to: .history)
                    }
                    DrawerNavItem(label: "Upload", icon: "square.and.arrow.down.fill") {
                        coordinator.navigate(to: .upload)
                    }
                    DrawerNavItem(label: "Settings", icon: "gearshape.fill") {
                        coordinator.navigate(to: .settings)
                    }

                    Spacer()
                }
                .frame(width: drawerWidth)
                .background(Color.brandBackground)

                Spacer()
            }
            .offset(x: coordinator.isDrawerOpen ? 0 : -drawerWidth)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: coordinator.isDrawerOpen)
        }
        .ignoresSafeArea()
    }
}

// Drawer nav item — extracted to keep DrawerView readable
private struct DrawerNavItem: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandEmber)
                    .frame(width: 24)
                Text(label)
                    .font(.mono(16))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }
}
