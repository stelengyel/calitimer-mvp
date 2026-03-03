---
phase: 03-video-upload-shell
plan: 01
subsystem: ui
tags: [swift6, phppicker, avplayer, avfoundation, photosui, concurrency]

# Dependency graph
requires:
  - phase: 02-camera-setup-session-view
    provides: "CameraManager @MainActor ObservableObject pattern + CameraPreviewView UIViewRepresentable pattern"

provides:
  - "VideoImportManager: @MainActor ObservableObject managing PHPicker video import with iCloud download progress"
  - "PHPickerSheet: UIViewControllerRepresentable wrapping PHPickerViewController (video-only)"
  - "VideoPlayerView: SwiftUI player with adaptive aspect ratio, autoplay, stop-at-end, play/pause, scrubber"

affects:
  - 03-video-upload-shell
  - 05-handstand-detection-timer

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "VideoImportManager mirrors CameraManager: @MainActor ObservableObject with @Published state"
    - "PHPickerSheet mirrors pattern from SessionConfigSheet: .sheet(isPresented:) + UIViewControllerRepresentable"
    - "AVPlayerLayerView: UIViewRepresentable hosting AVPlayerLayer with layoutSubviews frame sync"
    - "MainActor.assumeIsolated in Timer callback to eliminate Swift 6 concurrency warnings"
    - "progressTimer stored on self (not captured in closure) to avoid sending non-Sendable Timer across actor boundaries"

key-files:
  created:
    - CaliTimer/Upload/VideoImportManager.swift
    - CaliTimer/Upload/PHPickerCoordinator.swift
    - CaliTimer/Upload/VideoPlayerView.swift
  modified:
    - CaliTimer.xcodeproj/project.pbxproj

key-decisions:
  - "handlePickerResult is async to satisfy @MainActor call from Task { @MainActor in } in PHPickerSheet.Coordinator"
  - "Progress polling via stored progressTimer (not NSProgress KVO) — KVO is not MainActor-safe in Swift 6"
  - "Timer callback uses MainActor.assumeIsolated + ignores _ timer param — avoids sending non-Sendable Timer into @MainActor closure"
  - "AVPlayer owned by parent (not VideoPlayerView internally) — enables Phase 5 external playback control"
  - "loadFileRepresentation copies URL to temporaryDirectory — system-provided URL is only valid during callback"

patterns-established:
  - "Upload layer pattern: Manager (state/logic) + Coordinator (UIKit bridge) + PlayerView (rendering) — mirrors Camera layer"
  - "Non-Sendable @objc objects (Timer) must be stored on @MainActor self, not captured in nested closures"

requirements-completed: [VIDU-01]

# Metrics
duration: 4min
completed: 2026-03-03
---

# Phase 3 Plan 1: VideoImportManager + PHPickerSheet + VideoPlayerView Summary

**PHPickerViewController video import via @MainActor VideoImportManager with iCloud progress polling, plus AVPlayer-backed VideoPlayerView with adaptive aspect ratio, autoplay, and scrubber controls**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-03T18:48:03Z
- **Completed:** 2026-03-03T18:52:10Z
- **Tasks:** 2
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments
- VideoImportManager exposes five @Published vars (videoURL, isDownloading, downloadProgress, importError, hasVideo) wired to SwiftUI without bridging actors
- PHPickerSheet presents a video-only PHPickerViewController and routes results to manager.handlePickerResult via Task { @MainActor in }
- VideoPlayerView renders AVPlayer at natural video aspect ratio (portrait or landscape), autoplays on readyToPlay, stops at end without looping
- All three files compile cleanly under Swift 6 strict concurrency with zero errors and zero warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: VideoImportManager + PHPickerSheet** - `1b6303c` (feat)
2. **Task 2: VideoPlayerView with adaptive aspect ratio and controls** - `fb64861` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `CaliTimer/Upload/VideoImportManager.swift` - @MainActor ObservableObject owning PHPicker import state; copies video to app temp dir; polls iCloud download progress via stored Timer
- `CaliTimer/Upload/PHPickerCoordinator.swift` - UIViewControllerRepresentable for video-only PHPickerViewController; PHPickerSheet delegates results to VideoImportManager
- `CaliTimer/Upload/VideoPlayerView.swift` - SwiftUI player with AVPlayerLayerView (UIViewRepresentable), adaptive aspect ratio, autoplay, stop-at-end notification, play/pause button, Slider scrubber, M:SS time labels
- `CaliTimer.xcodeproj/project.pbxproj` - XcodeGen regenerated to include new Upload/ directory in build target

## Decisions Made
- `handlePickerResult` marked `async` to satisfy `@MainActor` call from `Task { @MainActor in }` inside PHPickerSheet.Coordinator
- Progress polling uses a stored `progressTimer: Timer?` on `self` (not NSProgress KVO) — KVO is not MainActor-safe in Swift 6
- Timer callback uses `MainActor.assumeIsolated` with `_ ` (ignored) timer parameter — avoids sending non-Sendable `Timer` into an `@MainActor`-isolated closure
- `AVPlayer` is owned by the parent view, not VideoPlayerView — allows Phase 5 to control playback from outside the component

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Swift 6 Timer concurrency error in observeProgress**
- **Found during:** Task 1 (VideoImportManager compilation)
- **Issue:** Original plan used `Task { @MainActor in timer.invalidate() }` inside the Timer callback. Swift 6 rejected this because `timer: Timer` (non-Sendable @objc object) was being sent into a `@MainActor`-isolated Task closure
- **Fix:** Stored `progressTimer: Timer?` on `self` as an instance variable; Timer callback ignores the `_ ` timer parameter; added `MainActor.assumeIsolated` to satisfy Swift 6 isolation check. Also extracted `stopProgressTimer()` method for clean invalidation from both timer callback and completion handler
- **Files modified:** CaliTimer/Upload/VideoImportManager.swift
- **Verification:** Build succeeded with zero Swift concurrency errors or warnings
- **Committed in:** 1b6303c (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Swift 6 concurrency bug in template code)
**Impact on plan:** Fix necessary for Swift 6 compliance; no behavior change, no scope creep.

## Issues Encountered
- Plan's `observeProgress` template used `Task { @MainActor in }` capturing `timer: Timer` — Swift 6 strict concurrency rejected this as a potential data race. Resolved by storing timer on `self` and using `MainActor.assumeIsolated`.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three Upload/ files ready for wiring into UploadModeView (Plan 03-02 or equivalent)
- VideoImportManager.videoURL is the signal Phase 5 (Handstand Detection) will observe to start detection on imported video
- AVPlayer ownership pattern is established — parent view creates and owns player, VideoPlayerView consumes it

## Self-Check: PASSED

- FOUND: CaliTimer/Upload/VideoImportManager.swift
- FOUND: CaliTimer/Upload/PHPickerCoordinator.swift
- FOUND: CaliTimer/Upload/VideoPlayerView.swift
- FOUND: .planning/phases/03-video-upload-shell/03-01-SUMMARY.md
- FOUND: 1b6303c (Task 1 commit)
- FOUND: fb64861 (Task 2 commit)

---
*Phase: 03-video-upload-shell*
*Completed: 2026-03-03*
