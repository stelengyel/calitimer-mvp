import SwiftUI

/// Pre-session and mid-session config: skill picker + optional target hold time + skeleton toggle.
/// Used in two places: HomeView (.sheet before navigate) and LiveSessionView (gear icon mid-session).
/// Skill picker: Handstand only in Phase 2. No placeholder slots for future skills.
struct SessionConfigSheet: View {
    /// Skeleton overlay preference — passed from LiveSessionView so both share the same instance.
    /// When opened from HomeView (no shared instance), caller passes a fresh SkeletonPreference.
    @ObservedObject var skeletonPref: SkeletonPreference

    /// Detection indicator preference — passed from LiveSessionView so both share the same instance.
    /// When opened from HomeView (no shared instance), caller passes a fresh DetectionIndicatorPreference.
    @ObservedObject var indicatorPref: DetectionIndicatorPreference

    /// Called when athlete taps Go. HomeView uses this to create Session + navigate.
    /// LiveSessionView uses this to update in-progress session config.
    let onConfirm: (_ skill: String, _ targetDuration: TimeInterval?) -> Void

    @Environment(\.dismiss) private var dismiss

    // Target hold duration persisted across sessions (0.0 = no target)
    @AppStorage("targetHoldDuration") private var targetHoldDurationSeconds: Double = 0.0

    // Local editing state — committed to @AppStorage on confirm
    @State private var draftDuration: Double = 0.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Skill label (Phase 2: fixed to Handstand, no picker needed)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skill")
                        .font(.mono(12))
                        .foregroundStyle(Color.textSecondary)
                    Text("Handstand")
                        .font(.monoBold(20))
                        .foregroundStyle(Color.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)

                Divider()
                    .background(Color.textSecondary.opacity(0.15))

                // Target hold time stepper
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Hold")
                        .font(.mono(12))
                        .foregroundStyle(Color.textSecondary)

                    HStack {
                        if draftDuration <= 0 {
                            Text("None")
                                .font(.monoBold(20))
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            Text(formattedDuration(draftDuration))
                                .font(.monoBold(20))
                                .foregroundStyle(Color.textPrimary)
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                draftDuration = max(0, draftDuration - 5)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(draftDuration > 0 ? Color.brandEmber : Color.textSecondary)
                            }
                            Button {
                                draftDuration += 5
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.brandEmber)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 24)

                Divider()
                    .background(Color.textSecondary.opacity(0.15))

                // Skeleton overlay toggle row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skeleton Overlay")
                            .font(.mono(12))
                            .foregroundStyle(Color.textSecondary)
                        Text("Show joint detection on camera")
                            .font(.mono(11))
                            .foregroundStyle(Color.textSecondary.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $skeletonPref.isEnabled)
                        .tint(Color.brandEmber)
                        .labelsHidden()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

                Divider()
                    .background(Color.textSecondary.opacity(0.15))

                // Detection indicator toggle row — same pattern as skeleton overlay
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Detection Indicator")
                            .font(.mono(12))
                            .foregroundStyle(Color.textSecondary)
                        Text("Show glow border and hold timer on camera")
                            .font(.mono(11))
                            .foregroundStyle(Color.textSecondary.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $indicatorPref.isEnabled)
                        .tint(Color.brandEmber)
                        .labelsHidden()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

                Spacer()

                // Go button
                Button {
                    let target: TimeInterval? = draftDuration > 0 ? draftDuration : nil
                    targetHoldDurationSeconds = draftDuration
                    onConfirm("Handstand", target)
                    dismiss()
                } label: {
                    Text("Go")
                        .font(.monoBold(18))
                        .foregroundStyle(Color.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.brandEmber, .brandAmber, .brandGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle("Session Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            draftDuration = targetHoldDurationSeconds
        }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s >= 60 ? "\(s / 60)m \(s % 60)s" : "\(s)s"
    }
}
