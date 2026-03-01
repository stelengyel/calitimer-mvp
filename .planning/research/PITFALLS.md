# Pitfalls Research

**Domain:** iOS real-time pose estimation + camera + video recording (calisthenics timer app)
**Researched:** 2026-03-01
**Confidence:** MEDIUM-HIGH — Core AVFoundation/Vision pitfalls are well-documented by Apple and community. Handstand-specific accuracy issues are partially inferred from documented limitations on inverted poses (official WWDC confirmation exists). Swift 6 concurrency friction is actively discussed (2024-2025 forum threads).

---

## Critical Pitfalls

### Pitfall 1: Vision Framework Fails on Inverted Poses — The Handstand Problem

**What goes wrong:**
Apple's VNDetectHumanBodyPoseRequest is trained on standard upright human silhouettes. When the body is inverted (handstand), the model degrades significantly: joint confidence scores drop, joints are misidentified, and the algorithm "guesses" positions unrealistically. The skeleton overlay will look plausible to the framework while actually being wrong. This means pose-based hold detection may either miss valid handstands entirely or fire false positives on unrelated positions.

**Why it happens:**
Explicitly documented in WWDC20 session 10653: "If people on the scene are bent over or upside down, the body pose algorithm will not perform as well." The model was not optimized for inverted poses. The framework still returns *some* observation — it doesn't return nil — which makes the failure mode silent rather than obvious.

**How to avoid:**
- Do not detect a handstand by looking for high-confidence joint positions in standard orientation. Instead, design a handstand classifier based on *geometric relationships*: feet joints should be above head joints (normalized image coordinates), wrists near midline, hips above shoulders.
- Use confidence thresholds per-joint (filter joints below 0.5 confidence) but weight detection logic on the joints that remain reliable in inversion: ankles, knees, and hips tend to hold up better than the head/neck joints.
- Build a small labeled dataset of handstand frames (even 50-100 images) and test detection accuracy before trusting the pipeline. Do this in Phase 1 before building anything on top of it.
- If Apple Vision accuracy is consistently insufficient, MediaPipe Pose (BlazePose) has been shown to handle non-standard poses more reliably — keep this as a fallback option.

**Warning signs:**
- During manual testing, the skeleton overlay appears correct visually but detection never fires (or fires constantly)
- Confidence values for key joints (head, neck) are all below 0.4 during a handstand
- Detection fires during pike/forward fold positions that look nothing like a handstand

**Phase to address:** Phase 1 (core pose detection). This must be validated before any other feature is built on top of it.

---

### Pitfall 2: AVCaptureSession.startRunning() on the Main Thread Blocks UI

**What goes wrong:**
Calling `startRunning()` on the main thread causes the UI to freeze for several hundred milliseconds while the camera initializes. With Swift 6's strict concurrency checking, calling it on a background `DispatchQueue` generates "non-sendable type AVCaptureSession in asynchronous access" compile errors. Developers either block the main thread to avoid the Swift 6 errors, or use `@unchecked Sendable` workarounds that hide real data races.

**Why it happens:**
Apple's own documentation warns that `startRunning()` should run on a background thread. But `AVCaptureSession` is not `Sendable`, so Swift 6's actor isolation model prevents clean dispatch to background queues without unsafe annotations. This tension between AVFoundation's thread requirements and Swift 6's concurrency model is an unresolved friction point as of early 2026 (active Swift Forums discussion: "Safely use AVCaptureSession + Swift 6.2 Concurrency").

**How to avoid:**
- Create a dedicated `CameraService` actor or class that owns the `AVCaptureSession` and is explicitly isolated to a serial background queue using `nonisolated(unsafe)` or a custom serial executor.
- Do not route camera session management through `@MainActor`. Keep it on its own dedicated queue.
- Avoid `@unchecked Sendable` on types that touch the session — this suppresses warnings that protect against real crashes.
- Pattern: `Task.detached(priority: .userInitiated) { await cameraService.start() }` where `cameraService` manages its own isolation.

**Warning signs:**
- Any `@MainActor` annotation on a class that calls `captureSession.startRunning()`
- The Thread Performance Checker in Xcode Instruments firing "UI API called on a background thread" or "startRunning should be called from background thread"
- UI stutter when transitioning to the camera screen

**Phase to address:** Phase 1 (camera setup). Establish correct threading architecture at the start — retrofitting it is painful.

---

### Pitfall 3: Vision Request Handler Created Per-Frame — Loses Temporal Context and Wastes CPU

