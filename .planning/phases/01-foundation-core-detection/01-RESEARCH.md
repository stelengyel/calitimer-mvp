# Phase 1: Foundation + Core Detection - Research

**Researched:** 2026-03-01
**Domain:** Real-time pose estimation, camera pipeline, hold state machine, persistence, SwiftUI
**Confidence:** HIGH (first-party Apple frameworks with well-documented APIs)

## Summary

Phase 1 builds the core of CaliTimer: a camera pipeline that feeds frames into Apple's Vision framework for human body pose detection, a geometric classifier that determines whether the person is in a handstand, a state machine that debounces transitions and drives a live timer, and a persistence layer that stores sessions and holds with personal best tracking. A secondary video import path reuses the same detection pipeline against pre-recorded footage for developer testing.

The entire stack is first-party Apple: AVFoundation for camera and video reading, Vision for pose estimation, SwiftUI with @Observable for UI, and SwiftData for persistence. Zero external dependencies. This is a locked decision from prior research.

**Primary recommendation:** Build a CameraActor (custom global actor) that owns AVCaptureSession and its delegate callbacks, feeding CMSampleBuffers into a PoseDetector actor that wraps VNDetectHumanBodyPoseRequest. The HandstandClassifier is a pure function (struct) that takes recognized points and returns a classification. The HoldStateMachine is a value type driven by the classifier output with frame-count debounce thresholds. SessionCoordinator (@MainActor @Observable) orchestrates everything and drives the SwiftUI views.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DETE-01 | Auto-detect handstand via geometric pose classifier | Vision VNDetectHumanBodyPoseRequest + geometric classifier (feet-above-head in normalized coords); see Architecture Patterns |
| DETE-02 | Hold state machine with debounce | HoldStateMachine value type with searching/detected/timing/ended states and 10-15 frame threshold; see State Machine pattern |
| DETE-03 | Detection state indicator (3 visual states, toggleable) | SwiftUI overlay driven by HoldStateMachine.state, bound to toggle in SessionCoordinator |
| DETE-04 | Timer counts up during active hold | ContinuousClock-based timer started on timing state entry, stopped on hold end; see Timer pattern |
| DETE-05 | Skeleton overlay on camera feed, toggleable | SkeletonRenderer using Canvas/Shape drawing recognized joint positions; see Overlay pattern |
| DETE-06 | Visual + haptic alert at target duration | UINotificationFeedbackGenerator.success + visual flash; see Haptic pattern |
| DETE-07 | Set target hold duration on the fly | Stepper/picker in session view, stored in SessionCoordinator.targetDuration |
| CAMR-01 | Front and rear camera | AVCaptureDevice.Position toggle via CameraActor.switchCamera(); see Camera pattern |
| CAMR-02 | Works propped on stand | No orientation lock; UIDevice.orientation awareness for correct Vision coordinate mapping |
| SESS-01 | Start/end explicit training session | SessionCoordinator manages session lifecycle; SwiftData Session entity created on start |
| SESS-02 | Holds grouped under session | Hold entity has session foreign key; see Data Model |
| HIST-01 | Session history log (skill, duration, date, camera) | SwiftData @Query in HistoryView; see Persistence pattern |
| HIST-02 | Personal best per skill tracked locally | Computed on write: compare new hold duration to stored PB, update if exceeded |
| VIDU-01 | Import video from camera roll | PHPickerViewController for .videos; see Video Import pattern |
| VIDU-02 | Detection pipeline runs against imported video | AVAssetReader + CMSampleBuffer extraction fed into same PoseDetector; see VideoFrameReader pattern |
</phase_requirements>

## Standard Stack

### Core

| Library/Framework | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| AVFoundation | iOS 17+ | Camera capture (AVCaptureSession), video reading (AVAssetReader), sample buffer delivery | Apple's only supported camera API; required for real-time frame access |
| Vision | iOS 17+ | VNDetectHumanBodyPoseRequest for 2D body pose estimation | Apple's on-device pose estimation; no external dependency needed; runs on Neural Engine |
| SwiftUI | iOS 17+ | All UI: camera preview, overlays, session controls, history | @Observable support from iOS 17; project standard |
| SwiftData | iOS 17+ | Persistence for Session, Hold, SkillPersonalBest entities | Project decision: zero external dependencies; first-party Apple persistence |
| UIKit (targeted) | iOS 17+ | UIViewRepresentable for AVCaptureVideoPreviewLayer, UINotificationFeedbackGenerator for haptics | SwiftUI has no native camera preview; haptic API is UIKit-only |

