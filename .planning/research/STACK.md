# Stack Research

**Domain:** iOS on-device real-time pose estimation timer app (calisthenics / handstand detection)
**Researched:** 2026-03-01
**Confidence:** MEDIUM-HIGH (Apple-native stack is HIGH; pose estimation framework decision carries some LOW-confidence elements on inverted-pose accuracy)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.0 (Xcode 16+) | Primary language | Swift 6 concurrency required to safely use the new Vision async API and AVFoundation on actor-isolated queues; no real alternative on iOS |
| SwiftUI | iOS 17+ | All UI, camera overlay, session screen | @Observable macro (iOS 17) eliminates ObservableObject boilerplate; declarative layout composes cleanly with ZStack overlay for skeleton rendering; UIKit only needed for AVCaptureVideoPreviewLayer via UIViewRepresentable |
| Vision (Apple) | iOS 17+ (legacy VN API); iOS 18+ (new Swift async API) | Body pose detection | First-party, zero dependency, Neural Engine accelerated, no CocoaPods, no third-party model distribution risk. VNDetectHumanBodyPoseRequest detects 19 joints. The new WWDC24 Swift API (DetectHumanBodyPoseRequest with async/await) is available from iOS 18; the VN-prefixed legacy API works from iOS 14. Since target is iOS 17+, use legacy API on iOS 17, new API on iOS 18+, or target iOS 18+ to simplify. See decision note below. |
| AVFoundation | iOS 17+ | Camera capture, video recording, pre-roll buffer | The only way to get raw CMSampleBuffers for feeding Vision requests frame-by-frame and for custom AVAssetWriter recording. AVCaptureMovieFileOutput does not support simultaneous Vision frame processing. |
| SwiftData | iOS 17+ | Session history, hold records, personal bests | iOS 17+ project + no iCloud sync + simple data model (sessions with holds) = SwiftData is appropriate. Core Data is overkill for this model complexity. Limitations (complex predicates, enum filtering) do not affect CaliTimer's data access patterns. |
| Observation (Swift Observation framework) | iOS 17+ | Reactive state across CameraManager, PoseDetector, SessionManager | @Observable macro replaces ObservableObject/Combine for view-model binding; iOS 17+ guarantees it is available; more granular than @StateObject (only re-renders on properties actually read) |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVAssetWriter + VideoToolbox | Built-in | Frame-by-frame video encoding into a rolling pre-roll buffer | Use for the automatic hold clip capture feature: maintain a N-second rolling buffer of compressed frames; on hold-start, begin saving; on hold-end, finalize the clip. VideoToolbox hardware-encodes frames before they enter the circular buffer to keep memory manageable. |
| XCTest | Built-in (Xcode 16) | Unit tests for pose classification logic, session data model, hold detection state machine | Use for all logic that can be exercised with static image inputs or synthetic joint data — no camera required |
| Swift Testing (swift-testing) | Built-in (Xcode 16) | Modern test suite alongside XCTest | Swift Testing's `#expect` and parameterized tests are cleaner for table-driven tests of angle thresholds and state-machine transitions; works alongside XCTest |
| PhotosUI (PHPickerViewController) | Built-in | Video import from camera roll (Video Upload Mode feature) | Use when building Video Upload Mode: PHPickerViewController is the modern replacement for UIImagePickerController for accessing Photos library |
| Photos (PHPhotoLibrary) | Built-in | Saving kept clips to camera roll | Required to write video to camera roll; request `.addOnly` authorization (iOS 14+) to minimize permission scope |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | IDE, simulator, Instruments | Required for Swift 6 and new Vision async API compilation |
| Instruments → Core Animation, Time Profiler | Profile frame-drop during simultaneous Vision + AVAssetWriter | Run on physical device; simulators cannot exercise Neural Engine |
| xcrun simctl | Script test runs in CI | Use for logic-only tests that do not require camera |
| Swift Package Manager | Dependency management | No CocoaPods needed — the entire recommended stack is first-party or SPM-native. If MediaPipe is ever reconsidered, it requires CocoaPods, which complicates build setup. |

---

## Pose Estimation Framework Decision (Critical)

**Recommendation: Apple Vision `VNDetectHumanBodyPoseRequest` (legacy) for iOS 17 target; migrate to `DetectHumanBodyPoseRequest` async API when dropping iOS 17 support.**

### Why Apple Vision over MediaPipe

