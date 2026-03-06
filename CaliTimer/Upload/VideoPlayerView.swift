import SwiftUI
import AVFoundation
import AVKit

/// Full-screen video player with overlaid scrubber and play/pause controls.
/// The parent owns the AVPlayer instance and passes it in.
struct VideoPlayerView: View {
    let player: AVPlayer

    @State private var isPlaying: Bool = false
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isBuffering: Bool = false
    @State private var naturalSize: CGSize = CGSize(width: 9, height: 16)
    @State private var timeObserver: Any?
    @State private var itemObserver: NSKeyValueObservation?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Video surface — fills all available space, letterboxed by AVPlayerLayer
            AVPlayerLayerView(player: player, naturalSize: $naturalSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if isBuffering {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }

            // Bottom controls overlay
            controlsOverlay
        }
        .onAppear { setupObservers() }
        .onDisappear { teardownObservers() }
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack(spacing: 6) {
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

            HStack {
                Text(formatTime(currentTime))
                    .font(.mono(11))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()

                Spacer()

                Button {
                    if isPlaying { player.pause() } else { player.play() }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text(formatTime(duration))
                    .font(.mono(11))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Observers

    private func setupObservers() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
        }

        if let item = player.currentItem {
            itemObserver = item.observe(\.status, options: [.new]) { item, _ in
                DispatchQueue.main.async {
                    if item.status == .readyToPlay {
                        duration = item.duration.seconds.isNaN ? 0 : item.duration.seconds
                        if let track = item.tracks.first(where: { $0.assetTrack?.mediaType == .video }),
                           let assetTrack = track.assetTrack {
                            let size = assetTrack.naturalSize
                            naturalSize = size.width > 0 && size.height > 0 ? size : CGSize(width: 9, height: 16)
                        }
                        isBuffering = false
                        player.play()
                        isPlaying = true
                    }
                }
            }
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                isPlaying = false
                currentTime = 0
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

/// UIViewRepresentable that hosts an AVPlayerLayer, filling its frame.
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
