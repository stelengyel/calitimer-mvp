import SwiftUI

struct SettingsView: View {
    @StateObject private var skeletonPref = SkeletonPreference()

    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()
            List {
                Section("Detection") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Skeleton Overlay")
                                .font(.mono(14))
                                .foregroundStyle(Color.textPrimary)
                            Text("Show joint detection on camera feed")
                                .font(.mono(11))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $skeletonPref.isEnabled)
                            .tint(Color.brandEmber)
                            .labelsHidden()
                    }
                    .listRowBackground(Color.brandBackground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.brandBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