**MediaPipe BlazePose fundamental limitation for handstands:**
MediaPipe's person detector was trained on normally-oriented humans in typical exercise contexts (yoga, dance, HIIT). Its orientation anchor is based on hip midpoint and face-to-hip incline angle. For a handstand where the body is fully inverted, the detector's orientation model degrades significantly — the model was not trained on upside-down humans and the "face as proxy for person location" initialization fails on an inverted athlete. This is a documented architectural constraint, not a workaround-able configuration issue.

**Apple Vision behavior for inverted poses:**
VNDetectHumanBodyPoseRequest does not rely on face detection as an anchor. It returns normalized joint coordinates that are frame-relative, not orientation-normalized. For a handstand, wrists will appear at the bottom of the frame and ankles at the top — which is exactly what you need to compute an "inverted upright body" condition via joint geometry. The downstream handstand-detection logic (compare wrist y-coordinate < ankle y-coordinate, check body vertical alignment angle) works reliably from raw joint positions regardless of orientation.

**Integration advantage:**
Apple Vision is a first-party framework, Neural Engine accelerated, zero external dependency, no CocoaPods, no model distribution size cost, and integrates directly with CMSampleBuffer output from AVCaptureVideoDataOutput without format conversion.

**Accuracy tradeoff acknowledged:**
A benchmark on the Yoga dataset shows BlazePose at 45.0 mAP vs Apple Vision at 32.8 mAP for general pose accuracy. For CaliTimer's narrow use case (one static skill, one person, detect "body is inverted and vertical"), lower general-purpose mAP is acceptable. The handstand detection algorithm does not need precise knee angle — it needs coarse wrist/ankle/shoulder/hip alignment that Vision delivers reliably.

**The new Vision async API:**
WWDC24 introduced `DetectHumanBodyPoseRequest` (no VN prefix) with async/await and holistic body+hand detection in a single request (iOS 18+). This is the forward-looking API. Since CaliTimer targets iOS 17+, use `VNDetectHumanBodyPoseRequest` now and plan an iOS 18+ migration to the new API in a future phase. The migration is mechanical (remove VN prefix, replace callbacks with async/await).

### MediaPipe: when it would be right

Use MediaPipe if you need: cross-platform (iOS + Android), 33-landmark precision (e.g., finger tracking), or general-pose yoga scoring against a large dataset. None of these apply to CaliTimer.

### CoreML custom model: when it would be right

Use a custom CoreML model if Apple Vision detection accuracy for handstands proves insufficient after phase 1 testing and you need fine-tuned inverted-pose detection. This is a Phase 2 fallback, not a Phase 1 requirement. Custom model requires training data, Create ML or PyTorch + coremltools pipeline, and model versioning. Avoid unless Vision detection is proven insufficient.

---

## UI Architecture: SwiftUI with UIViewRepresentable for camera preview

**Recommendation: SwiftUI with one UIViewRepresentable wrapping AVCaptureVideoPreviewLayer.**

SwiftUI cannot natively host an `AVCaptureVideoPreviewLayer`. The correct pattern is:
1. `CameraPreviewView: UIViewRepresentable` — wraps a `UIView` with an `AVCaptureVideoPreviewLayer` sublayer
2. Rendered in a SwiftUI `ZStack` as the bottom layer
3. Skeleton overlay (`SkeletonOverlayView`) as a SwiftUI `Canvas` drawn on top of the camera preview
4. Session UI controls (timer display, state indicator, target setter) as SwiftUI views in the `ZStack`

Do NOT use UIKit view controllers as the top-level container and push SwiftUI downward. SwiftUI as the root makes @Observable bindings, navigation, and sheets (video review, history) idiomatic. The camera preview is a leaf view, not the root — UIViewRepresentable for the leaf is the correct scope.

---

## Video Buffering Architecture

**Recommendation: Circular CMSampleBuffer buffer written via AVAssetWriter.**

The app must automatically record each hold attempt (PROJECT.md: "Each hold attempt is recorded automatically (buffered in temp storage)"). This requires a pre-roll buffer so that when pose detection transitions from "searching" to "hold started", the video clip already contains the lead-up frames.

Architecture:
- `AVCaptureVideoDataOutput` + `AVCaptureAudioDataOutput` emit `CMSampleBuffer` objects per frame
- A `CircularSampleBufferQueue` holds the last N seconds of compressed frames (hardware-encode with VideoToolbox before buffering to reduce memory 10x)
- On hold-start: pass buffered + live frames to `AVAssetWriter` writing to a temp file in the app's temporary directory
- On hold-end: finalize the asset writer, present the clip for review (keep/discard)
- On keep: use `PHPhotoLibrary` to write to camera roll
- On discard: delete the temp file immediately

