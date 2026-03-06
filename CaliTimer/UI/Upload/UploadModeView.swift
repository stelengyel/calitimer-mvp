import SwiftUI
import AVFoundation

struct UploadModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = VideoImportManager()
    @State private var showPicker = false
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerView(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showPicker = true } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPicker) {
            PHPickerSheet(isPresented: $showPicker, manager: manager)
        }
        .onChange(of: manager.videoURL) { _, newURL in
            guard let url = newURL else { player = nil; return }
            player = AVPlayer(playerItem: AVPlayerItem(url: url))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.textSecondary.opacity(0.35))
            Text("Import a video to begin")
                .font(.mono(14))
                .foregroundStyle(Color.textSecondary.opacity(0.6))
            Button { showPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(Color.brandEmber)
                    Text("Import Video")
                        .font(.monoBold(15))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.brandEmber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brandEmber.opacity(0.4), lineWidth: 1)
                )
            }
        }
    }
}