### Supporting

| Library/Framework | Version | Purpose | When to Use |
|-------------------|---------|---------|-------------|
| PhotosUI | iOS 17+ | PHPickerViewController for video import (VIDU-01) | Video upload mode only |
| CoreHaptics | iOS 17+ | Advanced haptic patterns (optional, UIFeedbackGenerator may suffice) | Only if simple notification haptic is insufficient |
| os.log | iOS 17+ | Structured logging for detection pipeline debugging | Throughout; especially detection tuning |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftData | SQLiteData (GRDB-based) | More control, better query composition, CloudKit sync; but adds external dependency which contradicts project decision |
| Vision body pose | MediaPipe | Cross-platform, more joint points; but adds large external dependency, not needed for handstand-only |
| Vision body pose | Create ML custom model | Could be more accurate for specific skill; but massive training data effort, Vision is sufficient for geometric classification |

**Installation:** No external packages. All frameworks are system frameworks included in Xcode.

## Architecture Patterns

### Recommended Project Structure

```
CaliTimer/
  App/
    CaliTimerApp.swift              # @main entry, SwiftData container setup
  Features/
    Session/
      SessionView.swift             # Main training session UI
      SessionCoordinator.swift      # @Observable, orchestrates camera+detection+timer
    History/
      HistoryView.swift             # Session history list
      SessionDetailView.swift       # Single session hold list
    VideoImport/
      VideoImportView.swift         # PHPicker + debug output
      VideoFrameReader.swift        # AVAssetReader frame extraction
  Detection/
    CameraActor.swift               # Global actor owning AVCaptureSession
    PoseDetector.swift              # Actor wrapping Vision requests
    HandstandClassifier.swift       # Pure struct: recognized points -> classification
    HoldStateMachine.swift          # Value type: classification stream -> hold events
  Rendering/
    CameraPreviewView.swift         # UIViewRepresentable for preview layer
    SkeletonRenderer.swift          # Canvas overlay drawing joints + bones
    DetectionStateOverlay.swift     # Visual state indicator (searching/detected/timing)
  Models/
    Session.swift                   # SwiftData @Model
    Hold.swift                      # SwiftData @Model
    SkillPersonalBest.swift         # SwiftData @Model
  Utilities/
    HapticManager.swift             # Wrapper around UIFeedbackGenerator
```

### Pattern 1: CameraActor (Global Actor for AVCaptureSession)

**What:** A custom global actor that isolates all AVCaptureSession configuration and delegate callbacks to a single serial executor, satisfying Swift 6 strict concurrency.

**When to use:** Always. AVCaptureSession is not thread-safe and its delegate callbacks arrive on a serial dispatch queue. Wrapping this in a global actor provides compile-time safety.

**Why global actor, not plain actor:** AVCaptureSession's delegate (AVCaptureVideoDataOutputSampleBufferDelegate) delivers callbacks on a dispatch queue you specify. A @globalActor lets you annotate the delegate conformance so the compiler enforces isolation. A plain actor would require async hops for every delegate callback, adding latency to the frame pipeline.

```swift
@globalActor
actor CameraActor {
    static let shared = CameraActor()

    // Dedicated serial queue for video data output
    let videoDataOutputQueue = DispatchQueue(
        label: "com.calitimer.camera.videodata",
        qos: .userInteractive
    )
}

@CameraActor
final class CameraManager: NSObject {
    private let captureSession = AVCaptureSession()
    private var currentInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?

    // Frame callback closure — called on videoDataOutputQueue
    var onFrame: ((CMSampleBuffer) -> Void)?

    func configure(position: AVCaptureDevice.Position) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .high

        // Remove existing input
        if let currentInput {
            captureSession.removeInput(currentInput)
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            throw CameraError.deviceUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        captureSession.addInput(input)
        currentInput = input

        // Video data output
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: CameraActor.shared.videoDataOutputQueue)
        guard captureSession.canAddOutput(output) else {
            throw CameraError.cannotAddOutput
        }
        captureSession.addOutput(output)
        videoDataOutput = output
    }

    func start() {
        guard !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    func stop() {
        guard captureSession.isRunning else { return }
        captureSession.stopRunning()
    }

    func switchCamera() throws {
        let newPosition: AVCaptureDevice.Position =
            currentInput?.device.position == .back ? .front : .back
        try configure(position: newPosition)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // This runs on videoDataOutputQueue
        onFrame?(sampleBuffer)
    }
}
```

