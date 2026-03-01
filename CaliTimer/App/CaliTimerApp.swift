import SwiftUI
import SwiftData

@main
struct CaliTimerApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.path) {
                HomeView()
                    .navigationDestination(for: AppCoordinator.Destination.self) { destination in
                        switch destination {
                        case .history:     HistoryView()
                        case .upload:      UploadModeView()
                        case .settings:    SettingsView()
                        case .liveSession: LiveSessionView()
                        }
                    }
                    .environment(coordinator)
            }
            .overlay(alignment: .leading) {
                DrawerView()
                    .environment(coordinator)
            }
        }
        .modelContainer(for: [Session.self, Hold.self, SkillPersonalBest.self])
    }
}
