import Foundation
@preconcurrency import AVFoundation
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

    // MARK: - Scan state (Phase 5)

    /// True while AVAssetReaderScanner is running. UploadModeView shows scan progress UI.
    @Published var isScanning = false

    /// True after a video has been successfully loaded (videoURL != nil).
    var hasVideo: Bool { videoURL != nil }

    /// Video display size after applying preferredTransform (width×height as shown to user).
    /// Used by UploadModeView to map Vision landscape coords into the resizeAspect video rect.
    @Published var videoDisplaySize: CGSize = .zero

    // MARK: - Vision

    /// VisionProcessor for upload mode — @MainActor isolated, matches VisionProcessor declaration.
    let visionProcessor = VisionProcessor()

    // MARK: - Internal

    /// Reference to the active scan task. Cancelled when a new video is imported.
    private var scanTask: Task<Void, Never>?

    /// Tracks the active download progress so it can be cancelled or observed.
    private var progressObservation: Progress?

    /// Timer used to poll iCloud download progress. Stored on self to allow
    /// invalidation without capturing the timer across actor boundaries.
    private var progressTimer: Timer?

    /// AVPlayerItemVideoOutput for pixel buffer extraction from the video frames.
    /// nonisolated(unsafe) because AVPlayerItemVideoOutput cannot cross actor boundaries.
    nonisolated(unsafe) private var videoOutput: AVPlayerItemVideoOutput?

    /// Orientation of the pixel buffer as delivered by AVPlayerItemVideoOutput.
    /// Derived from the video track's preferredTransform at import time.
    /// nonisolated(unsafe) because it's written on MainActor and read on Task.detached.
    nonisolated(unsafe) private var pixelOrientation: CGImagePropertyOrientation = .up

    /// Periodic time observer token for ~30fps frame polling. Must be removed before dealloc.
    private var frameObserverToken: Any?

    // MARK: - Import

    /// Called by PHPickerSheet after the user picks a video (or cancels).
    func handlePickerResult(_ results: [PHPickerResult]) async {
        guard let result = results.first else { return }

        // Reset previous state
        stopProgressTimer()
        detachVideoOutput()
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
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        let asset = AVURLAsset(url: dest)
                        if let track = try? await asset.loadTracks(withMediaType: .video).first {
                            let natural = (try? await track.load(.naturalSize)) ?? .zero
                            let t = (try? await track.load(.preferredTransform)) ?? .identity
                            let isRotated = abs(t.b) > 0.5 || abs(t.c) > 0.5
                            let displaySize = isRotated
                                ? CGSize(width: natural.height, height: natural.width)
                                : natural

                            // Reject landscape videos — app is portrait-only.
                            guard displaySize.height >= displaySize.width else {
                                self.importError = "Please import a portrait video."
                                return
                            }

                            self.videoDisplaySize = displaySize

                            // Derive Vision orientation from the pixel buffer layout.
                            // isRotated → pixels are landscape-encoded; determine CW vs CCW.
                            // !isRotated → pixels match display orientation (.up or .down).
                            if isRotated {
                                self.pixelOrientation = t.b > 0 ? .right : .left
                            } else {
                                self.pixelOrientation = t.a >= 0 ? .up : .down
                            }
                        }

                        self.videoURL = dest
                        self.player = AVPlayer(playerItem: AVPlayerItem(url: dest))
                        self.attachVideoOutput(to: self.player!)
                        // Phase 5: UploadModeView will call self.startScan(holdStateMachine:) after import — NOT called here to avoid needing holdStateMachine reference in VideoImportManager
                    }
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

    // MARK: - Video Output / Frame Processing

    /// Attach an AVPlayerItemVideoOutput to the given player and start polling frames at ~30fps.
    /// Called immediately after player creation in handlePickerResult.
    private func attachVideoOutput(to player: AVPlayer) {
        // Remove any previous output before attaching a new one
        detachVideoOutput()

        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ])
        self.videoOutput = output
        player.currentItem?.add(output)

        // Poll every ~33ms (~30fps) — matches typical video frame rate.
        // Vision will process on a background thread via Task.detached (nonisolated process()).
        let interval = CMTime(seconds: 0.033, preferredTimescale: 600)
        frameObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.processCurrentFrame(at: time)
            }
        }
    }

    /// Extract the current video frame at `time` and send it to VisionProcessor.
    /// hasNewPixelBuffer returns false when paused — naturally holds the last skeleton on screen.
    private func processCurrentFrame(at time: CMTime) {
        guard let output = videoOutput,
              output.hasNewPixelBuffer(forItemTime: time) else { return }

        guard let pixelBuffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }

        // Wrap CVPixelBuffer in CMSampleBuffer for VNSequenceRequestHandler
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        guard let formatDescription else { return }

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer else { return }

        // process() is nonisolated — dispatch to a background thread to keep Main thread free
        let processor = visionProcessor
        let orientation = pixelOrientation
        Task.detached {
            processor.process(sampleBuffer: sampleBuffer, orientation: orientation)
        }
    }

    // MARK: - Scan (Phase 5)

    /// Start a full-speed AVAssetReader scan of the current video.
    /// Called automatically after video import completes (no user tap required — per CONTEXT.md).
    /// Stops the AVPlayerItemVideoOutput observer during scan to avoid dual processing.
    func startScan(holdStateMachine: HoldStateMachine) {
        guard let url = videoURL else { return }

        // Cancel any in-flight scan
        scanTask?.cancel()

        // Detach the realtime-rate observer during full-speed scan
        detachVideoOutput()

        isScanning = true

        let processor = visionProcessor
        let orientation = pixelOrientation

        scanTask = Task {
            defer {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isScanning = false
                    // Reattach video output for skeleton overlay after scan completes
                    if let player = self.player {
                        self.attachVideoOutput(to: player)
                    }
                }
            }

            do {
                try await AVAssetReaderScanner.scan(
                    url: url,
                    visionProcessor: processor,
                    holdStateMachine: holdStateMachine,
                    pixelOrientation: orientation
                )
            } catch {
                print("[AVAssetReaderScanner] scan error: \(error)")
            }
        }
    }

    /// Cancel an in-progress scan. Called on new import or view dismissal.
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    /// Remove the video output and stop the periodic observer. Called before attaching a new one
    /// and in the reset block at the top of handlePickerResult.
    private func detachVideoOutput() {
        if let token = frameObserverToken, let player {
            player.removeTimeObserver(token)
            frameObserverToken = nil
        }
        videoOutput = nil
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