### Pattern 2: PoseDetector (Vision Request Handler)

**What:** An actor that receives CMSampleBuffers, runs VNDetectHumanBodyPoseRequest, and emits recognized body pose observations.

**Critical detail from prior research:** Use VNSequenceRequestHandler created ONCE per session (not VNImageRequestHandler per frame). This provides temporal smoothing and reduces CPU waste.

**IMPORTANT: VNSequenceRequestHandler.perform is synchronous.** It blocks the calling thread until the request completes. This is by design -- it must be called from the same serial queue that supplies frames. Do NOT wrap it in async/await or Task; call it synchronously on the video data output queue.

```swift
actor PoseDetector {
    private let sequenceHandler = VNSequenceRequestHandler()
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()

    /// Process a frame and return recognized body points (if any).
    /// Call from video data output queue (synchronous Vision processing).
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) -> VNHumanBodyPoseObservation? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
            return request.results?.first
        } catch {
            // Log but don't crash -- dropped frames are acceptable
            return nil
        }
    }
}
```

**Note on VNSequenceRequestHandler vs VNImageRequestHandler:** For body pose detection specifically, VNImageRequestHandler per frame is acceptable and simpler. VNSequenceRequestHandler is primarily beneficial for tracking requests (VNTrackObjectRequest). The prior research recommendation to use VNSequenceRequestHandler may have been based on general Vision best practices rather than body pose specifics. For Phase 1, VNImageRequestHandler per frame is correct for body pose. Revisit if adding tracking in Phase 4.

### Pattern 3: HandstandClassifier (Pure Geometric Function)

**What:** A pure value type that takes a VNHumanBodyPoseObservation and returns whether the pose is a handstand. Uses geometric rules (feet above head in normalized coordinates), NOT per-joint confidence scores.

**Why geometric, not confidence:** Prior research established that Vision's confidence scores degrade on inverted poses (upside-down bodies). Geometric classification (comparing Y-coordinates of wrists vs ankles) is more robust.

**Key thresholds to determine empirically:**
- Wrist Y < Ankle Y margin (how much higher must feet be than hands)
- Vertical alignment tolerance (how far off-center is acceptable)
- Minimum joint confidence cutoff (below which to discard the entire observation)

