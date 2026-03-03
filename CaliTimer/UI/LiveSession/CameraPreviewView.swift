@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// UIView that hosts CameraManager's AVCaptureVideoPreviewLayer as a sublayer.
/// Using the sublayer approach (not layerClass override) so the exact same layer object
/// from CameraManager is embedded here — avoids the timing issue where makeUIView runs
/// before startSession() assigns the AVCaptureSession to the layer.
final class PreviewUIView: UIView {
    private var capturePreviewLayer: AVCaptureVideoPreviewLayer?

    func attach(_ layer: AVCaptureVideoPreviewLayer) {
        capturePreviewLayer = layer
        self.layer.addSublayer(layer)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capturePreviewLayer?.frame = bounds
    }
}

/// SwiftUI wrapper for the live camera viewfinder.
/// Receives CameraManager's previewLayer directly — no session copy, no timing dependency.
/// When startSession() later sets previewLayer.session, that same layer (already sublayered
/// here) begins rendering immediately.
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.attach(previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}