**What goes wrong:**
Creating a new `VNImageRequestHandler` for every camera frame is the first implementation mistake developers make when following basic Vision tutorials. This discards all inter-frame state, causes joint positions to jitter frame-to-frame with no smoothing, and wastes CPU initializing the handler on every frame. At 30fps this accumulates into noticeable battery drain and processing lag.

**Why it happens:**
Most introductory Vision samples show single-image analysis using `VNImageRequestHandler`. Developers copy this pattern into their video loop without realizing that `VNSequenceRequestHandler` exists specifically for sequential frames and maintains state across calls.

**How to avoid:**
- Create one `VNSequenceRequestHandler` at session start and reuse it across all frames.
- Pass all concurrent requests in a single `perform([request1, request2])` call — the handler is optimized for batch processing and runs faster than calling perform separately.
- Do not create a new handler per frame under any circumstances.

**Warning signs:**
- `VNImageRequestHandler()` instantiation inside the `captureOutput(_:didOutput:from:)` delegate method
- Jittery skeleton overlay that jumps around even when the subject is still
- High CPU utilization in Instruments with Vision request allocation visible in allocations trace

**Phase to address:** Phase 1 (pose detection pipeline). Establish this before writing detection logic.

---

### Pitfall 4: Processing Vision Requests on the Main Thread Causes Frame Drops and UI Freeze

**What goes wrong:**
Running `visionHandler.perform(requests)` on the main thread blocks UI rendering for the duration of the inference. At 30fps, each frame allows ~33ms. Vision body pose inference takes 20-50ms on mid-range devices. On the main thread, this drops the UI to single-digit FPS, makes the camera preview stutter, and makes the timer display lag.

**Why it happens:**
`AVCaptureVideoDataOutput` can deliver frames on any queue including the main queue. Beginner implementations set the capture delegate queue to `DispatchQueue.main` out of convenience (to update UI directly), then call Vision in the same delegate callback.

**How to avoid:**
- Set the delegate queue for `AVCaptureVideoDataOutput` to a dedicated **serial** background queue (not `.global()` concurrent — use serial to prevent out-of-order frame processing).
- Run all Vision inference on this background queue.
- Publish results back to `@MainActor` via `await MainActor.run {}` or `@Published` property updates.
- Never call SwiftUI state updates from the capture delegate directly.

**Warning signs:**
- `setSampleBufferDelegate(self, queue: .main)` anywhere in the codebase
- Camera preview visibly stutters when pose detection is enabled
- Instruments showing long main-thread hangs (~30-50ms) correlating with frame delivery timing

**Phase to address:** Phase 1 (camera + pose pipeline). Non-negotiable architecture requirement from day one.

---

### Pitfall 5: Circular Pre-Roll Buffer Memory Blowup

**What goes wrong:**
Implementing a pre-roll video buffer (keeping the N seconds before hold detection fires) requires storing raw `CMSampleBuffer` or `CVPixelBuffer` objects in memory. `CVPixelBufferPool` used by `AVCaptureVideoDataOutput` maintains 10-15 buffer references internally. Retaining additional references prevents the pool from reclaiming buffers, causing memory usage to spike from ~50MB to 200-300MB+. On iPhone with low available RAM, this causes OS memory pressure kills.

**Why it happens:**
`CMSampleBuffer` retains the underlying pixel buffer pool memory until released. If a ring buffer holds references to 90 frames (3 seconds at 30fps) of uncompressed 4K video, each frame at 1920x1080 is ~8MB. That's 720MB just for the ring buffer — impossible on device. Even at 720p (4MB/frame) for 3 seconds = 360MB.

**How to avoid:**
- **Do not buffer raw pixel buffers in memory.** Use VideoToolbox to H.264-encode frames to compressed data before storing in the ring buffer. Compressed frames are 10-50x smaller.
- Alternatively: run the camera at a lower resolution specifically for the buffer (720p, not 4K) and only record full resolution to the active `AVAssetWriter` session once hold is confirmed.
- Set `alwaysDiscardsLateVideoFrames = true` on `AVCaptureVideoDataOutput` — never false in this use case.
- Cap ring buffer size explicitly (e.g., 5 seconds max pre-roll) and enforce it.
- Call `CFRelease` on sample buffers that are no longer needed immediately.

**Warning signs:**
- Memory climbing steadily during a session in Instruments' Allocations tool
- CVPixelBufferPool entries accumulating in the memory graph
- App being killed by Jetsam (OOM killer) — shows in device logs as `jettisoned`

**Phase to address:** Phase 2 (video recording). Design the buffer architecture before implementing. The simplest safe approach: start `AVAssetWriter` slightly before detection fires rather than trying to buffer pre-roll frames. Accept a 1-2 second miss at the start of the clip rather than building complex buffer logic.