```swift
struct HandstandClassifier {
    struct Configuration {
        /// Minimum Y-distance (normalized) between ankle midpoint and wrist midpoint.
        /// Positive means ankles are above wrists in image coordinates.
        /// NOTE: Vision normalized coordinates have origin at bottom-left,
        /// so higher Y = higher in the image.
        var minVerticalSeparation: CGFloat = 0.15

        /// Maximum horizontal offset between ankle midpoint and wrist midpoint.
        var maxHorizontalOffset: CGFloat = 0.25

        /// Minimum confidence for any individual joint to be considered valid.
        var minJointConfidence: Float = 0.3
    }

    var configuration = Configuration()

    enum Classification: Equatable {
        case handstand
        case notHandstand
        case insufficientData  // Not enough joints detected
    }

    func classify(_ observation: VNHumanBodyPoseObservation) -> Classification {
        guard let points = extractKeyPoints(from: observation) else {
            return .insufficientData
        }

        let ankleCenter = CGPoint(
            x: (points.leftAnkle.x + points.rightAnkle.x) / 2,
            y: (points.leftAnkle.y + points.rightAnkle.y) / 2
        )
        let wristCenter = CGPoint(
            x: (points.leftWrist.x + points.rightWrist.x) / 2,
            y: (points.leftWrist.y + points.rightWrist.y) / 2
        )

        // In Vision normalized coords: higher Y = higher in frame
        let verticalSeparation = ankleCenter.y - wristCenter.y
        let horizontalOffset = abs(ankleCenter.x - wristCenter.x)

        if verticalSeparation >= configuration.minVerticalSeparation
            && horizontalOffset <= configuration.maxHorizontalOffset {
            return .handstand
        }

        return .notHandstand
    }

    private func extractKeyPoints(
        from observation: VNHumanBodyPoseObservation
    ) -> KeyPoints? {
        do {
            let leftAnkle = try observation.recognizedPoint(.leftAnkle)
            let rightAnkle = try observation.recognizedPoint(.rightAnkle)
            let leftWrist = try observation.recognizedPoint(.leftWrist)
            let rightWrist = try observation.recognizedPoint(.rightWrist)

            // Check minimum confidence
            guard leftAnkle.confidence >= configuration.minJointConfidence,
                  rightAnkle.confidence >= configuration.minJointConfidence,
                  leftWrist.confidence >= configuration.minJointConfidence,
                  rightWrist.confidence >= configuration.minJointConfidence
            else {
                return nil
            }

            return KeyPoints(
                leftAnkle: leftAnkle.location,
                rightAnkle: rightAnkle.location,
                leftWrist: leftWrist.location,
                rightWrist: rightWrist.location
            )
        } catch {
            return nil
        }
    }

    struct KeyPoints {
        let leftAnkle: CGPoint
        let rightAnkle: CGPoint
        let leftWrist: CGPoint
        let rightWrist: CGPoint
    }
}
```

### Pattern 4: HoldStateMachine (Value Type with Debounce)

**What:** A value type (struct) that receives per-frame classification results and transitions through searching -> detected -> timing -> ended states. Uses frame-count debounce to prevent phantom holds.

```swift
struct HoldStateMachine {
    enum State: Equatable {
        case searching
        case detected(frameCount: Int)   // Accumulating detection frames
        case timing(startDate: Date)     // Active hold being timed
        case ended(duration: TimeInterval)
    }

    var state: State = .searching

    /// Frames of consistent detection before transitioning to timing
    var detectionThreshold: Int = 12  // ~0.4s at 30fps

    /// Frames of consistent non-detection before ending a hold
    var lossThreshold: Int = 10       // ~0.33s at 30fps

    private var lossFrameCount: Int = 0

    mutating func feed(_ classification: HandstandClassifier.Classification) {
        switch (state, classification) {

        // Searching + handstand detected -> start accumulating
        case (.searching, .handstand):
            state = .detected(frameCount: 1)

        // Accumulating detections
        case (.detected(let count), .handstand):
            if count + 1 >= detectionThreshold {
                state = .timing(startDate: Date())
                lossFrameCount = 0
            } else {
                state = .detected(frameCount: count + 1)
            }

        // Lost detection during accumulation -> reset
        case (.detected, .notHandstand), (.detected, .insufficientData):
            state = .searching

        // Active timing + still handstand -> continue
        case (.timing, .handstand):
            lossFrameCount = 0

        // Active timing + lost detection -> count loss frames
        case (.timing(let startDate), .notHandstand),
             (.timing(let startDate), .insufficientData):
            lossFrameCount += 1
            if lossFrameCount >= lossThreshold {
                let duration = Date().timeIntervalSince(startDate)
                state = .ended(duration: duration)
            }

        // After ended, reset when ready
        case (.ended, _):
            break  // External code calls reset()

        // Searching + no detection -> stay searching
        case (.searching, .notHandstand), (.searching, .insufficientData):
            break
        }
    }

    mutating func reset() {
        state = .searching
        lossFrameCount = 0
    }
}
```

### Pattern 5: SessionCoordinator (@Observable, MainActor)

**What:** The central orchestrator that wires camera -> detection -> state machine -> UI. Lives on @MainActor so all state mutations drive SwiftUI directly.

