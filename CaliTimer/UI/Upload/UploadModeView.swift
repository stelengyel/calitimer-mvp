import SwiftUI
import AVFoundation

struct UploadModeView: View {
    @StateObject private var manager = VideoImportManager()
    @State private var showPicker = false
    @State private var player: AVPlayer?
    @State private var showLongVideoWarning = false

    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ZONE 1: Import action
                zone1

                // ZONE 2: Video player area
                zone2

                // ZONE 3: Results area (Phase 5 plugs in here)
                zone3
            }
        }
        .navigationTitle("Upload")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.brandBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showPicker) {
            PHPickerSheet(isPresented: $showPicker, manager: manager)
        }
        .onChange(of: manager.videoURL) { _, newURL in
            guard let url = newURL else { player = nil; return }
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            // Check duration for long-video warning (30 min = 1800s)
            Task {
                // Wait for item to be ready before reading duration
                try? await Task.sleep(for: .seconds(0.5))
                let dur = try? await item.asset.load(.duration)
                if let d = dur, d.seconds > 1800 {
                    showLongVideoWarning = true
                }
            }
        }
    }

    // MARK: - Zone 1

    private var zone1: some View {
        VStack(spacing: 8) {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(Color.brandEmber)
                    Text(manager.hasVideo ? "Import different video" : "Import Video")
                        .font(.monoBold(16))
                        .foregroundStyle(Color.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandEmber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandEmber.opacity(0.4), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)

            // Long video warning banner (non-blocking, dismissible)
            if showLongVideoWarning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.brandAmber)
                    Text("This video is over 30 minutes. Analysis may take a while.")
                        .font(.mono(12))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Button {
                        showLongVideoWarning = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.brandAmber.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Zone 2

    @ViewBuilder
    private var zone2: some View {
        if manager.isDownloading {
            // iCloud download progress
            VStack(spacing: 12) {
                Text("Downloading from iCloud…")
                    .font(.mono(13))
                    .foregroundStyle(Color.textSecondary)
                ProgressView(value: manager.downloadProgress, total: 1.0)
                    .tint(Color.brandEmber)
                Text("\(Int(manager.downloadProgress * 100))%")
                    .font(.mono(11))
                    .foregroundStyle(Color.textSecondary.opacity(0.7))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

        } else if let error = manager.importError {
            // Import error state
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.textSecondary)
                Text("Could not load video")
                    .font(.monoBold(14))
                    .foregroundStyle(Color.textPrimary)
                Text(error)
                    .font(.mono(12))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    showPicker = true
                }
                .font(.monoBold(13))
                .foregroundStyle(Color.brandEmber)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

        } else if let player {
            // Video player — adaptive aspect ratio, controls handled by VideoPlayerView
            VideoPlayerView(player: player)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

        } else {
            // Empty state — no video imported yet (current shell appearance)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
                    .aspectRatio(16/9, contentMode: .fit)

                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.textSecondary)
                    Text("No video imported")
                        .font(.mono(13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Zone 3 (Phase 5 wiring point)
    // IMPORTANT: Keep this zone's outer structure stable — Phase 5 replaces the inner content
    // with a detected holds list. Do NOT change the padding, background, or frame modifiers.

    @ViewBuilder
    private var zone3: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.textSecondary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.textSecondary.opacity(0.15), lineWidth: 1)
                )

            // Phase 5 replaces everything inside this ZStack.
            // detectionResults: [HoldResult] — injected by Phase 5 via @Binding or environment.
            if manager.hasVideo {
                // Shell: Analyzing… spinner — Phase 5 replaces with real progress + results list
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.textSecondary)
                    Text("Analyzing…")
                        .font(.mono(13))
                        .foregroundStyle(Color.textSecondary.opacity(0.7))
                }
            } else {
                // Empty state: no video imported
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.textSecondary.opacity(0.5))
                    Text("Import a video to see detected holds")
                        .font(.mono(13))
                        .foregroundStyle(Color.textSecondary.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
        .padding(.bottom, 20)
    }
}
