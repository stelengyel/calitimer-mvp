---
phase: 04-pose-detection
plan: "03"
subsystem: ui
tags: [AVFoundation, Vision, AVPlayerItemVideoOutput, SwiftUI, pose-detection]

# Dependency graph
requires:
  - phase: 04-01
    provides: VisionProcessor, SkeletonOverlayView, SkeletonPreference
  - phase: 03-video-upload-shell
    provides: VideoImportManager with AVPlayer, UploadModeView with VideoPlayerView

provides:
  - VideoImportManager polls video frames at ~30fps via AVPlayerItemVideoOutput and feeds them to VisionProcessor
  - UploadModeView renders SkeletonOverlayView over VideoPlayerView controlled by SkeletonPreference

affects:
  - 04-pose-detection
  - 05-handstand-detection

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AVPlayerItemVideoOutput + addPeriodicTimeObserver polling pattern for video frame extraction
    - CMSampleBuffer wrapping from CVPixelBuffer via CMVideoFormatDescriptionCreateForImageBuffer
    - Task.detached for dispatching nonisolated Vision processing off the main thread
    - allowsHitTesting(false) on skeleton overlay to pass through player control taps

key-files:
  created: []
  modified:
    - CaliTimer/Upload/VideoImportManager.swift
    - CaliTimer/UI/Upload/UploadModeView.swift

key-decisions:
  - "Used Task.detached instead of Task { @CameraActor in } because VisionProcessor.process() is nonisolated @MainActor — @CameraActor actor is not used in this project"
  - "nonisolated(unsafe) on videoOutput property matches Swift 6 requirements for AVPlayerItemVideoOutput crossing actor boundary in DispatchQueue.main.async callback"
  - "detachVideoOutput() called both in handlePickerResult reset block and before attachVideoOutput() — prevents double-observer leaks on rapid re-imports"

patterns-established:
  - "Frame tap pattern: AVPlayerItemVideoOutput + periodic observer + CMSampleBuffer wrapping — reusable for any AVPlayer pipeline needing Vision input"

requirements-completed: [DETE-05]

# Metrics
duration: 2min
completed: 2026-03-06
---

# Phase 4 Plan 03: Upload Mode Pose Detection Summary

**AVPlayerItemVideoOutput taps imported video frames at ~30fps, wraps them as CMSampleBuffer, and feeds VisionProcessor — SkeletonOverlayView layered over VideoPlayerView in UploadModeView via SkeletonPreference toggle.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-06T16:02:15Z
- **Completed:** 2026-03-06T16:04:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `VideoImportManager` now attaches `AVPlayerItemVideoOutput` to the `AVPlayerItem` immediately after player creation and polls at ~33ms intervals (~30fps)
- Each frame is extracted as a `CVPixelBuffer`, wrapped into `CMSampleBuffer`, and sent to `VisionProcessor.process()` via `Task.detached`
- `hasNewPixelBuffer(forItemTime:)` guard naturally holds the skeleton on the last processed frame when video is paused or scrubbed — no extra state needed
- `UploadModeView` layers `SkeletonOverlayView` over `VideoPlayerView` inside a nested `ZStack`, controlled by the same `SkeletonPreference` UserDefaults toggle from Plan 02
- Overlay uses `allowsHitTesting(false)` to keep player controls (scrubber, play/pause) fully interactive
- Phase 3 outer ZStack structure (Zone 3 stability contract) is untouched

## Task Commits

Each task was committed atomically:

1. **Task 1: Add AVPlayerItemVideoOutput frame tap to VideoImportManager** - `02e2701` (feat)
2. **Task 2: Layer skeleton overlay onto VideoPlayerView in UploadModeView** - `fae2226` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `CaliTimer/Upload/VideoImportManager.swift` - Added visionProcessor, AVPlayerItemVideoOutput, periodic frame polling, CMSampleBuffer wrapping, detachVideoOutput cleanup
- `CaliTimer/UI/Upload/UploadModeView.swift` - Added skeletonPref StateObject, nested ZStack with SkeletonOverlayView over VideoPlayerView

## Decisions Made

- Used `Task.detached` to call the `nonisolated` `VisionProcessor.process()` rather than `Task { @CameraActor in }`. The actual VisionProcessor is `@MainActor` not `@CameraActor` — the CLAUDE.md preference for `@MainActor` over custom global actors was already applied in Plan 01.
- `nonisolated(unsafe)` on `videoOutput: AVPlayerItemVideoOutput?` — required because the property is written from `DispatchQueue.main.async` (non-MainActor context in Swift 6's view).
- `detachVideoOutput()` called twice: in the reset block at the top of `handlePickerResult` AND at the top of `attachVideoOutput()` — belt-and-suspenders prevents double observer leaks if rapid imports occur.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adapted @CameraActor references to match actual @MainActor VisionProcessor**
- **Found during:** Task 1 (implementing processCurrentFrame)
- **Issue:** Plan specified `Task { @CameraActor in processor.process(sampleBuffer:) }` but VisionProcessor is `@MainActor` (not `@CameraActor`) per CLAUDE.md Swift 6 preference applied in Plan 01
- **Fix:** Used `Task.detached { processor.process(sampleBuffer:) }` — `process()` is `nonisolated` so it dispatches off the main thread without needing any actor annotation
- **Files modified:** CaliTimer/Upload/VideoImportManager.swift
- **Verification:** grep confirms Task.detached usage, matches nonisolated func signature
- **Committed in:** 02e2701 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 actor mismatch — plan used stale @CameraActor, actual code is @MainActor)
**Impact on plan:** Essential correctness fix. No scope creep. Behavior identical — Vision runs off main thread in both approaches.

## Issues Encountered

None — the actor mismatch was caught immediately by reading the existing VisionProcessor source and was a one-line fix.

## Next Phase Readiness

- Upload mode now has full pose detection parity with live camera mode
- Plan 04-02 (LiveSessionView skeleton) and Plan 04-03 (UploadModeView skeleton) are both complete — Phase 4 functional requirements fulfilled
- Phase 5 (Handstand Detection + Timer) can now consume `VisionProcessor.detectedPose` from either pipeline

---
*Phase: 04-pose-detection*
*Completed: 2026-03-06*

## Self-Check: PASSED

- CaliTimer/Upload/VideoImportManager.swift: FOUND
- CaliTimer/UI/Upload/UploadModeView.swift: FOUND
- .planning/phases/04-pose-detection/04-03-SUMMARY.md: FOUND
- Commit 02e2701: FOUND
- Commit fae2226: FOUND
