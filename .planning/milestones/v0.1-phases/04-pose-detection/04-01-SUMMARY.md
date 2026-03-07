---
phase: 04-pose-detection
plan: 01
subsystem: ui
tags: [vision, pose-detection, swiftui, canvas, userdefaults, cameraactor]

# Dependency graph
requires:
  - phase: 02-camera-setup-session-view
    provides: CameraActor global actor definition used for VisionProcessor isolation
provides:
  - VisionProcessor: CameraActor-isolated pose detection engine with DetectedPose published to MainActor
  - SkeletonOverlayView: SwiftUI Canvas skeleton renderer with Vision coordinate y-flip
  - SkeletonPreference: UserDefaults-backed ObservableObject skeleton toggle (default true)
affects:
  - 04-02-live-camera-wiring
  - 04-03-upload-mode-wiring

# Tech tracking
tech-stack:
  added: [Vision framework (VNDetectHumanBodyPoseRequest, VNSequenceRequestHandler)]
  patterns:
    - "@CameraActor-isolated class publishing via nonisolated(unsafe) + Task { @MainActor in }"
    - "SwiftUI Canvas for skeleton rendering with explicit coordinate flip"
    - "Combine $isEnabled.sink for UserDefaults persistence without didSet on @Published"

key-files:
  created:
    - CaliTimer/Vision/VisionProcessor.swift
    - CaliTimer/Vision/SkeletonOverlayView.swift
    - CaliTimer/Vision/SkeletonPreference.swift
  modified: []

key-decisions:
  - "VisionProcessor uses @CameraActor isolation (not @MainActor) per plan contract — downstream plans 02 and 03 depend on this as an explicit interface"
  - "nonisolated(unsafe) var detectedPose bridges @CameraActor to MainActor without task overhead per-read"
  - "SkeletonOverlayView uses VNHumanBodyPoseObservation.JointName.rawValue constants (e.g., left_wrist_2d) as dict keys — type-safe string production without importing JointName at use sites"
  - "project.yml requires no modification — path: CaliTimer is recursive, Vision/ subdirectory picked up automatically by XcodeGen"

patterns-established:
  - "Vision coordinate flip: canvasY = (1.0 - normalizedY) * size.height"
  - "Bone render order: bones first, joint dots on top — prevents dots from being obscured by lines"
  - "Partial skeleton graceful: skip any bone where either endpoint is missing from dict"

requirements-completed: [DETE-05]

# Metrics
duration: 8min
completed: 2026-03-06
---

# Phase 4 Plan 1: Pose Detection Primitives Summary

**Vision pose detection engine (VNSequenceRequestHandler, 8 handstand joints) + SwiftUI Canvas skeleton renderer (y-flip, ember style) + UserDefaults-backed toggle, providing concrete contracts for live camera and upload wiring plans**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-06T15:56:21Z
- **Completed:** 2026-03-06T16:04:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `VisionProcessor` — `@CameraActor`-isolated `ObservableObject` using `VNSequenceRequestHandler` created once per session; processes `CMSampleBuffer` frames, extracts 8 joints with confidence > 0.2, publishes `DetectedPose?` to `MainActor` via `nonisolated(unsafe)` + `Task { @MainActor in }`
- `SkeletonOverlayView` — SwiftUI `Canvas` that converts Vision normalized coords (0,0 bottom-left) to Canvas coords (0,0 top-left) via y-flip, draws 8 bones in ember (2pt, 0.85 opacity) then 8 joint dots (r=4) on top; partial skeletons render gracefully
- `SkeletonPreference` — `@MainActor ObservableObject` persisted to `UserDefaults`, default `true` on first launch, observed via Combine sink

## Task Commits

Each task was committed atomically:

1. **Task 1: VisionProcessor — CameraActor-isolated pose detection engine** - `1d7a828` (feat)
2. **Task 2: SkeletonOverlayView + SkeletonPreference** - `0cf4207` (feat)

## Files Created/Modified

- `CaliTimer/Vision/VisionProcessor.swift` — CameraActor-isolated pose detection engine; exports `VisionProcessor` and `DetectedPose`
- `CaliTimer/Vision/SkeletonOverlayView.swift` — SwiftUI Canvas renderer; exports `SkeletonOverlayView`
- `CaliTimer/Vision/SkeletonPreference.swift` — UserDefaults-backed toggle preference; exports `SkeletonPreference`

## Decisions Made

- `VisionProcessor` uses `@CameraActor` isolation (not `@MainActor` as CLAUDE.md suggests for simpler cases) because the plan's `must_haves` establish this as an explicit downstream contract — Plans 02 and 03 wire against this interface
- `project.yml` was not modified — the existing `path: CaliTimer` source entry is already recursive; XcodeGen picks up `Vision/` automatically
- Bone connection strings use `VNHumanBodyPoseObservation.JointName.rawValue` constants computed at type level rather than hard-coded strings — avoids typos while remaining `Sendable`-safe

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All three primitives exported with stable interfaces — Plans 02 and 03 have concrete contracts to build against
- Plan 02 needs to add `AVCaptureVideoDataOutput` + delegate to `CameraManager` and call `VisionProcessor.process(sampleBuffer:)` from the delegate
- Plan 03 needs to tap `AVPlayer` frames via `AVPlayerItemVideoOutput` and feed to `VisionProcessor`
- `SkeletonOverlayView` drops into `LiveSessionView` ZStack between camera preview layer (0) and controls layer (1)

## Self-Check: PASSED

- FOUND: CaliTimer/Vision/VisionProcessor.swift
- FOUND: CaliTimer/Vision/SkeletonOverlayView.swift
- FOUND: CaliTimer/Vision/SkeletonPreference.swift
- FOUND: .planning/phases/04-pose-detection/04-01-SUMMARY.md
- FOUND: commit 1d7a828 (Task 1)
- FOUND: commit 0cf4207 (Task 2)

---
*Phase: 04-pose-detection*
*Completed: 2026-03-06*
