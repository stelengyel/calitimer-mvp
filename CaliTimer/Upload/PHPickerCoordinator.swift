import SwiftUI
import PhotosUI

/// UIViewControllerRepresentable that presents PHPickerViewController filtered to videos only.
/// Usage: .sheet(isPresented: $showPicker) { PHPickerSheet(isPresented: $showPicker, manager: manager) }
struct PHPickerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let manager: VideoImportManager

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, manager: manager)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos          // video-only — no photos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current  // avoid transcoding
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var isPresented: Bool
        let manager: VideoImportManager

        init(isPresented: Binding<Bool>, manager: VideoImportManager) {
            self._isPresented = isPresented
            self.manager = manager
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            isPresented = false
            Task { @MainActor in
                await manager.handlePickerResult(results)
            }
        }
    }
}
