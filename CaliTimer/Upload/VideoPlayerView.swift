import SwiftUI
import AVFoundation
import AVKit

/// SwiftUI video player with adaptive aspect ratio, play/pause, seek scrubber, and time labels.
/// The parent owns the AVPlayer instance and passes it in — Phase 5 can control playback externally.
struct VideoPlayerView: View {
    let player: AVPlayer

    @State private var isPlaying: Bool = false
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isBuffering: Bool = false
    @State private var naturalSize: CGSize = CGSize(width: 16, height: 9)
    @State private var timeObserver: Any?
    @State private var itemObserver: NSKeyValueObservation?

    var body: some View {
        VStack(spacing: 0) {
            // Video surface — adaptive aspect ratio
            ZStack {
                AVPlayerLayerView(player: player, naturalSize: $naturalSize)
                    .aspectRatio(naturalSize.width / naturalSize.height, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Buffering indicator
                if isBuffering {
                    ProgressView()
                        .tint(Color.textPrimary)
                        .scaleEffect(1.2)
                }
            }

            // Controls row
            VStack(spacing: 8) {
                // Scrubber
                Slider(
                    value: $currentTime,
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            let target = CMTime(seconds: currentTime, preferredTimescale: 600)
                            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                        }
                    }
                )
                .tint(Color.brandEmber)

                // Time labels + play/pause
                HStack {
                    Text(formatTime(currentTime))
                        .font(.mono(11))
                        .foregroundStyle(Color.textSecondary)
                        .monospacedDigit()

                    Spacer()

                    Button {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brandEmber)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text(formatTime(duration))
                        .font(.mono(11))
                        .foregroundStyle(Color.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
        .onAppear { setupObservers() }
        .onDisappear { teardownObservers() }
    }

    // MARK: - Private

    private func setupObservers() {
        // Periodic time update for scrubber
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }

        // Item status observation for duration + autoplay + naturalSize
        if let item = player.currentItem {
            itemObserver = item.observe(\.status, options: [.new]) { item, _ in
                DispatchQueue.main.async {
                    if item.status == .readyToPlay {
                        duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                        // Adaptive aspect ratio from video track
                        if let track = item.tracks.first(where: { $0.assetTrack?.mediaType == .video }),
                           let assetTrack = track.assetTrack {
                            let size = assetTrack.naturalSize
                            naturalSize = size.width > 0 && size.height > 0 ? size : CGSize(width: 16, height: 9)
                        }
                        isBuffering = false
                        player.play()       // Autoplay on ready
                        isPlaying = true
                    }
                }
            }
            // Stop at end — observe playback-to-end notification
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                isPlaying = false
                currentTime = 0
                // Seek back to start but do NOT loop
                player.seek(to: .zero)
            }
        }
    }

    private func teardownObservers() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        itemObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let total = Int(max(0, seconds))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

/// UIViewRepresentable that hosts an AVPlayerLayer.
/// Separate from VideoPlayerView so the SwiftUI layout gets the correct aspect ratio frame.
private struct AVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var naturalSize: CGSize

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    final class PlayerUIView: UIView {
        private let playerLayer: AVPlayerLayer

        init(player: AVPlayer) {
            self.playerLayer = AVPlayerLayer(player: player)
            self.playerLayer.videoGravity = .resizeAspect
            super.init(frame: .zero)
            layer.addSublayer(playerLayer)
            backgroundColor = .black
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
