import Foundation
import AVFoundation
import PhotosUI
import SwiftUI

/// Owns video import state for UploadModeView.
/// @MainActor so @Published vars bind directly to SwiftUI without bridging.
/// Pattern mirrors CameraManager from Phase 2.
@MainActor
final class VideoImportManager: ObservableObject {

    // MARK: - Published state (UploadModeView reads these)

    /// Set after a video finishes loading.
    @Published var videoURL: URL?

    /// Ready-to-use player, created alongside videoURL in the same update.
    @Published var player: AVPlayer?

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
        player = nil
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
            // Copy the file synchronously here — the system-provided URL is only
            // valid for the duration of this callback. Dispatching async before
            // copying can result in the URL being invalidated before we use it,
            // which causes the first pick after a fresh launch to silently fail.
            let importResult: Result<URL, Error>
            if let error {
                importResult = .failure(error)
            } else if let url {
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                    importResult = .success(dest)
                } catch {
                    importResult = .failure(error)
                }
            } else {
                importResult = .failure(NSError(domain: "VideoImport", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not load video."]))
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.stopProgressTimer()
                self.isDownloading = false
                self.downloadProgress = 0
                self.progressObservation = nil

                switch importResult {
                case .success(let dest):
                    self.videoURL = dest
                    self.player = AVPlayer(playerItem: AVPlayerItem(url: dest))
                case .failure(let err):
                    self.importError = "Could not prepare video: \(err.localizedDescription)"
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
