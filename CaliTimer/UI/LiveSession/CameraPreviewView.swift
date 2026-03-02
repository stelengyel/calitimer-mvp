@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// UIView whose backing layer is AVCaptureVideoPreviewLayer.
/// layerClass override is the standard pattern — no frame copying, hardware-accelerated.
final class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep preview layer frame in sync with Auto Layout — required for full-bleed fill
        previewLayer.frame = bounds
    }
}

/// SwiftUI wrapper for the live camera viewfinder.
/// Receives the session reference through previewLayer — never receives AVCaptureSession directly.
/// (AVCaptureSession is NOT Sendable — passing it across actor boundaries violates Swift 6)
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        // Connect: assign the session reference from CameraManager's previewLayer
        view.previewLayer.session = previewLayer.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // No dynamic updates needed — layer renders autonomously from the session
    }
}
