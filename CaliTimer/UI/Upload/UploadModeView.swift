import SwiftUI

struct UploadModeView: View {
    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Zone 1: Import action
                // Phase 3 replaces this button with PHPickerViewController integration
                VStack(spacing: 12) {
                    Button {
                        // Phase 3: PHPicker sheet presented here
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(Color.brandEmber)
                            Text("Import Video")
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
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Zone 2: Video player area
                // Phase 3 adds AVPlayer-based playback here
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                        .aspectRatio(16/9, contentMode: .fit)

                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.textSecondary)
                        Text("Video player")
                            .font(.mono(13))
                            .foregroundStyle(Color.textSecondary)
                        Text("Phase 3")
                            .font(.mono(11))
                            .foregroundStyle(Color.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Zone 3: Results area
                // Phase 5 populates this with detected holds + timestamps
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.textSecondary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.textSecondary.opacity(0.15), lineWidth: 1)
                        )

                    VStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.textSecondary.opacity(0.5))
                        Text("Results will appear here")
                            .font(.mono(13))
                            .foregroundStyle(Color.textSecondary.opacity(0.7))
                        Text("Import a video to detect holds")
                            .font(.mono(11))
                            .foregroundStyle(Color.textSecondary.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Upload")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.brandBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