---

### Pitfall 6: Swift 6 + AVFoundation Concurrency Compile Errors Stall Development

**What goes wrong:**
iOS 17+ projects using Swift 6's strict concurrency checking produce numerous compile errors when integrating AVFoundation: `AVCaptureSession` is not `Sendable`, `AVCaptureDevice` is not `Sendable`, and delegate callbacks don't arrive on the expected actor. Developers either disable strict concurrency (`-warnConcurrency` → nothing) or spray `@unchecked Sendable` everywhere, which hides real data races that manifest at runtime as crashes or corrupted state.

**Why it happens:**
AVFoundation predates Swift's actor model and was not designed with `Sendable` in mind. As of early 2026, Apple has not retroactively annotated all AVFoundation types. This is an active topic in Swift Forums (thread: "Safely use AVCaptureSession + Swift 6.2 Concurrency", 2025).

**How to avoid:**
- Isolate all AVFoundation interaction behind a single `CameraService` class that owns its own serial `DispatchQueue`.
- Use `nonisolated(unsafe) var captureSession: AVCaptureSession` within that class — acceptable because the class itself serializes access.
- Avoid spreading AVFoundation types across multiple actors or views.
- Do not use `@MainActor` on any class that directly holds `AVCaptureSession`.
- Accept that this subsystem will have some `@preconcurrency` imports and document why.

**Warning signs:**
- More than 3-4 Swift concurrency warnings/errors in camera-related code
- `@unchecked Sendable` on classes that hold `AVCaptureSession` or `AVAssetWriter`
- Delegates being called on an unexpected thread causing SwiftUI state mutation crashes

**Phase to address:** Phase 1 (foundation). Establish the `CameraService` architecture before any other code touches the camera.

---

### Pitfall 7: AVAssetWriter Initialization Blocks for 5-7 Seconds

**What goes wrong:**
The first time `AVAssetWriter(url:fileType:)` is called in a session, it can block the calling thread for 5-7 seconds while the system initializes video encoding infrastructure. If this call is made synchronously when a hold starts (the natural "start recording now" trigger), it introduces a multi-second dead zone where no video is recorded.

**Why it happens:**
AVAssetWriter lazily initializes hardware encoding resources. The first initialization is expensive. Subsequent writers in the same app session initialize faster but still have non-trivial overhead.

**How to avoid:**
- Initialize `AVAssetWriter` eagerly at session start, not on-demand when hold detection fires.
- Either: (a) create a new `AVAssetWriter` immediately after each clip is finalized to have one ready for the next hold, or (b) start writing continuously and trim/discard based on hold timestamps in post-processing.
- Never call `AVAssetWriter(url:fileType:)` on the main thread or in response to a UI event.
- Use `recommendedVideoSettingsForAssetWriter(writingTo:)` on `AVCaptureVideoDataOutput` to get Apple-recommended encoding settings — avoids trial-and-error with codec parameters.

**Warning signs:**
- "Recording started" fires in the UI but no video is captured for the first few seconds
- `AVAssetWriter` initialization happening inside `captureOutput(_:didOutput:from:)` callback
- First clip of a session is always shorter than expected

**Phase to address:** Phase 2 (video recording). Design the writer lifecycle before implementing hold-triggered recording.

---

### Pitfall 8: Transient Pose Detection Fires False Hold Events — Missing Debounce State Machine

**What goes wrong:**
Pose detection fluctuates frame-to-frame due to confidence variance, micro-movements, and lighting changes. Without debouncing, a 2-second hold attempt produces: detect → lose detection for 3 frames → detect again → lose for 1 frame → detect. The timer fires and stops multiple times, creating multiple short "holds" (0.1s, 0.3s) instead of one clean 2-second hold.

**Why it happens:**
The natural implementation is: "if pose detected this frame → start timer, if pose lost this frame → stop timer." There's no concept of hold continuity across momentary detection gaps.

**How to avoid:**
Design a formal state machine with these states: `searching` → `candidateDetected` (pose seen for N consecutive frames) → `holdActive` (timer running) → `candidateLost` (pose gone for M consecutive frames, grace period) → `holdEnded` (hold saved) or back to `holdActive` (pose recovered).
- `candidateDetected` threshold: 10-15 consecutive frames (~0.33-0.5 seconds) before the hold starts. Eliminates false starts.
- `candidateLost` grace period: 10-20 frames (~0.33-0.67 seconds) before hold ends. Eliminates micro-interruptions.
- Never start/stop the timer based on single-frame detection — always require a streak.
- The consecutive-frame counters reset independently for start and end conditions.

