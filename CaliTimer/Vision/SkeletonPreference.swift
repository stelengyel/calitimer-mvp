import Foundation
import Combine

/// UserDefaults-backed observable preference for the skeleton overlay toggle.
/// Default: true — first launch shows skeleton immediately to validate detection is running.
/// Persists across sessions via UserDefaults.
@MainActor
final class SkeletonPreference: ObservableObject {

    private static let defaultsKey = "skeletonOverlayEnabled"

    @Published var isEnabled: Bool

    private var cancellable: AnyCancellable?

    init() {
        // UserDefaults.bool(forKey:) returns false when key is absent.
        // For first launch, the key doesn't exist yet — check for presence.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.defaultsKey) != nil {
            self.isEnabled = defaults.bool(forKey: Self.defaultsKey)
        } else {
            // First launch: default to true (skeleton on by default)
            self.isEnabled = true
            defaults.set(true, forKey: Self.defaultsKey)
        }

        // Observe changes and persist to UserDefaults.
        // @Published property observer (didSet) doesn't fire on @Published,
        // so use Combine sink instead.
        cancellable = $isEnabled.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: Self.defaultsKey)
        }
    }
}
