import Foundation
import PhotosUI
import SwiftUI

/// Owns video import state for UploadModeView.
/// @MainActor so @Published vars bind directly to SwiftUI without bridging.
/// Pattern mirrors CameraManager from Phase 2.
@MainActor
final class VideoImportManager: ObservableObject {

    // MARK: - Published state (UploadModeView reads these)

    /// Set after a video finishes loading. Phase 5 observes this to start detection.
    @Published var videoURL: URL?

    /// True while an iCloud asset is being downloaded locally.
    @Published var isDownloading: Bool = false

    /// 0.0–1.0 progress during iCloud download. Show only when isDownloading == true.
    @Published var downloadProgress: Double = 0

    /// Non-nil when the last import attempt failed. Reset to nil on new import.
    @Published var importError: String?

    /// True after a video has been successfully loaded (videoURL != nil).
    var hasVideo: Bool { videoURL != nil }

    // MARK: - Internal

    /// Tracks the active download progress so it can be cancelled or observed.
    private var progressObservation: Progress?

    /// Timer used to poll iCloud download progress. Stored on self to allow
    /// invalidation without capturing the timer across actor boundaries.
    private var progressTimer: Timer?

    // MARK: - Import

    /// Called by PHPickerSheet after the user picks a video (or cancels).
    func handlePickerResult(_ results: [PHPickerResult]) async {
        guard let result = results.first else { return }

        // Reset previous state
        stopProgressTimer()
        videoURL = nil
        importError = nil
        isDownloading = false
        downloadProgress = 0

        let provider = result.itemProvider
        guard provider.hasItemConformingToTypeIdentifier("public.movie") else {
            importError = "Selected item is not a supported video format."
            return
        }

        isDownloading = true

        let progress = provider.loadFileRepresentation(
            forTypeIdentifier: "public.movie"
        ) { [weak self] url, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.stopProgressTimer()
                self.isDownloading = false
                self.downloadProgress = 0
                self.progressObservation = nil

                if let error {
                    self.importError = "Could not load video. \(error.localizedDescription)"
                    return
                }
                guard let url else {
                    self.importError = "Could not load video."
                    return
                }
                // Copy to app's temp directory — the system-provided URL
                // is only valid during this callback.
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                    self.videoURL = dest
                } catch {
                    self.importError = "Could not prepare video: \(error.localizedDescription)"
                }
            }
        }

        // Track download progress for iCloud assets
        progressObservation = progress
        // Poll progress on main RunLoop — NSProgress KVO is not MainActor-safe in Swift 6.
        // Timer is stored on self so the callback never captures `timer` across actor boundaries.
        startProgressTimer(progress)
    }

    // MARK: - Private

    private func startProgressTimer(_ progress: Progress) {
        // Timer fires on the main RunLoop because startProgressTimer() is @MainActor.
        // Use assumeIsolated so the Swift 6 checker knows we're already on MainActor.
        // We use `_` for the timer parameter so it is never captured or sent anywhere.
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard self.isDownloading else {
                    self.stopProgressTimer()
                    return
                }
                self.downloadProgress = progress.fractionCompleted
                if progress.isFinished { self.stopProgressTimer() }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