Key API: `AVAssetWriterInput.expectsMediaDataInRealTime = true` — required for live capture writing.

**Do NOT use AVCaptureMovieFileOutput.** It cannot simultaneously deliver frames to Vision (you cannot have both a movie file output and a video data output active on the same session processing the same frames for Vision). AVCaptureVideoDataOutput + AVAssetWriter is the correct split-pipeline approach.

---

## Local Persistence: SwiftData

**Recommendation: SwiftData with the following model structure.**

CaliTimer's data model is simple:
- `Session` (start date, end date, camera used)
- `Hold` (skill type, duration, date, session relationship, clip file path if saved)
- Personal best is a computed query (max duration per skill), not a stored entity

This fits comfortably within SwiftData's capabilities. The known limitations (complex predicates, enum-as-predicate) do not apply here — queries are "all holds for session X" and "max duration where skill = .handstand", both simple.

**Known SwiftData caveats to manage:**
- Make all relationships optional (known stability requirement)
- Avoid enum types as `#Predicate` parameters — store skill as `String` and compare strings, or use an intermediate integer raw value
- Use `@ModelActor` for any background write operations (e.g., finalizing hold records off main thread)
- iOS 18 introduced an internal change where `@ModelActor` writes do not auto-refresh views — call `context.save()` explicitly and post a notification or use the `@Query` macro refresh trigger

---

## Installation

```swift
// CaliTimer uses only first-party Apple frameworks — no package manifest entries required.
// In Xcode target settings, add these framework capabilities:
// - Vision (implicit via import Vision)
// - AVFoundation (implicit via import AVFoundation)
// - SwiftData (implicit via import SwiftData)
// - Photos / PhotosUI (implicit via import Photos / PhotosUI)

// Info.plist required keys:
// NSCameraUsageDescription — "CaliTimer uses the camera to detect your holds in real time."
// NSPhotoLibraryAddUsageDescription — "CaliTimer saves your kept clips to the Photos library."
// NSPhotoLibraryUsageDescription — "CaliTimer reads videos from your library for offline analysis." (Video Upload Mode only)
// NSMicrophoneUsageDescription — "CaliTimer records audio alongside your hold clips." (optional, omit if audio not captured)
```

No external dependencies. No Swift Package Manager entries required. Entire stack is first-party Apple frameworks.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Apple Vision VNDetectHumanBodyPoseRequest | MediaPipe BlazePose | Only if you also need Android support or need 33-landmark full-body accuracy for a skill where orientation is always upright |
| Apple Vision VNDetectHumanBodyPoseRequest | Custom CoreML model | Only if Phase 1 validation shows Vision detection is inaccurate for handstand holds in real training conditions |
| SwiftData | Core Data | If you need batch operations, complex SQL predicates, or public CloudKit sync |
| AVCaptureVideoDataOutput + AVAssetWriter | AVCaptureMovieFileOutput | Only for simple recording apps that do not need simultaneous Vision frame processing |
| SwiftUI root + UIViewRepresentable for preview | Full UIKit root with UIHostingController for SwiftUI leaves | Only if targeting iOS 15 or if you have an existing UIKit app to extend |
| Swift Testing (WWDC24) + XCTest | Only XCTest | Swift Testing is the forward path but XCTest is still needed for UI tests and performance tests |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| MediaPipe for handstand detection | BlazePose's person detector is orientation-sensitive; handstand (fully inverted body) is outside its training distribution; face-detection-as-proxy fails for inverted athletes | Apple Vision VNDetectHumanBodyPoseRequest |
| AVCaptureMovieFileOutput | Cannot simultaneously deliver frames to Vision; you get recording OR pose analysis, not both | AVCaptureVideoDataOutput + AVAssetWriter |
| Combine / ObservableObject | Superseded by @Observable (iOS 17+); more boilerplate, less granular re-render | @Observable macro with Swift Observation framework |
| CocoaPods | MediaPipe requires it; if you avoid MediaPipe you avoid CocoaPods entirely; SPM-only build is simpler and CI-friendly | Swift Package Manager (nothing to add for first-party stack) |
| VNDetectHumanBodyPose3DRequest for Phase 1 | Requires LiDAR (iPhone 12 Pro+), excluding non-Pro devices; 3D depth adds complexity without clear benefit for hold timer detection | VNDetectHumanBodyPoseRequest (2D is sufficient for handstand geometry) |
| iCloud / CloudKit | Out of scope per PROJECT.md; SwiftData's CloudKit sync has additional migration constraints | Local SwiftData only |
| UIImagePickerController | Deprecated; limited to photos, UI is non-customizable | PHPickerViewController for video import |

