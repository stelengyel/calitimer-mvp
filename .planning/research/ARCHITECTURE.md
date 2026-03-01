# Architecture Research

**Domain:** iOS real-time pose estimation + video capture app (calisthenics hold timer)
**Researched:** 2026-03-01
**Confidence:** HIGH (Apple documentation, WWDC sessions, verified patterns)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                           │
│  ┌──────────────────┐  ┌────────────────┐  ┌──────────────────────┐ │
│  │  SessionView     │  │  CameraView    │  │  HistoryView         │ │
│  │  (@Observable)   │  │  (UIViewRep.)  │  │  (SwiftData query)   │ │
│  └────────┬─────────┘  └───────┬────────┘  └──────────────────────┘ │
│           │                    │                                      │
├───────────┼────────────────────┼──────────────────────────────────── │
│                         COORDINATION LAYER                           │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  SessionCoordinator (@MainActor, @Observable)                  │  │
│  │  Owns: hold state, timer state, session metadata, routing      │  │
│  └──────┬──────────────┬───────────────────┬──────────────────────┘  │
│         │              │                   │                          │
├─────────┼──────────────┼───────────────────┼──────────────────────── │
│                         PIPELINE LAYER                               │
│  ┌──────┴──────┐  ┌────┴──────────┐  ┌────┴──────────────────────┐  │
│  │ CameraActor │  │ PoseDetector  │  │ HoldStateMachine           │  │
│  │ (GlobalAct) │  │ (background   │  │ (@MainActor)               │  │
│  │ AVCapture   │  │  dispatch Q)  │  │ searching→detected→timing  │  │
│  │ + PreviewL. │  │ Vision/VN*    │  │ →hold_ended                │  │
│  └──────┬──────┘  └────┬──────────┘  └────┬──────────────────────┘  │
│         │              │                   │                          │
│  ┌──────┴──────┐  ┌────┴──────────┐  ┌────┴──────────────────────┐  │
│  │ Recorder    │  │ SkeletonRender │  │ HoldTimer                  │  │
│  │ (own Actor) │  │ (CAShapeLayer) │  │ (DisplayLink/AsyncStream) │  │
│  │ circular    │  │               │  │                            │  │
│  │ pre-buffer  │  │               │  │                            │  │
│  └──────┬──────┘  └───────────────┘  └────────────────────────────┘  │
│         │                                                              │
├─────────┼──────────────────────────────────────────────────────────── │
│                         STORAGE LAYER                                │
│  ┌──────┴──────────────────┐  ┌─────────────────────────────────┐   │
│  │ SwiftData Store          │  │ FileManager (temp video clips)  │   │
│  │ Session, Hold, SkillPB   │  │ .tmp → camera roll (Photos)     │   │
│  └─────────────────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `CameraActor` | Owns `AVCaptureSession`, manages inputs/outputs, delivers `CMSampleBuffer` to subscribers | Swift GlobalActor wrapping AVFoundation; `AVCaptureVideoDataOutput` delegate |
| `PoseDetector` | Runs `DetectHumanBodyPoseRequest` on each frame buffer; returns joint positions + confidence | Runs on `videoDataOutputQueue`; Vision framework (iOS 17+ new API without `VN` prefix) |
| `HoldStateMachine` | Classifies pose as hold/not-hold using evidence accumulation; emits state transitions | `@MainActor @Observable` class; counts frames meeting threshold before transitioning |
| `HoldTimer` | Tracks elapsed time during a confirmed hold; publishes updates to UI | `CADisplayLink` or `AsyncStream` publishing `TimeInterval` on `@MainActor` |
| `Recorder` | Maintains circular pre-roll buffer; writes confirmed hold to temp file via `AVAssetWriter` | Isolated Actor receiving `CMSampleBuffer`; ring buffer of deep-copied pixel buffers |
| `SkeletonRenderer` | Draws joint overlay on camera preview as `CAShapeLayer` sublayer | Runs on `@MainActor`; redraws on pose update; toggled on/off via boolean |
| `SessionCoordinator` | Orchestrates the full live session: wires components, owns session record, routes events | `@MainActor @Observable`; receives state machine transitions; triggers recording start/stop |
| `SwiftData Store` | Persists `Session`, `Hold`, and `SkillPersonalBest` model objects | `@Model` classes; `ModelContainer` configured at app level |
| `VideoUploadPipeline` | Runs identical detection logic against an `AVAsset` imported via `PHPickerViewController` | `AVAssetReader` → frame loop → same `PoseDetector` + `HoldStateMachine` (reused); no `Recorder` needed — clips trimmed from source asset |