**Warning signs:**
- Timer visibly flickering on and off during a held position
- Session history showing many sub-second holds
- Detection fires when someone walks past the camera briefly

**Phase to address:** Phase 1 (detection + timing). Must be part of the initial detection pipeline design.

---

### Pitfall 9: Camera Preview in SwiftUI via Pixel Buffer — Causes Preview Lag

**What goes wrong:**
Implementing the camera preview by converting `CVPixelBuffer` frames to `UIImage` and updating a SwiftUI `Image` view causes the preview to lag and stutter. The SwiftUI rendering pipeline is not designed for 30fps pixel-level updates, and each frame update triggers unnecessary SwiftUI diffing and re-layout.

**Why it happens:**
SwiftUI's declarative model re-evaluates the view body on state changes. Pushing 30fps pixel buffer updates through `@Observable` or `@Published` properties means 30 view-body re-evaluations per second with image allocation overhead on each frame.

**How to avoid:**
- Use `AVCaptureVideoPreviewLayer` (a `CALayer` subclass) for the live camera preview — it bypasses SwiftUI rendering entirely and renders at native frame rate.
- Wrap it in `UIViewRepresentable` as a `UIView` with `previewLayer` as a sublayer.
- Keep the pixel buffer delegate output separate from the preview layer — the buffer is for Vision inference only, the preview layer handles display.
- Apply skeleton overlay as a `CAShapeLayer` on top of the preview layer, not as a SwiftUI overlay — CALayer animations are GPU-accelerated and don't trigger SwiftUI re-renders.

**Warning signs:**
- `UIImage(ciImage:)` or `UIImage(cgImage:)` conversions inside the frame delegate callback
- SwiftUI `Image` view being updated with `@Published var previewImage: UIImage?`
- Camera preview visibly laggy compared to native camera app

**Phase to address:** Phase 1 (camera UI). Establish the CALayer preview approach from the first camera integration commit.

---

### Pitfall 10: Battery Drain from Continuous Full-Rate Vision Inference

**What goes wrong:**
Running `VNSequenceRequestHandler.perform(poseRequests)` on every camera frame (30fps) at full resolution keeps the Neural Engine running continuously. During a 30-minute training session this is significant battery drain. Apple's own WWDC guidance explicitly recommends spacing out inference for older devices, and the pattern applies for battery efficiency on all devices.

**Why it happens:**
The easiest implementation processes every delivered camera frame. Throttling requires either dropping frames at the capture level or skipping inference calls in the delegate.

**How to avoid:**
- Reduce inference to 10-15fps for pose detection. The human body doesn't move faster than the detection can keep up with at 10fps. Use a frame counter: `if frameCount % 3 == 0 { performInference() }`.
- When the app is in `holdActive` state (hold confirmed, timer running), reduce inference further to ~5fps — you only need to detect hold *breaking*, not fine-grained position.
- Set camera capture resolution to 1280x720 (not 4K) for the analysis pipeline — Vision internally downsamples anyway, so higher resolution wastes preprocessing time.
- Use `AVCaptureSession.sessionPreset = .hd1280x720` not `.photo` or `.high`.

**Warning signs:**
- Energy Impact gauge in Xcode showing "High" during normal detection mode
- Device noticeably warm after 10 minutes of use
- Battery percentage dropping more than 2% per minute during active session

**Phase to address:** Phase 1 (detection pipeline) and Phase 3 (optimization/polish). Throttle from the start; profile in a dedicated optimization phase.

---

### Pitfall 11: Temp Directory Video Files Accumulate Without Cleanup

**What goes wrong:**
iOS does **not** automatically delete files written to the `tmp/` directory when storage is needed (contrary to common belief). Each hold attempt writes a video clip to `FileManager.default.temporaryDirectory`. If users discard clips (the expected common case), those files must be explicitly deleted. Bugs in the discard path (user dismisses review without choosing, app crashes during review, interruption during recording) leave orphaned video files that silently accumulate and fill storage.

**Why it happens:**
Developers test the happy path (keep or discard works correctly) but don't account for interruption scenarios. The OS does *eventually* clean tmp on reboot or storage pressure events, but not reliably enough for a video app writing large files.

**How to avoid:**
- Maintain a manifest (in-memory or persisted) of all active temp video file URLs for the current session.
- On session end, delete all temp files for clips that were not saved to camera roll.
- On app launch, scan the temp directory for video files created by this app and delete any not referenced by the active session (orphan cleanup on startup).
- Wrap all `AVAssetWriter` finalization in cleanup logic that guarantees deletion on failure paths.
- Write temp files to `FileManager.default.temporaryDirectory` with a unique session-scoped subdirectory to make orphan detection unambiguous.

