import SwiftUI
import SwiftData

@main
struct CaliTimerApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            // NavigationStack + DrawerView wired in Plan 03
            // Placeholder: confirm compilation before screens are added
            Text("CaliTimer — scaffold")
                .environment(coordinator)
        }
        .modelContainer(for: [Session.self, Hold.self, SkillPersonalBest.self])
    }
}