```swift
@Observable
@MainActor
final class SessionCoordinator {
    // State exposed to SwiftUI
    var holdState: HoldStateMachine.State = .searching
    var currentHoldDuration: TimeInterval = 0
    var targetDuration: TimeInterval = 30  // User-adjustable
    var isSkeletonVisible = true
    var isDetectionStateVisible = true
    var recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
    var isSessionActive = false

    // Internal
    private var stateMachine = HoldStateMachine()
    private let classifier = HandstandClassifier()
    private var timerTask: Task<Void, Never>?

    // Dependencies (injected or created)
    private let cameraManager: CameraManager
    private let modelContext: ModelContext

    // ... lifecycle methods: startSession(), endSession(), processFrame()
}
```

### Pattern 6: VideoFrameReader (AVAssetReader for Video Import)

**What:** Extracts CMSampleBuffers from a video file at native frame rate, feeding them into the same PoseDetector + HandstandClassifier pipeline used for live detection.

```swift
final class VideoFrameReader {
    struct DetectedHold: Identifiable {
        let id = UUID()
        let startTime: CMTime
        let endTime: CMTime
        let duration: TimeInterval
    }

    func processVideo(at url: URL) async throws -> [DetectedHold] {
        let asset = AVURLAsset(url: url)
        let track = try await asset.loadTracks(withMediaType: .video).first!
        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let trackOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: outputSettings
        )
        reader.add(trackOutput)
        reader.startReading()

        var stateMachine = HoldStateMachine()
        let classifier = HandstandClassifier()
        var holds: [DetectedHold] = []
        var currentHoldStart: CMTime?

        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Run same detection pipeline
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try handler.perform([request])

            let classification: HandstandClassifier.Classification
            if let observation = request.results?.first {
                classification = classifier.classify(observation)
            } else {
                classification = .insufficientData
            }

            let previousState = stateMachine.state
            stateMachine.feed(classification)

            // Detect transitions
            if case .timing = stateMachine.state, !(previousState == stateMachine.state) {
                currentHoldStart = timestamp
            }
            if case .ended(let duration) = stateMachine.state {
                if let start = currentHoldStart {
                    holds.append(DetectedHold(
                        startTime: start,
                        endTime: timestamp,
                        duration: duration
                    ))
                }
                currentHoldStart = nil
                stateMachine.reset()
            }
        }

        return holds
    }
}
```

### Anti-Patterns to Avoid

- **Creating VNImageRequestHandler on a background Task with async/await for each frame:** Vision's perform() is synchronous and designed to be called on the video output queue. Wrapping it in Task {} adds scheduling overhead and can cause frame drops.

- **Putting AVCaptureSession on @MainActor:** Camera configuration and frame delivery are expensive. Keeping them on MainActor blocks UI. Use a dedicated CameraActor.

- **Using @Published + Combine instead of @Observable:** The project targets iOS 17+ with SwiftUI. @Observable is the modern pattern and avoids ObservableObject/Combine overhead.

- **Storing hold duration as a computed property from Date.now:** This forces constant recalculation. Instead, use a timer that increments a stored duration value at regular intervals.

- **Making HoldStateMachine a class or actor:** It's pure state transition logic. A value type (struct) is simpler, testable, and avoids concurrency complexity.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Body pose estimation | Custom CoreML model | Vision VNDetectHumanBodyPoseRequest | Apple's model runs on Neural Engine, is maintained, handles device variations; training a custom model requires thousands of labeled handstand frames |
| Camera preview rendering | Custom Metal/OpenGL preview | AVCaptureVideoPreviewLayer via UIViewRepresentable | Hardware-accelerated, handles orientation, aspect ratio, mirroring automatically |
| Video file frame extraction | Manual CMSampleBuffer parsing | AVAssetReader + AVAssetReaderTrackOutput | Handles codec decompression, timing, pixel format conversion; hand-rolling this is error-prone |
| Photo/video picker | Custom PHAsset browser | PHPickerViewController (PhotosUI) | Handles permissions, album navigation, iCloud download; no direct Photos access needed |
| Haptic feedback | Custom CoreHaptics patterns | UINotificationFeedbackGenerator / UIImpactFeedbackGenerator | System-standard patterns for success/warning/error; CoreHaptics only if custom patterns needed |
| Skeleton joint rendering | Manual CGContext drawing | SwiftUI Canvas with Path | Canvas is hardware-accelerated, integrates with SwiftUI, handles coordinate transforms |