**Warning signs:**
- Temp directory size growing across sessions in Instruments' File System usage
- Users reporting "not enough storage" errors despite having free space
- Multiple video files in tmp with no corresponding session record

**Phase to address:** Phase 2 (video recording). Build cleanup logic alongside the recording pipeline, not as a later add-on.

---

### Pitfall 12: App Backgrounding Kills Camera Session Without Graceful Recovery

**What goes wrong:**
When the app backgrounds (user receives a call, switches apps, locks screen), `AVCaptureSession` is interrupted. If the session is also actively writing to `AVAssetWriter`, the writer can be left in an invalid state — producing a corrupt or empty video file. On foreground return, the session may fail to restart without explicit `startRunning()` being called.

**Why it happens:**
iOS camera policy prohibits background camera access. The interruption fires `AVCaptureSessionWasInterruptedNotification`. If this is not handled, an in-progress `AVAssetWriter` write is abandoned mid-stream.

**How to avoid:**
- Observe `AVCaptureSessionWasInterruptedNotification` and `AVCaptureSessionInterruptionEndedNotification`.
- On interruption: call `AVAssetWriter.finishWriting(completionHandler:)` to close any open write session cleanly, then cancel or save the partial clip.
- On interruption end: call `captureSession.startRunning()` (on background thread) to resume.
- Use `scenePhase` in SwiftUI to complement the AVFoundation notifications — `ScenePhase.background` is an additional signal to trigger cleanup.
- If a hold was in progress during interruption, treat it as a completed hold (save the partial clip) or discard it — surface the interrupted state to the user.

**Warning signs:**
- Corrupt `.mov` files in temp directory (non-zero size but unplayable)
- Session not resuming after a phone call without app restart
- Timer stuck at a non-zero value after returning from background

**Phase to address:** Phase 2 (video recording) for writer safety; Phase 3 (robustness) for full interruption recovery UX.

---

### Pitfall 13: Photo Library Write Permission Uses Deprecated API

**What goes wrong:**
Using `PHPhotoLibrary.requestAuthorization { status in }` (the deprecated single-parameter variant) for write-only access produces incorrect authorization status. The old API doesn't properly distinguish between `.addOnly` and `.readWrite` access levels, and `PHPhotoLibrary.authorizationStatus()` returns `.notDetermined` even after the user has granted write access — causing the app to re-prompt unnecessarily or silently fail to save.

**Why it happens:**
iOS 14 introduced `PHAccessLevel` (.addOnly vs .readWrite) with new API overloads. Tutorials and StackOverflow answers still show the deprecated single-parameter form. CaliTimer only needs `.addOnly` (saving kept clips to camera roll, no read access required) — but developers default to requesting `.readWrite` which triggers a more intrusive permission dialog.

**How to avoid:**
- Use `PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in }` exclusively.
- Check status with `PHPhotoLibrary.authorizationStatus(for: .addOnly)`.
- In `Info.plist`, include only `NSPhotoLibraryAddUsageDescription` (not `NSPhotoLibraryUsageDescription` for read) — requesting minimal permissions reduces user friction and App Review scrutiny.
- Test permission flow explicitly: fresh install, deny, re-request, grant — all paths must be handled.

**Warning signs:**
- Using `PHPhotoLibrary.requestAuthorization { status in }` without the `for:` parameter
- `NSPhotoLibraryUsageDescription` in Info.plist when the app only writes
- "Already have permission but app thinks it doesn't" bug reports

**Phase to address:** Phase 2 (video saving). Get permissions right from first implementation.

---

### Pitfall 14: Privacy Manifest Missing — App Store Rejection

**What goes wrong:**
Since May 2024, App Store submissions without a `PrivacyInfo.xcprivacy` privacy manifest are rejected. Camera, microphone, and photo library access require declaring usage in the manifest. Third-party SDKs (if any) also require their own manifests. CaliTimer's fully on-device architecture reduces risk, but any SDK added during development (analytics, crash reporting) may require its own manifest.

**Why it happens:**
Privacy manifest requirements are new enough that developers working from tutorials written before 2024 are unaware of them. The requirement applies to the app *and* any bundled SDKs that use required-reason APIs.

**How to avoid:**
- Add `PrivacyInfo.xcprivacy` to the main target from project creation.
- Declare: `NSCameraUsageDescription` (for pose detection + recording), `NSPhotoLibraryAddUsageDescription` (for saving clips).
- Declare required-reason API usage for any file timestamp, disk space, or system boot time APIs accessed.
- Before adding any third-party dependency, verify it includes its own `PrivacyInfo.xcprivacy`.