## Recommended Project Structure

```
CaliTimer/
├── App/
│   ├── CaliTimerApp.swift        # App entry, ModelContainer setup
│   └── AppCoordinator.swift      # Root navigation state
├── Camera/
│   ├── CameraActor.swift         # AVCaptureSession actor
│   ├── CameraPreviewView.swift   # UIViewRepresentable wrapping AVCaptureVideoPreviewLayer
│   └── SkeletonRenderer.swift    # CAShapeLayer overlay, coordinate conversion
├── Pose/
│   ├── PoseDetector.swift        # DetectHumanBodyPoseRequest runner
│   ├── PoseObservation.swift     # Value type wrapping joint positions + confidence
│   ├── HandstandClassifier.swift # Skill-specific geometry rules (wrists above hips, body vertical)
│   └── HoldStateMachine.swift    # Evidence accumulation, state enum, transitions
├── Session/
│   ├── SessionCoordinator.swift  # @Observable orchestrator (live mode)
│   ├── HoldTimer.swift           # CADisplayLink-based elapsed timer
│   └── Recorder.swift            # Pre-roll circular buffer + AVAssetWriter actor
├── Upload/
│   ├── VideoUploadCoordinator.swift  # @Observable orchestrator (upload mode)
│   └── VideoFrameReader.swift        # AVAssetReader frame extractor
├── Storage/
│   ├── Models/
│   │   ├── Session.swift         # @Model: start/end time, skill, holds
│   │   ├── Hold.swift            # @Model: duration, timestamp, clipURL, kept flag
│   │   └── SkillPersonalBest.swift  # @Model: skill enum, bestDuration, date
│   └── StorageService.swift      # SwiftData insert/query helpers
├── UI/
│   ├── LiveSession/
│   │   ├── LiveSessionView.swift
│   │   ├── HoldTimerOverlay.swift
│   │   ├── StateIndicatorView.swift
│   │   └── TargetDurationControl.swift
│   ├── ClipReview/
│   │   └── ClipReviewView.swift  # Keep/discard sheet
│   ├── History/
│   │   └── HistoryView.swift
│   └── Upload/
│       └── UploadModeView.swift
└── Shared/
    ├── HapticService.swift
    ├── PermissionsService.swift
    └── SkillDefinition.swift     # Skill enum, pose signature specs
```

### Structure Rationale