**Key insight:** The detection pipeline (camera -> Vision -> classifier -> state machine) is the app's core value. Everything else (camera preview, haptics, video picker, persistence) should use the highest-level Apple API available.

## Common Pitfalls

### Pitfall 1: Vision Coordinate System Confusion

**What goes wrong:** Joints appear in wrong positions on screen; skeleton overlay is mirrored, flipped, or offset.

**Why it happens:** Vision returns points in normalized coordinates (0,0 at bottom-left, 1,1 at top-right) which differs from UIKit/SwiftUI coordinates (0,0 at top-left). Front camera is also mirrored.

**How to avoid:** Create a coordinate transform utility that:
1. Flips Y-axis (1.0 - y) for SwiftUI rendering
2. Accounts for front camera mirroring
3. Scales from normalized [0,1] to view dimensions
4. Handles device orientation

**Warning signs:** Skeleton overlay looks correct on rear camera but wrong on front camera, or joints are vertically inverted.

### Pitfall 2: Frame Processing Backpressure

**What goes wrong:** App becomes unresponsive; memory usage climbs; frames queue up faster than Vision can process them.

**Why it happens:** Vision body pose detection takes ~15-30ms per frame on modern devices. At 30fps, frames arrive every 33ms. If processing exceeds delivery rate, frames accumulate.

**How to avoid:**
- Set `alwaysDiscardsLateVideoFrames = true` on AVCaptureVideoDataOutput (already in pattern)
- Process frames synchronously on the video data output queue (do NOT dispatch to another queue)
- If needed, add explicit frame skipping (process every Nth frame)

**Warning signs:** Memory usage grows during session; Instruments shows increasing buffer count.

### Pitfall 3: AVCaptureSession Configuration Threading

**What goes wrong:** Crashes or undefined behavior when configuring AVCaptureSession.

**Why it happens:** AVCaptureSession.beginConfiguration/commitConfiguration must be called from the same thread. Mixing @MainActor calls with background configuration causes threading violations.

**How to avoid:** ALL AVCaptureSession configuration happens on CameraActor. Never touch it from @MainActor code. Use async/await to bridge: `await cameraManager.configure(position: .back)`.

**Warning signs:** Intermittent crashes in AVCaptureSession methods; "Session configuration failed" errors.

### Pitfall 4: SwiftData ModelContext Thread Safety

**What goes wrong:** Crashes when accessing SwiftData objects from wrong thread/actor.

**Why it happens:** SwiftData ModelContext is not Sendable. Each actor/thread needs its own ModelContext created from the shared ModelContainer.

**How to avoid:**
- Create ModelContext on @MainActor for UI reads
- For background writes (e.g., saving a hold from camera callback), create a new ModelContext on the background context or dispatch to MainActor
- Never pass @Model objects across actor boundaries; pass identifiers instead

**Warning signs:** "Accessing ModelContext from wrong thread" crashes; EXC_BAD_ACCESS in SwiftData internals.

### Pitfall 5: Debounce Threshold Tuning

**What goes wrong:** Phantom holds (false positives) or missed holds (false negatives).

**Why it happens:** Thresholds too low = any brief arm raise triggers timing. Thresholds too high = athlete must hold for >1s before timing starts, frustrating for short holds.

**How to avoid:**
- Start with 12-frame detection threshold (~0.4s at 30fps) and 10-frame loss threshold (~0.33s)
- Make thresholds configurable (not hard-coded) for easy tuning
- Use the video import tool (VIDU-01/02) to test against recorded handstand footage
- Plan for empirical tuning as a dedicated task

**Warning signs:** Users report timer "not starting" or "starting randomly."

### Pitfall 6: Camera Permission Denied with No Recovery

**What goes wrong:** App shows blank screen if camera permission is denied; user has no way to recover.

**Why it happens:** Developer only handles the "granted" path.

**How to avoid:**
- Check AVCaptureDevice.authorizationStatus(for: .video) before starting session
- Show clear explanation before requesting permission (in context, not at launch)
- If denied, show ContentUnavailableView with "Open Settings" button
- Handle .restricted status (parental controls)

**Warning signs:** App crashes or shows blank screen when permission is denied.

