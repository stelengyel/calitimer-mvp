import SwiftUI

@Observable
@MainActor
final class AppCoordinator {
    var path = NavigationPath()
    var isDrawerOpen = false
    var pendingTargetDuration: TimeInterval? = nil

    enum Destination: Hashable {
        case history
        case upload
        case settings
        case liveSession
    }

    func navigate(to destination: Destination) {
        isDrawerOpen = false
        path.append(destination)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