- **Camera/:** Isolates all AVFoundation code. `CameraActor` never imported by UI; only by `SessionCoordinator`.
- **Pose/:** Detection and classification are separate. `PoseDetector` is pure Vision code; `HandstandClassifier` holds the geometric business logic. New skills in Phase 2 add classifiers here without touching detection.
- **Session/** vs **Upload/:** Both coordinators call the same `Pose/` and `Storage/` code but wire up inputs differently (live camera vs. file reader). No conditional branching inside detection code.
- **Storage/:** `@Model` classes are thin; business logic stays in coordinators.

## Architectural Patterns

### Pattern 1: Actor-Per-Concern Threading

**What:** Each subsystem that has its own threading needs runs in a Swift actor. `CameraActor` (custom GlobalActor) handles AVFoundation's GCD callbacks. `Recorder` runs on its own isolated actor. `SessionCoordinator` and all `@Observable` models are `@MainActor`.

**When to use:** Everywhere in this app. AVFoundation is GCD-based; Swift 6 strict concurrency requires explicit actor boundaries.

**Trade-offs:** Some boilerplate for `nonisolated` delegate methods; pays back in compiler-enforced thread safety and no data races.

**Example:**
```swift
@globalActor
actor CameraGlobalActor {
    static let shared = CameraGlobalActor()
}

@CameraGlobalActor
final class CameraActor {
    private let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()

    func startSession() {
        session.startRunning()  // safe — on camera actor
    }
}
```

### Pattern 2: Evidence Accumulation State Machine

**What:** Apple's WWDC20 recommended pattern for pose classification. Instead of triggering on any single frame, accumulate N consecutive frames that meet the classification criteria before transitioning state. Reset counters on contradiction.

**When to use:** Hold detection entry and exit. Prevents noise-induced false starts/stops that would create phantom holds.

**Trade-offs:** Introduces a deliberate latency equal to (N frames / FPS). At 30 fps and N=6, that is ~200ms — imperceptible to athletes.

**Example:**
```swift
@MainActor @Observable
final class HoldStateMachine {
    enum State { case searching, possibleHold, timing, possibleEnd }

    var state: State = .searching
    private var holdEvidence = 0
    private var endEvidence = 0
    private let requiredFrames = 6   // ~200ms at 30fps

    func process(observation: PoseObservation) {
        let isHolding = HandstandClassifier.classify(observation)

        if isHolding {
            holdEvidence += 1
            endEvidence = 0
            if holdEvidence >= requiredFrames, state == .searching || state == .possibleHold {
                state = (holdEvidence >= requiredFrames) ? .timing : .possibleHold
            }
        } else {
            endEvidence += 1
            holdEvidence = 0
            if endEvidence >= requiredFrames, state == .timing || state == .possibleEnd {
                state = .searching
            }
        }
    }
}
```

### Pattern 3: Circular Pre-Roll Buffer

**What:** The `Recorder` actor maintains a fixed-size ring buffer of deep-copied `CMSampleBuffer`s (deep copy required — native CMSampleBuffers are pooled and cannot be retained directly). When a hold is confirmed, the recorder writes the buffered pre-roll frames first, then continues capturing live until hold end.

**When to use:** Any app that needs recording to appear to start before the triggering event. For CaliTimer, a 2-second pre-roll ensures the approach/setup is captured.

**Trade-offs:** Memory cost of the ring buffer. At 30fps × 2s × ~90KB/frame (720p), that is ~5.4MB — acceptable. Must deep-copy via `CVPixelBuffer` copy because retaining `CMSampleBuffer` exhausts the capture pool and drops frames.

**Example:**
```swift
actor Recorder {
    private var preRollBuffer: [CMSampleBuffer] = []
    private let preRollCapacity = 60  // 2s at 30fps
    private var assetWriter: AVAssetWriter?

    func appendBuffer(_ buffer: CMSampleBuffer) {
        let copy = buffer.deepCopy()  // required: avoids pool exhaustion
        if preRollBuffer.count >= preRollCapacity {
            preRollBuffer.removeFirst()
        }
        preRollBuffer.append(copy)

        if isRecording {
            assetWriter?.append(copy)
        }
    }

    func startRecording(outputURL: URL) {
        // flush pre-roll frames first, then continue live
        for preRollFrame in preRollBuffer {
            assetWriter?.append(preRollFrame)
        }
        isRecording = true
    }
}
```

### Pattern 4: Shared Pipeline, Dual Input Sources

**What:** `PoseDetector` and `HoldStateMachine` are input-agnostic — they accept `CMSampleBuffer` regardless of origin. `SessionCoordinator` feeds live camera buffers; `VideoUploadCoordinator` feeds `AVAssetReader` output buffers. The detection code is identical.

**When to use:** Video upload mode. Reuse 100% of detection logic with no conditionals.

**Trade-offs:** `VideoUploadCoordinator` must match the live framerate behavior (throttle or process at full speed with playback simulation). No `Recorder` needed in upload mode — clips are trimmed from the source asset at detected timestamps.

**Example:**
```swift
// Live mode
cameraActor.onFrame = { [weak coordinator] buffer in
    Task { await coordinator?.processSampleBuffer(buffer) }
}

// Upload mode — AVAssetReader loop
while let buffer = assetReaderOutput.copyNextSampleBuffer() {
    await uploadCoordinator.processSampleBuffer(buffer)
}
```

## Data Flow

### Live Camera Frame Pipeline

```
AVCaptureSession (CameraGlobalActor)
    │  CMSampleBuffer @ 30fps (videoDataOutputQueue)
    ▼
PoseDetector (background dispatch queue)
    │  DetectHumanBodyPoseRequest.perform()
    │  → PoseObservation (joint dict + confidence)
    ▼
HoldStateMachine (@MainActor)
    │  evidence accumulation → state transition
    │  .searching → .timing  (hold confirmed)
    │  .timing → .searching  (hold broken)
    ▼
    ├──→ SessionCoordinator (@MainActor)
    │       starts/stops HoldTimer
    │       triggers haptic alert at target duration
    │       saves Hold record to SwiftData on end
    │
    └──→ Recorder (own Actor)
            on .timing: flush pre-roll + begin writing
            on .searching: stop writing → temp .mov file
            → emits URL to SessionCoordinator for review sheet
```

### Skeleton Overlay Flow

```
PoseObservation (from PoseDetector)
    │  normalized Vision coordinates (0,0 bottom-left)
    ▼
SkeletonRenderer (@MainActor)
    │  convert to view space: VNImagePointForNormalizedPoint()
    │  (flip Y-axis: Vision origin is bottom-left, UIKit top-left)
    ▼
CAShapeLayer (sublayer above AVCaptureVideoPreviewLayer)
    │  draw joints as circles, bones as lines
    │  toggled via SessionCoordinator.showSkeleton bool
```

### Video Upload Pipeline

```
PHPickerViewController
    │  user picks video → URL via loadFileRepresentation()
    ▼
VideoUploadCoordinator (@Observable, @MainActor)
    │  creates AVAssetReader → AVAssetReaderTrackOutput
    │  (kCVPixelFormatType_420YpCbCr8BiPlanarFullRange for Vision)
    ▼
Frame Loop (background Task / actor)
    │  copies CMSampleBuffer per frame
    │  same PoseDetector + HoldStateMachine used as live mode
    ▼
HoldStateMachine → timestamps of hold start/end
    ▼
AVAssetExportSession
    trimmed clips per hold using CMTimeRange
    (no Recorder actor needed — trim from source)
    ▼
ClipReviewView (same UI as live mode)
```

### State Management

```
SessionCoordinator (@Observable, @MainActor)
    ├── detectionState: DetectionState     // published to StateIndicatorView
    ├── holdDuration: TimeInterval         // published to HoldTimerOverlay
    ├── targetDuration: TimeInterval       // user sets via TargetDurationControl
    ├── showSkeleton: Bool                 // skeleton overlay toggle
    └── pendingClipURL: URL?               // set when hold ends → triggers review sheet
```

## Anti-Patterns

### Anti-Pattern 1: Running Pose Estimation on the Main Thread

**What people do:** Call `VNImageRequestHandler.perform()` inside `captureOutput(_:didOutput:)` on whatever queue it arrives on — often dispatched to main for SwiftUI state updates.

**Why it's wrong:** Vision inference takes 10-30ms per frame. At 30fps there is 33ms budget. Blocking `@MainActor` freezes the UI and starves the camera pipeline, causing frame drops and missed holds.

**Do this instead:** Keep `PoseDetector` on the dedicated `videoDataOutputQueue` (serial background queue). When detection is complete, use `Task { @MainActor in ... }` to update only the `@Observable` state properties that drive UI.

### Anti-Pattern 2: Retaining CMSampleBuffer Directly in Pre-Roll Array

**What people do:** `preRollBuffer.append(sampleBuffer)` using the AVFoundation-vended buffer directly.

**Why it's wrong:** `CMSampleBuffer`s come from a fixed-size system memory pool. Retaining them prevents the pool from being reclaimed. After a few seconds the pool exhausts and `captureOutput` stops receiving new frames silently.

**Do this instead:** Deep-copy via `CVPixelBufferGetBaseAddress` copy or `CMSampleBufferCreateCopy` into a new backing allocation before storing. Release originals immediately.

### Anti-Pattern 3: AVCaptureMovieFileOutput for This App

**What people do:** Use `AVCaptureMovieFileOutput` because it's simpler — no `AVAssetWriter` required.

**Why it's wrong:** `AVCaptureMovieFileOutput` writes continuously. It cannot implement a pre-roll buffer, cannot access frames for pose estimation simultaneously, and cannot start a file mid-session based on a trigger. It is the wrong primitive.

**Do this instead:** `AVCaptureVideoDataOutput` for frame access + `AVAssetWriter` for recording. Both can run simultaneously off the same `AVCaptureSession`.

### Anti-Pattern 4: One ViewModel to Rule Them All

**What people do:** A single `CameraViewModel` manages the session, runs inference, owns recording state, and publishes UI state — all in one class.

**Why it's wrong:** Camera operations are GCD-based, inference is on a background queue, and UI must be on `@MainActor`. Mixing these without actor boundaries causes data races under Swift 6 strict concurrency, and the class becomes untestable.

**Do this instead:** `CameraActor` → `PoseDetector` → `HoldStateMachine` → `SessionCoordinator` — each with its own concurrency domain. Coordinator is `@MainActor` and `@Observable`; UI binds to it directly.

### Anti-Pattern 5: Running DetectHumanBodyPoseRequest on Every Frame in Upload Mode Without Throttling

**What people do:** Loop `AVAssetReader` as fast as possible and run Vision on every buffer.

**Why it's wrong:** `AVAssetReader` reads faster than real-time. Running full Vision inference on every frame of a 10-minute training video will take many seconds and peg the CPU, blocking the UI.

**Do this instead:** Sample frames at the live-session rate (every 33ms of video time, i.e., skip frames based on `CMSampleBufferGetPresentationTimeStamp`). Run inference on sampled frames only. Report progress to UI via async stream.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `CameraActor` → `PoseDetector` | Direct call passing `CMSampleBuffer`; detector runs on same `videoDataOutputQueue` | Keep on same queue — Vision is not thread-safe across concurrent calls to same handler |
| `PoseDetector` → `HoldStateMachine` | `Task { @MainActor in stateMachine.process(observation) }` | Hop to main actor for state mutation; structured concurrency |
| `HoldStateMachine` → `Recorder` | `Task { await recorder.startRecording() }` or `stopRecording()` | Recorder is isolated actor — await for handoff |
| `Recorder` → `SessionCoordinator` | Async callback / `AsyncStream<URL>` emitting clip URL on hold completion | Coordinator receives URL, sets `pendingClipURL` to trigger review sheet |
| `SessionCoordinator` → SwiftData | Direct `modelContext.insert()` on `@MainActor` | SwiftData `ModelContext` is `@MainActor`-bound |
| `VideoUploadCoordinator` → `PoseDetector` | Same interface as live mode | No structural change to detector; coordinator drives the frame loop |
| `VideoUploadCoordinator` → `AVAssetExportSession` | Coordinator collects `[CMTimeRange]` from state machine, trims source asset | Export is async; progress reported to upload view |

### External APIs

| API | How Used | Notes |
|-----|----------|-------|
| `AVFoundation` (AVCaptureSession, AVAssetWriter, AVAssetReader) | Camera capture, recording, upload frame extraction | Session configuration must be on background thread |
| `Vision` (DetectHumanBodyPoseRequest — iOS 17 new API without `VN` prefix) | Body pose detection per frame | New async API with Swift 6 support; use `perform()` on `ImageRequestHandler` |
| `SwiftData` | Session/hold persistence | `@Model` classes, `ModelContainer` at app root, `@MainActor` context |
| `Photos` / `PHPickerViewController` | Video import for upload mode, save kept clips to camera roll | Use `loadFileRepresentation` for video URLs; `PHPhotoLibrary.shared().performChanges` for save |
| `CoreHaptics` / `UIFeedbackGenerator` | Target duration alert, hold confirmation feedback | Simple haptic; `UIImpactFeedbackGenerator` is sufficient |

## Scalability Considerations

This is a local, single-device app. "Scalability" means handling longer sessions and multiple skills without performance degradation.

| Concern | Mitigation |
|---------|------------|
| Long session → many `Hold` SwiftData records | `@Query` with predicate to fetch only current session; no full table scans |
| Multiple skills (Phase 2) | `HandstandClassifier` is one file; new skills add sibling files. `HoldStateMachine` accepts a `SkillClassifier` protocol — no changes to state logic |
| High-res video pre-roll memory | Cap pre-roll at 2s; cap recording resolution to 1080p (not 4K); ~5-6MB ring buffer |
| Upload mode on large video files | Frame sampling (process 1 in N frames based on presentation timestamp); progress reporting via `AsyncStream` to prevent UI lockup |

## Build Order Implications

The architecture has clear dependency layers. Build in this order to avoid rework:

1. **`CameraActor` + `CameraPreviewView`** — foundational; everything depends on frame delivery
2. **`PoseDetector`** — needs camera frames; output is the input to everything else
3. **`HandstandClassifier` + `HoldStateMachine`** — needs pose observations; defines the hold boundary
4. **`HoldTimer` + `SessionCoordinator` (skeleton)** — needs state machine transitions; drives UI state
5. **`Recorder` + pre-roll buffer** — needs camera frames + state machine; complex; isolated actor simplifies testing
6. **`SkeletonRenderer`** — needs pose observations + preview layer; cosmetic, can be added late
7. **SwiftData models + `StorageService`** — can be scaffolded early but only wired once coordinator is stable
8. **`VideoUploadCoordinator` + `VideoFrameReader`** — last; reuses all of 2–4; only new code is frame extraction and clip trimming

**Key dependency:** `Recorder`'s pre-roll correctness depends on a working `HoldStateMachine` that fires precisely — build and test state machine with unit tests before integrating recording.

## Sources

- [Detect Body and Hand Pose with Vision — WWDC20 (Apple)](https://developer.apple.com/videos/play/wwdc2020/10653/) — evidence accumulation pattern, ring buffer for pose observations, confidence thresholds (HIGH confidence)
- [Discover Swift enhancements in the Vision framework — WWDC24 (Apple)](https://developer.apple.com/videos/play/wwdc2024/10163/) — new async/await API without `VN` prefix, `DetectHumanBodyPoseRequest`, `performAll()` (HIGH confidence)
- [Capturing Video on iOS — objc.io](https://www.objc.io/issues/23-video/capturing-video/) — AVCaptureSession + AVAssetWriter architecture, threading model (MEDIUM confidence, older but pattern is stable)
- [Swift 6 Refactoring in a Camera App — fatbobman.com](https://fatbobman.com/en/posts/swift6-refactoring-in-a-camera-app/) — actor-per-concern pattern, CameraActor GlobalActor, nonisolated delegates (HIGH confidence, current)
- [Detecting body poses in a live video feed — createwithswift.com](https://www.createwithswift.com/detecting-body-poses-in-a-live-video-feed/) — end-to-end component wiring, delegate pattern, coordinate conversion (MEDIUM confidence)
- [AVCaptureSession — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturesession) — canonical session configuration (HIGH confidence)
- [AVAssetWriter — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avassetwriter) — writer lifecycle, startWriting/finishWriting pattern (HIGH confidence)
- CMSampleBuffer deep copy requirement — multiple Apple Developer Forum threads confirming pool exhaustion behavior (MEDIUM confidence, consistent across sources)

---
*Architecture research for: iOS real-time pose estimation + circular-buffer video recording (CaliTimer)*
*Researched: 2026-03-01*