**Warning signs:**
- No `PrivacyInfo.xcprivacy` file in the Xcode project
- Adding a third-party SDK without checking its privacy manifest status
- App Store Connect upload warnings about missing privacy declarations

**Phase to address:** Phase 1 (project setup). Add the manifest on day one.

---

### Pitfall 15: Testing the Real-Time CV Pipeline Is Nearly Impossible on Simulator

**What goes wrong:**
The iOS Simulator does not support `AVCaptureSession` with a real camera. Vision framework requests can be tested with static images on Simulator, but the full pipeline — camera → buffer → Vision inference → state machine → timer → UI — cannot be integration-tested in a CI environment without a physical device.

**Why it happens:**
CI systems (Xcode Cloud, GitHub Actions) run on Simulator by default. Camera-dependent code paths are skipped entirely in automated tests, leaving large surface area untested until manual device testing.

**How to avoid:**
- Design the detection pipeline behind a protocol: `PoseDetectionProvider` with a concrete `VisionPoseDetectionProvider` and a testable `MockPoseDetectionProvider` that replays pre-recorded joint position sequences.
- Unit test the state machine (debounce logic, hold timing, transitions) using the mock provider — this is pure logic with no camera dependency.
- Unit test the session history model, PB tracking, and clip management in complete isolation.
- Create a set of static test images (handstand, non-handstand, partial occlusion, poor lighting) for Vision request accuracy checks that can run on Simulator.
- Accept that integration testing of the full live pipeline requires a physical device; plan manual test sessions at key milestones.

**Warning signs:**
- Zero unit tests in the detection/state-machine layer
- All test targets failing on CI due to camera unavailability
- Bugs in debounce logic only discovered during manual testing

**Phase to address:** Phase 1 (detection pipeline). Design the protocol boundary before writing the implementation.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Process every camera frame in Vision (no throttle) | Simpler code | Battery drain, thermal throttle | Never — throttle from day one |
| Create `VNImageRequestHandler` per frame | Follows basic tutorial pattern | Jitter, CPU waste, no temporal smoothing | Never |
| `@MainActor` on `CameraService` | Avoids Swift 6 concurrency errors | UI freeze on session start, frame drops | Never |
| Raw pixel buffer ring buffer | Conceptually simple | Memory blowup, OOM kills | Never — use compressed encoding or accept no pre-roll |
| `AVAssetWriter` initialized on-demand | Natural trigger-based model | 5-7s recording dead zone on first hold | Never — init eagerly |
| Skip `PHPhotoLibrary.addOnly` in favor of full `.readWrite` | Simpler permission handling | Unnecessarily intrusive permission dialog, App Review flag | Never — request only what's needed |
| Single-frame detection trigger (no debounce) | Faster to implement | False events, flickering timer | Never — state machine is non-negotiable |
| Manual cleanup of temp files deferred | Ship faster | Storage accumulation, user complaints | MVP only if you add a "clear storage" setting as compensating control |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `AVCaptureVideoPreviewLayer` in SwiftUI | Put it inside a SwiftUI view hierarchy as a regular view | Wrap in `UIViewRepresentable`; set `videoGravity = .resizeAspectFill`; handle layer bounds in `layoutSubviews` not SwiftUI geometry |
| Vision + AVFoundation | Call Vision from `captureOutput` delegate on any queue | Dedicate a serial background queue for capture delegate *and* Vision inference; never share with main |
| `AVAssetWriter` + interruptions | Assume `finishWriting` is instantaneous | `finishWriting` is async — use the `completionHandler` variant; do not deallocate the writer before handler fires |
| `PHPhotoLibrary` write | Call from background thread and assume success | Always call on `DispatchQueue.main` or check for `PHPhotosError.accessRestricted`; handle `limited` access mode |
| Audio session + recording | Ignore `AVAudioSession` for a video-only app | Configure `AVAudioSession` to `.record` category before starting capture; handle `AVAudioSessionInterruptionNotification` to avoid silent crash when phone call arrives during recording |
| `CMSampleBuffer` in ring buffer | Store the buffer directly | Copy the buffer data or encode to H.264 before storing; call `CMSampleBufferInvalidate` on discarded buffers |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full-resolution inference (4K frames into Vision) | High CPU, excessive battery drain, ANE thermal throttle | Set session preset to `.hd1280x720` for analysis | From first user session |
| Concurrent Vision requests on global queue | Out-of-order results, race conditions in state machine | Use serial dedicated queue for all Vision work | Under any moderate motion/frame rate |
| `alwaysDiscardsLateVideoFrames = false` with slow inference | Memory spike, delayed processing, cascading frame queue backup | Keep `true`; design inference to complete within frame interval | Immediately when inference exceeds 33ms |
| `CALayer` skeleton overlay updated from background thread | Intermittent flicker, occasional crash | All CALayer mutations must be on main thread: `DispatchQueue.main.async { layer.path = ... }` | Randomly — worst kind of bug |
| `AVAssetWriter` not checking `readyForMoreMediaData` | Memory spike, dropped frames mid-clip | Check `writerInput.isReadyForMoreMediaData` before every `append` call | Under storage I/O pressure |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No camera-angle guidance | Users point phone at themselves sideways or at bad angle; detection never fires; they blame the app | On first launch and session start, show camera angle guide (phone at ~45° elevation, full body visible). Use brief onboarding, not persistent nag. |
| Detection state is opaque | User doesn't know if app sees them; unclear if they need to back up, change lighting | Always show three distinct states visually: "Searching" (no skeleton), "Pose Detected" (skeleton visible, not timing), "Timing" (skeleton + timer running). Binary on/off is insufficient. |
| Clip review blocks next attempt | After each hold, review UI pops up — user has to choose keep/discard before they can start the next hold | Allow queuing: save review to a list, let user continue training. They can review all clips at session end. |
| Silent failure on first hold | Detection works in developer testing (good light, solo) but fails for user (gym lighting, crowded background) | Show confidence level or "body not fully visible" hint when joints are low-confidence. Do not show nothing. |
| No target-reached feedback | User holds for their target duration but misses the haptic (sweating, focused) | Combine haptic with a clear visual flash (full-screen brief tint or timer color change). Vibration alone is insufficient under exertion. |

