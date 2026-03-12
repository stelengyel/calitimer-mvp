import AVFoundation
import CoreMedia

/// Full-speed video frame scanner using AVAssetReader.
/// Reads frames sequentially at decoder speed (5-30x realtime on modern iPhones).
/// Per RESEARCH.md: AVPlayerItemVideoOutput realtime-rate path is NOT used for scanning.
///
/// Threading: scan() is nonisolated. Bridges back to MainActor for state machine calls only.
/// AVAssetReader is not Sendable — confined entirely to this function's stack.
enum AVAssetReaderScanner {

    /// Scan all frames in the video at `url`, running each through `visionProcessor`
    /// and feeding results to `holdStateMachine`. Sets currentVideoTime before each process() call
    /// so state machine records video-timeline offsets instead of wall-clock dates.
    ///
    /// Cancellation: cooperative — checks Task.isCancelled after each frame batch.
    /// Caller should store the Task and cancel on new video import or view dismissal.
    nonisolated static func scan(
        url: URL,
        visionProcessor: VisionProcessor,
        holdStateMachine: HoldStateMachine,
        pixelOrientation: CGImagePropertyOrientation
    ) async throws {
        let asset = AVURLAsset(url: url)

        // Load video track
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { return }

        // Setup AVAssetReader
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
        )
        output.alwaysCopiesSampleData = false  // performance: avoid extra copy
        reader.add(output)

        guard reader.startReading() else {
            throw NSError(domain: "AVAssetReaderScanner", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed to start: \(reader.error?.localizedDescription ?? "unknown")"])
        }

        // Reset state machine before scan
        await MainActor.run {
            holdStateMachine.resetForNewScan()
        }

        // Read loop — runs at full decoder speed
        // Bridge back to MainActor only for state machine calls (not for AVAssetReader ops)
        while reader.status == .reading {
            // Cooperative cancellation check
            if Task.isCancelled {
                reader.cancelReading()
                return
            }

            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }

            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // process() is nonisolated and returns the pose synchronously.
            // Using the return value directly eliminates the MainActor round-trip race:
            // the old pattern read visionProcessor.detectedPose after an await MainActor.run,
            // but the Task { @MainActor in self.detectedPose = pose } inside process() may not
            // have run yet, causing the state machine to always see the previous frame's pose.
            let pose = visionProcessor.process(sampleBuffer: sampleBuffer, orientation: pixelOrientation)

            await MainActor.run {
                holdStateMachine.currentVideoTime = pts
                holdStateMachine.process(pose: pose)
            }
        }

        // Scan complete — clear currentVideoTime on MainActor
        await MainActor.run {
            holdStateMachine.currentVideoTime = nil
        }
    }
}
