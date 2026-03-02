import Foundation

/// Serial global actor that isolates all AVFoundation work.
/// Established in STATE.md — non-negotiable for Swift 6 strict concurrency.
/// Cannot be retrofitted after Phase 4 adds Vision frame processing.
@globalActor
actor CameraActor: GlobalActor {
    static let shared = CameraActor()
}