### Pitfall 7: Timer Drift with Date-Based Calculation

**What goes wrong:** Timer display shows slightly wrong values; timer "jumps" by visible amounts.

**Why it happens:** Using Date() calculations for display is subject to system clock adjustments and timer coalescing.

**How to avoid:**
- Use ContinuousClock (or CADisplayLink) for UI timer updates
- Store the hold start time from ContinuousClock.now, not Date()
- Update display at 10Hz (every 100ms) -- 1Hz is too choppy for a timer, 60Hz is wasteful

**Warning signs:** Timer shows values like 0.0, 0.0, 0.2, 0.2, 0.4 instead of smooth progression.

## Code Examples

### Camera Permission Flow

```swift
func requestCameraAccess() async -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
        return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .video)
    case .denied, .restricted:
        return false
    @unknown default:
        return false
    }
}
```

### SwiftData Model Definitions

```swift
import SwiftData

@Model
final class Session {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var holds: [Hold]

    init(id: UUID = UUID(), startDate: Date = Date()) {
        self.id = id
        self.startDate = startDate
        self.holds = []
    }
}

@Model
final class Hold {
    var id: UUID
    var duration: TimeInterval
    var startDate: Date
    var skill: String            // "handstand" for Phase 1
    var cameraPosition: String   // "front" or "back"
    var session: Session?

    init(
        id: UUID = UUID(),
        duration: TimeInterval,
        startDate: Date,
        skill: String = "handstand",
        cameraPosition: String
    ) {
        self.id = id
        self.duration = duration
        self.startDate = startDate
        self.skill = skill
        self.cameraPosition = cameraPosition
    }
}

@Model
final class SkillPersonalBest {
    @Attribute(.unique) var skill: String
    var bestDuration: TimeInterval
    var achievedDate: Date

    init(skill: String, bestDuration: TimeInterval, achievedDate: Date) {
        self.skill = skill
        self.bestDuration = bestDuration
        self.achievedDate = achievedDate
    }
}
```

### Haptic Alert at Target Duration

```swift
struct HapticManager {
    static func playTargetReached() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func playHoldDetected() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}
```

### Camera Preview (UIViewRepresentable)

```swift
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
```

### Skeleton Overlay with Canvas

```swift
struct SkeletonOverlayView: View {
    let points: [VNHumanBodyPoseObservation.JointName: CGPoint]  // Already in view coordinates
    let isVisible: Bool

    // Define bone connections
    private let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .rightShoulder),
        (.leftHip, .rightHip),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        if isVisible {
            Canvas { context, size in
                // Draw bones
                for (from, to) in bones {
                    guard let p1 = points[from], let p2 = points[to] else { continue }
                    var path = Path()
                    path.move(to: p1)
                    path.addLine(to: p2)
                    context.stroke(path, with: .color(.green), lineWidth: 2)
                }
                // Draw joints
                for (_, point) in points {
                    let rect = CGRect(
                        x: point.x - 4, y: point.y - 4,
                        width: 8, height: 8
                    )
                    context.fill(Circle().path(in: rect), with: .color(.yellow))
                }
            }
        }
    }
}
```

### Video Import with PHPicker

