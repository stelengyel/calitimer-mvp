---
phase: 04-pose-detection
plan: 02
subsystem: ui
tags: [avfoundation, vision, skeleton-overlay, swiftui, camera, pose-detection]

# Dependency graph
requires:
  - phase: 04-01
    provides: VisionProcessor, SkeletonOverlayView, SkeletonPreference types
  - phase: 02-camera-setup-session-view
    provides: CameraManager, LiveSessionView, SessionConfigSheet
provides:
  - AVCaptureVideoDataOutput wired into CameraManager with VisionProcessor delegate
  - SkeletonOverlayView layered in LiveSessionView between camera and controls
  - Skeleton toggle in SessionConfigSheet (passed from LiveSessionView)
  - Skeleton toggle in SettingsView (Detection section)
affects:
  - 04-03 (HandstandClassifier reads VisionProcessor.detectedPose same pipeline)
  - 05-handstand-detection-timer (consumes live pose pipeline built here)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AVCaptureVideoDataOutputSampleBufferDelegate on nonisolated CameraManager with separate videoOutputQueue
    - nonisolated delegate calls nonisolated VisionProcessor.process() directly — no actor bridging needed
    - SkeletonPreference passed into SessionConfigSheet as parameter so LiveSessionView owns the instance
    - Independent SkeletonPreference instances in SettingsView and HomeView read/write same UserDefaults key

key-files:
  created: []
  modified:
    - CaliTimer/Camera/CameraManager.swift
    - CaliTimer/UI/LiveSession/LiveSessionView.swift
    - CaliTimer/UI/LiveSession/SessionConfigSheet.swift
    - CaliTimer/UI/Settings/SettingsView.swift
    - CaliTimer/UI/Home/HomeView.swift

key-decisions:
  - "captureOutput delegate calls visionProcessor.process() directly (nonisolated on both sides) — no Task actor bridge needed since VisionProcessor.process() is nonisolated"
  - "skeletonPref passed as let parameter to SessionConfigSheet from LiveSessionView — single instance shared mid-session; HomeView creates its own instance (same UserDefaults key)"
  - "SettingsView replaces placeholder body with List + Detection section containing skeleton toggle"

patterns-established:
  - "Pattern: AVCaptureVideoDataOutput on separate videoOutputQueue — keeps camera ops queue unblocked"
  - "Pattern: nonisolated delegate + nonisolated processor = zero actor hop overhead per frame"

requirements-completed: [DETE-05]

# Metrics
duration: 2min
completed: 2026-03-06
---

# Phase 4 Plan 02: Live Camera Pipeline + Skeleton Overlay Summary

**AVCaptureVideoDataOutput wired to VisionProcessor per frame, SkeletonOverlayView rendered live in camera ZStack, toggle in SessionConfigSheet and SettingsView persisted via UserDefaults**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-06T16:02:05Z
- **Completed:** 2026-03-06T16:04:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- CameraManager feeds every camera frame to VisionProcessor via AVCaptureVideoDataOutput on a dedicated videoOutputQueue
- SkeletonOverlayView renders in LiveSessionView between camera preview (layer 0) and controls (layer 1) with allowsHitTesting(false)
- Skeleton toggle in SessionConfigSheet (passed as parameter from LiveSessionView) and SettingsView (Detection section) — both persist via UserDefaults key "skeletonOverlayEnabled"

## Task Commits

Each task was committed atomically:

1. **Task 1: Add AVCaptureVideoDataOutput + VisionProcessor wiring to CameraManager** - `64427fd` (feat)
2. **Task 2: Layer SkeletonOverlayView into LiveSessionView + toggle in SessionConfigSheet and SettingsView** - `06b9eff` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `CaliTimer/Camera/CameraManager.swift` - Added videoOutputQueue, videoOutput, visionProcessor let, AVCaptureVideoDataOutput setup in configureAndStart(), AVCaptureVideoDataOutputSampleBufferDelegate extension
- `CaliTimer/UI/LiveSession/LiveSessionView.swift` - Added @StateObject skeletonPref, SkeletonOverlayView layer between camera and controls, passed skeletonPref to SessionConfigSheet
- `CaliTimer/UI/LiveSession/SessionConfigSheet.swift` - Added let skeletonPref parameter, skeleton toggle row with Divider
- `CaliTimer/UI/Settings/SettingsView.swift` - Replaced placeholder with List + Detection section containing skeleton toggle
- `CaliTimer/UI/Home/HomeView.swift` - Added @StateObject skeletonPref, pass to SessionConfigSheet call site

## Decisions Made
- `captureOutput` calls `visionProcessor.process()` directly without `Task { @CameraActor in }` bridging because `VisionProcessor` is `@MainActor` with `nonisolated func process()` — nonisolated to nonisolated is a direct call, no actor hop overhead
- `skeletonPref` is a `let` parameter on `SessionConfigSheet` rather than a separate `@StateObject` — LiveSessionView owns the single instance during a session; SessionConfigSheet mutates it via binding
- HomeView gets its own `SkeletonPreference` instance since it's a pre-session context — both instances share the same UserDefaults key

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated HomeView SessionConfigSheet call site**
- **Found during:** Task 2 (SessionConfigSheet parameter addition)
- **Issue:** Adding `let skeletonPref` to SessionConfigSheet broke the existing call in HomeView (missing argument)
- **Fix:** Added `@StateObject private var skeletonPref = SkeletonPreference()` to HomeView and passed it to the SessionConfigSheet call
- **Files modified:** CaliTimer/UI/Home/HomeView.swift
- **Verification:** grep confirms `SessionConfigSheet(skeletonPref: skeletonPref)` in HomeView
- **Committed in:** `06b9eff` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Fix required for project to compile. HomeView was the only other SessionConfigSheet call site. No scope creep.

## Issues Encountered
- Plan interfaces described VisionProcessor as `@CameraActor` but Plan 01 implemented it as `@MainActor` with `nonisolated func process()`. The delegate implementation was adapted accordingly — direct call instead of `Task { @CameraActor in }`. This is correct and more efficient.

## Next Phase Readiness
- Live pose pipeline is complete: camera frames flow to VisionProcessor, detectedPose publishes to SwiftUI
- SkeletonOverlayView renders detected joints and bones on the camera feed
- Plan 03 (HandstandClassifier) can read `visionProcessor.detectedPose` from the same pipeline
- Phase 5 (Handstand Detection + Timer) ready to consume the pipeline

---
*Phase: 04-pose-detection*
*Completed: 2026-03-06*