---

## "Looks Done But Isn't" Checklist

- [ ] **Hold detection:** Works in your living room — verify in gym lighting (high contrast, shadows, multiple people in background)
- [ ] **Video saving:** Clip saves to camera roll — verify the clip actually plays and has the correct duration (AVAssetWriter finalization can succeed but produce a 0-byte file)
- [ ] **Session interruption:** App receives a phone call mid-hold — verify writer closes cleanly, hold is discarded or saved gracefully, session resumes after call ends
- [ ] **Temp storage:** Run 10 sessions and discard all clips — verify temp directory is empty afterward, not accumulating files
- [ ] **Permissions:** Fresh install → deny camera permission → re-enable in Settings → verify session works correctly without restarting app
- [ ] **Background:** App backgrounds mid-hold — verify timer is paused, clip is not corrupted, state resets correctly on foreground return
- [ ] **Low battery / thermal throttle:** Session at 20% battery or device warm from sustained use — verify frame rate and detection stability don't collapse
- [ ] **Personal best:** First hold is always a PB — verify PB logic handles edge case of no previous record correctly

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong Vision handler type (per-frame vs. sequence) | LOW | Swap `VNImageRequestHandler` for `VNSequenceRequestHandler`; single-line change with immediate improvement |
| Threading architecture wrong (main thread camera) | HIGH | Requires extracting all camera/Vision code into a dedicated service class; touches every file in the stack |
| Memory leak from retained sample buffers | MEDIUM | Profile with Instruments Allocations; identify which object holds the buffer; add `CFRelease` at correct scope |
| Temp file accumulation in production | MEDIUM | Ship a cleanup routine in next update; add a "Clear Storage" option in settings as immediate user-visible fix |
| AVAssetWriter corrupt clips from interruption | MEDIUM | Add `finishWriting` to app background handler; users with corrupt clips cannot be recovered but future clips are protected |
| Missing privacy manifest causing App Store rejection | LOW | Add `PrivacyInfo.xcprivacy` to project; re-submit; typically a 1-day turnaround for this specific fix |
| Handstand pose detection fundamentally unreliable | HIGH | Switch to MediaPipe Pose or a custom CoreML classifier; requires rebuilding detection layer with new model |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Inverted pose accuracy failure | Phase 1 (pose detection) | Manual test: 50 handstand frames across lighting conditions; >80% correct detection required to proceed |
| `startRunning` on main thread | Phase 1 (camera setup) | Thread Performance Checker must show zero violations; UI remains smooth during session start |
| Per-frame Vision handler creation | Phase 1 (pose pipeline) | Code review: no `VNImageRequestHandler` in capture delegate; skeleton overlay is smooth |
| Vision inference on main thread | Phase 1 (pose pipeline) | Instruments: main thread shows no Vision-related work; preview runs at 30fps |
| Circular buffer memory blowup | Phase 2 (video recording) | Instruments Allocations: memory stable during 10-minute session with continuous detection |
| Swift 6 concurrency friction | Phase 1 (foundation) | Zero `@unchecked Sendable` on camera-related types; compile with strict concurrency enabled |
| AVAssetWriter init latency | Phase 2 (video recording) | First hold clip starts within 0.5s of detection firing |
| Missing debounce state machine | Phase 1 (detection + timing) | Test: wave hand in front of camera rapidly — no holds logged; stand still for 2s — exactly one hold logged |
| SwiftUI pixel-buffer preview lag | Phase 1 (camera UI) | Preview runs at device camera rate with no visible stutter when detection is active |
| Battery drain from full-rate inference | Phase 1 (pipeline, throttled from start); validated Phase 3 | Energy gauge shows "Low" or "Fair" impact; device not warm after 15 minutes |
| Temp file accumulation | Phase 2 (video recording) | After 10 sessions with all clips discarded: `FileManager.temporaryDirectory` contains zero video files from this app |
| Camera backgrounding / interruption | Phase 2 (video recording) + Phase 3 (robustness) | Phone call during active recording produces no corrupt files; session resumes correctly |
| Photo library deprecated API | Phase 2 (video saving) | `.addOnly` access level used throughout; no `PHPhotoLibraryUsageDescription` in Info.plist |
| Missing privacy manifest | Phase 1 (project setup) | `PrivacyInfo.xcprivacy` present in project; App Store Connect shows no privacy manifest warnings on upload |
| Untestable CV pipeline | Phase 1 (architecture) | `PoseDetectionProvider` protocol exists; state machine has >80% unit test coverage via mock provider |