```swift
import PhotosUI

struct VideoPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPickerView

        init(_ parent: VideoPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            else { return }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url else { return }
                // Copy to temp directory (provider's URL is temporary)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                try? FileManager.default.copyItem(at: url, to: tempURL)
                Task { @MainActor in
                    self.parent.selectedURL = tempURL
                }
            }
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| VNDetectHumanBodyPoseRequest (iOS 14) | Same API, improved accuracy in iOS 17+ | iOS 17 (2023) | Better joint detection, especially for unusual poses |
| ObservableObject + @Published | @Observable macro | iOS 17 / Swift 5.9 | Less boilerplate, better performance, fine-grained observation |
| Core Data | SwiftData | iOS 17 (2023) | Swift-native, simpler API, built-in CloudKit sync support |
| DispatchQueue-based concurrency | Swift structured concurrency + actors | Swift 5.5+ (2021), strict in 6.0 | Compile-time data race safety |
| VNImageRequestHandler per frame | VNImageRequestHandler per frame (still correct for body pose) | Current | VNSequenceRequestHandler is for tracking, not body pose |

**Deprecated/outdated:**
- **Core Data:** Replaced by SwiftData for new projects targeting iOS 17+.
- **ObservableObject/Combine:** Replaced by @Observable macro for SwiftUI. Still works but adds unnecessary complexity.
- **DispatchQueue.main.async for UI updates:** Use @MainActor instead.
- **UIImagePickerController for video selection:** Use PHPickerViewController (PhotosUI).

## Open Questions

1. **HandstandClassifier threshold values**
   - What we know: Geometric approach (feet above head) is correct. Need minVerticalSeparation, maxHorizontalOffset, minJointConfidence values.
   - What's unclear: Exact numeric values that balance precision vs recall across different body types, distances from camera, and lighting conditions.
   - Recommendation: Start with conservative defaults (0.15 vertical separation, 0.25 horizontal offset, 0.3 confidence). Build the video import tool early (Plan 01-06) so thresholds can be tuned against real footage. Make all thresholds configurable.

2. **Detection accuracy acceptance criteria**
   - What we know: Need a concrete pass/fail threshold before Phase 1 is "done."
   - What's unclear: What false positive / false negative rate is acceptable for athletes.
   - Recommendation: Define as "correctly detects and times >= 90% of handstand holds in a 50-frame test corpus, with < 5% phantom hold rate." Build corpus from video import tool output.

3. **Device orientation handling**
   - What we know: App needs to work with phone propped on a stand (CAMR-02). Vision coordinates assume a specific image orientation.
   - What's unclear: Whether to lock to portrait or handle multiple orientations; how UIDevice.orientation interacts with AVCaptureConnection.videoOrientation and Vision coordinate transforms.
   - Recommendation: Lock to portrait for Phase 1. Most phone stands hold the phone vertically. Set AVCaptureConnection.videoOrientation = .portrait explicitly. Defer landscape support.

4. **iOS version target discrepancy**
   - What we know: PROJECT.md says iOS 17+. Plugin system prompt says iOS 26.0+. SwiftData requires iOS 17+.
   - What's unclear: Whether to target iOS 17+ (wider reach) or iOS 26+ (latest APIs).
   - Recommendation: Target iOS 17+ as stated in PROJECT.md. This provides maximum device coverage and all required APIs (Vision body pose, SwiftData, @Observable) are available from iOS 17.

## Sources

### Primary (HIGH confidence)
- Apple Vision Framework Documentation -- VNDetectHumanBodyPoseRequest, VNHumanBodyPoseObservation, recognized joint names and coordinate system
- Apple AVFoundation Documentation -- AVCaptureSession, AVCaptureVideoDataOutput, AVAssetReader configuration
- Apple SwiftData Documentation -- @Model, ModelContainer, ModelContext usage patterns
- Swift Evolution SE-0395 -- @Observable macro specification
- Plugin skill references: modern-swift, composable-architecture, sqlite-data, ios-hig (feedback, privacy-permissions)

### Secondary (MEDIUM confidence)
- Prior project research (STATE.md decisions) -- Geometric classifier rationale, VNSequenceRequestHandler recommendation, CameraActor pattern
- WWDC sessions on Vision body pose (WWDC 2020/2023) -- General approach and best practices

### Tertiary (LOW confidence)
- HandstandClassifier threshold values -- No empirical source; values are educated guesses that require validation with real footage
- VNSequenceRequestHandler vs VNImageRequestHandler for body pose -- Prior research recommended sequence handler but body pose requests don't benefit from temporal tracking the same way object tracking does

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All first-party Apple frameworks with well-documented APIs; zero external dependencies simplifies the picture
- Architecture: HIGH -- CameraActor pattern is well-established for AVCaptureSession in Swift concurrency; state machine is a straightforward value type
- Pitfalls: HIGH -- Camera threading, Vision coordinates, and frame backpressure are well-documented problems with known solutions
- Classifier thresholds: LOW -- Numeric values are guesses; must be validated empirically
- SwiftData thread safety: MEDIUM -- SwiftData's actor isolation model is newer and less battle-tested than Core Data's; worth extra testing

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (stable first-party frameworks; no fast-moving dependencies)
