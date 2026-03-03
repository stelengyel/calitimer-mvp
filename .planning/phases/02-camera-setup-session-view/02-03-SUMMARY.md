---
phase: 02-camera-setup-session-view
plan: 03
subsystem: verification
tags: [avfoundation, uiviewrepresentable, camera, bugfix, human-verification]

# Dependency graph
requires:
  - phase: 02-02
    provides: CameraPreviewView, LiveSessionView, SessionConfigSheet, HomeView sheet flow, Session @Model

provides:
  - Phase 2 human verification: all UAT criteria confirmed on iOS Simulator
  - Bug fix: CameraPreviewView sublayer pattern (replaced layerClass override — timing issue)

affects: [03-video-recording]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - CameraPreviewView sublayer pattern: plain UIView + attach(_:) adds CameraManager's layer as sublayer
      (replaces layerClass override — avoids makeUIView/startSession timing race)

key-files:
  modified:
    - CaliTimer/UI/LiveSession/CameraPreviewView.swift

key-decisions:
  - "Switched CameraPreviewView from layerClass override to sublayer pattern — layerClass creates a NEW
    AVCaptureVideoPreviewLayer per UIView instance; makeUIView runs before startSession() assigns the
    session, so the UIView's layer always had session=nil. Sublayer pattern passes CameraManager's
    own previewLayer directly, so the session assignment in configureAndStart() is immediately visible."
  - "No new @Published state added — the sublayer approach requires zero timing gates or isSessionRunning
    flags; the layer self-activates once session is assigned."

requirements-completed: [CAMR-01, CAMR-02, SESS-01, SESS-02]

# Metrics
duration: ~5min (gap closure + re-verify)
completed: 2026-03-02
---

# Phase 02 Plan 03: Human Verification + Camera Feed Bug Fix

**All Phase 2 UAT criteria confirmed on iOS Simulator after fixing black camera feed (layerClass → sublayer pattern)**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-03-02
- **Tasks:** 2 (build/run + human verify)
- **Files modified:** 1 (bug fix)

## Accomplishments

- Diagnosed black camera feed: `CameraPreviewView` used `layerClass` override which created a separate
  `AVCaptureVideoPreviewLayer`; `makeUIView` copied the session reference before `startSession()` set it,
  leaving the UIView's layer with `session = nil` forever.
- Fixed by switching to sublayer pattern: `PreviewUIView` is now a plain `UIView` with an `attach(_:)` method
  that adds CameraManager's existing `previewLayer` as a sublayer. Same object → session assignment in
  `configureAndStart()` is immediately visible.
- All 6 UAT criteria verified on iOS Simulator (iPhone 17):

  | # | Check | Result |
  |---|-------|--------|
  | 1 | Home screen shows "Start Session" button | Pass |
  | 2 | Tap "Start Session" → SessionConfigSheet slides up | Pass |
  | 3 | Confirm in sheet → navigates to LiveSessionView | Pass |
  | 4 | LiveSessionView shows live camera feed (full-bleed) | Pass (after fix) |
  | 5 | Flip and End Session buttons visible | Pass |
  | 6 | Tapping End Session returns to Home | Pass |

## Task Commits

1. **Bug fix: CameraPreviewView layerClass → sublayer pattern** - `fix(02)` commit

## Files Modified

- `CaliTimer/UI/LiveSession/CameraPreviewView.swift` — sublayer pattern; `PreviewUIView` now uses `attach(_:)`
  instead of `layerClass` override

## Decisions Made

- `layerClass` override considered idiomatic but fundamentally incompatible with the async session
  lifecycle: the view renders synchronously, the session starts asynchronously. Sublayer pattern
  is equally hardware-accelerated and compatible with async initialization.

## Deviations from Plan

- Gap closure required: camera feed showed black background after permission grant. Root cause was
  the `layerClass` / async timing mismatch, not a permission or session configuration issue.

## Issues Encountered

- **Black camera preview** — `CameraPreviewView.makeUIView` ran before `startSession()` could assign
  `previewLayer.session`; the UIView's own backing layer (different object) never received the session.
  Fixed by attaching CameraManager's layer directly.

## User Setup Required

None.

## Next Phase Readiness

- Phase 2 requirements CAMR-01, CAMR-02, SESS-01, SESS-02 fully satisfied
- Phase 3 (video recording / AVAssetWriter shell) can proceed

## Self-Check: PASSED

- FOUND: CaliTimer/UI/LiveSession/CameraPreviewView.swift (sublayer pattern)
- Human verification: all 6 UAT items confirmed
- FOUND: .planning/phases/02-camera-setup-session-view/02-03-SUMMARY.md

---
*Phase: 02-camera-setup-session-view*
*Completed: 2026-03-02*