---

## Sources

- Apple WWDC20 Session 10653: "Detect Body and Hand Pose with Vision" — explicit documentation of inverted-pose limitations, buffer-starvation warning, handler reuse guidance
  https://developer.apple.com/videos/play/wwdc2020/10653/
- Apple WWDC23 Session 111241: "Explore 3D body pose and person segmentation in Vision"
  https://developer.apple.com/videos/play/wwdc2023/111241/
- Apple Developer Forums: "AVCaptureSession and concurrency" (Swift 6 tension) — 2024
  https://forums.swift.org/t/avcapturesession-and-concurrency/72681
- Apple Developer Forums: "Safely use AVCaptureSession + Swift 6.2 Concurrency" — 2025
  https://forums.swift.org/t/safely-use-avcapturesession-swift-6-2-concurrency/83622
- Apple Developer Documentation: `VNDetectHumanBodyPoseRequest`
  https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest
- Apple Developer Forums: AVCaptureVideoDataOutput memory/buffer consumption thread
  https://developer.apple.com/forums/thread/679250
- Apple Technical Note TN2445: Handling Frame Drops with AVCaptureVideoDataOutput
  https://developer.apple.com/library/archive/technotes/tn2445/_index.html
- Apple Developer Forums: AVAssetWriter performance issues thread
  https://developer.apple.com/forums/thread/741942
- Apple Developer Documentation: Privacy manifest files
  https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- objc.io Issue 23: "Capturing Video on iOS" — AVAssetWriter `expectsMediaDataInRealTime`, permission black-frame failure
  https://www.objc.io/issues/23-video/capturing-video/
- Kamil Tustanowski: "Detecting body pose using Vision framework" — confidence thresholds, occlusion behavior
  https://medium.com/@kamil.tustanowski/detecting-body-pose-using-vision-framework-caba5435796a
- OrangeLoops: "Hand Tracking & Body Pose Detection with Vision Framework" — lighting/angle accuracy analysis
  https://orangeloops.com/2020/08/hand-tracking-body-pose-detection-with-vision-framework/
- Apple Developer Forums: "When does iOS system clear tmp directory" — confirmation OS does NOT auto-clear tmp
  https://developer.apple.com/forums/thread/680224
- NSHipster: "Temporary Files" — best practices for temp file management on iOS
  https://nshipster.com/temporary-files/
- PHPhotoLibrary authorizationStatus / write-only API open radar issue
  https://github.com/lionheart/openradar-mirror/issues/18522
- Swift Senpai: "How to Manage Photo Library Permission in iOS" — `.addOnly` vs `.readWrite`
  https://swiftsenpai.com/development/photo-library-permission/
- neuralception.com: "Live camera feed in SwiftUI with AVCaptureVideoPreviewLayer" — CALayer-in-SwiftUI pattern
  https://www.neuralception.com/detection-app-tutorial-camera-feed/
- Matthijs Hollemans: "Everything we actually know about the Apple Neural Engine" — ANE power characteristics
  https://github.com/hollance/neural-engine

---
*Pitfalls research for: iOS real-time pose estimation calisthenics timer (CaliTimer)*
*Researched: 2026-03-01*