---

## Stack Patterns by Variant

**If targeting iOS 17 only (current plan):**
- Use `VNDetectHumanBodyPoseRequest` (legacy API, VN-prefixed, callback-based)
- Use `VNImageRequestHandler` with `CVPixelBuffer` from `CMSampleBuffer`
- Wrap Vision callback in an `actor` or `DispatchQueue` to avoid Swift 6 data-race warnings
- SwiftData is available from iOS 17.0

**If dropping iOS 17 support and targeting iOS 18+ (future):**
- Migrate to `DetectHumanBodyPoseRequest` async/await (no VN prefix)
- Holistic body pose (`request.detectsHands = true`) for free hand tracking if needed
- Full Swift 6 structured concurrency throughout the Vision pipeline

**If Phase 2 custom CoreML model is needed:**
- Use `coremltools` (Python) to convert a PyTorch model to `.mlpackage`
- Integrate via `CoreML.MLModel` and wrap in a Vision `VNCoreMLRequest`
- Same AVFoundation pipeline; replace VNDetectHumanBodyPoseRequest with VNCoreMLRequest

---

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| VNDetectHumanBodyPoseRequest | iOS 14+ | Stable, will not be removed; "legacy" label at WWDC24 means new features go to async API only |
| SwiftData | iOS 17.0+ | Do not backport to iOS 16; use Core Data for any iOS 16 requirement |
| @Observable macro | iOS 17.0+ | Replaces ObservableObject; not available on iOS 16 |
| DetectHumanBodyPoseRequest (new async API) | iOS 18.0+ | New at WWDC24; use only if dropping iOS 17 support |
| PHPickerViewController | iOS 14+ | Use for all video import; UIImagePickerController deprecated |
| AVAssetWriter | iOS 4.1+ | Stable, no compatibility concerns |

---

## Sources

- [VNDetectHumanBodyPoseRequest — Apple Developer Documentation](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest) — joints, availability, confidence levels
- [VNDetectHumanBodyPose3DRequest — Apple Developer Documentation](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest) — 3D API, LiDAR requirement, single-person limitation
- [Discover Swift enhancements in the Vision framework — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10163/) — new async API, iOS 18+ requirement, holistic body pose, VN prefix removal (HIGH confidence)
- [Detecting body poses in a live video feed — Create with Swift](https://www.createwithswift.com/detecting-body-poses-in-a-live-video-feed/) — AVFoundation + Vision integration pattern, alwaysDiscardsLateVideoFrames (MEDIUM confidence)
- [Pose landmark detection guide for iOS — Google AI Edge](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker/ios) — MediaPipe installation (CocoaPods), 33 landmarks, no inverted-pose guidance (HIGH confidence for MediaPipe facts)
- [MediaPipe for Sports Apps — it-jim.com](https://www.it-jim.com/blog/mediapipe-for-sports-apps/) — limb direction flipping, orientation instability for inverted poses (MEDIUM confidence)
- [BlazePose pose.md — Google AI Edge GitHub](https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/pose.md) — hip-midpoint orientation anchor, face-detection-as-proxy architecture (HIGH confidence for BlazePose design)
- [Key Considerations Before Using SwiftData — fatbobman.com](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — SwiftData limitations, performance hierarchy, iOS 18 ModelActor issue (MEDIUM confidence)
- [SwiftData Issues — mjtsai.com](https://mjtsai.com/blog/2024/06/04/swiftdata-issues-in-macos-14-and-ios-17/) — enum predicate bug, optional relationship requirement (MEDIUM confidence)
- [iOS 18/17 new Camera APIs — Medium/YLabZ](https://zoewave.medium.com/ios-18-17-new-camera-apis-645f7a1e54e8) — iOS 17/18 camera API overview (LOW confidence, blog post)
- [Doing it Live at GIPHY with AVFoundation](https://engineering.giphy.com/doing-it-live-at-giphy-with-avfoundation/) — circular buffer + VideoToolbox compression pattern, 10x memory reduction (MEDIUM confidence)
- [AVAssetWriter for high FPS — Medium/krzechowski](https://medium.com/@krzechowski/avassetwriter-for-high-fps-camera-stream-90c33861b7ee) — expectsMediaDataInRealTime, AVCaptureVideoDataOutput setup (MEDIUM confidence)

---

*Stack research for: iOS on-device calisthenics pose estimation timer (CaliTimer)*
*Researched: 2026-03-01*
