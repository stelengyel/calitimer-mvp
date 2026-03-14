---
phase: 02-camera-setup-session-view
plan: 02
subsystem: ui
tags: [swiftui, avfoundation, swiftdata, camera, uiviewrepresentable, appcoordinator]

# Dependency graph
requires:
  - phase: 02-01
    provides: CameraActor global actor + CameraManager with AVCaptureSession lifecycle, previewLayer, permissionDenied
  - phase: 01-app-layout-navigation
    provides: AppCoordinator navigate/popToRoot, brand system, NavigationStack wiring

provides:
  - CameraPreviewView: UIViewRepresentable with PreviewUIView layerClass override for full-bleed camera feed
  - LiveSessionView: full-bleed ZStack with camera preview + overlaid controls (flip, End Session, gear)
  - SessionConfigSheet: shared pre/mid-session config sheet (skill + target hold time, @AppStorage persistence)
  - HomeView: Start Session now opens SessionConfigSheet before navigating to liveSession
  - Session @Model: Phase 2 minimum schema (startedAt, skill, targetDuration)
  - Session record created and inserted into SwiftData on every session start

affects: [05-handstand-detection, 06-session-data-model, 03-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - UIViewRepresentable with layerClass override for AVCaptureVideoPreviewLayer (hardware-accelerated, no frame copy)
    - @AppStorage for user preferences persisted across sessions
    - ZStack full-bleed camera with overlaid SwiftUI controls using .ultraThinMaterial
    - Task { @CameraActor in } for calling CameraActor-isolated methods from SwiftUI button actions
    - .task modifier for async session start on view appearance (hops to CameraActor)
    - onConfirm closure pattern for SessionConfigSheet reuse in two distinct contexts

key-files:
  created:
    - CaliTimer/UI/LiveSession/CameraPreviewView.swift
    - CaliTimer/UI/LiveSession/SessionConfigSheet.swift
  modified:
    - CaliTimer/UI/LiveSession/LiveSessionView.swift
    - CaliTimer/UI/Home/HomeView.swift
    - CaliTimer/Storage/Models/Session.swift
    - CaliTimer.xcodeproj/project.pbxproj

key-decisions:
  - "PreviewUIView uses layerClass override (layer IS the preview layer) — zero additional AVCaptureVideoPreviewLayer creation, hardware-accelerated"
  - "AVCaptureSession confined to CameraManager — no SwiftUI file references it directly (Swift 6 Sendable constraint)"
  - "flipCamera() called via Task { @CameraActor in } from SwiftUI button — CameraActor isolation requires explicit hop from @MainActor context"
  - "SessionConfigSheet uses onConfirm closure pattern to serve both HomeView (pre-session) and LiveSessionView (mid-session gear) contexts"
  - "Session @Model deferred endedAt and holds relationship to Phase 6 — Phase 2 minimum: startedAt, skill, targetDuration only"
  - "@AppStorage(targetHoldDuration) persists target hold time across sessions — user preference survives app restarts"
  - "Handstand-only skill picker: no placeholder slots for future skills (locked decision per CONTEXT.md)"

patterns-established:
  - "CameraPreviewView pattern: PreviewUIView.layerClass = AVCaptureVideoPreviewLayer.self, layoutSubviews keeps frame in sync"
  - "ZStack full-bleed: Layer 0 camera/fallback with .ignoresSafeArea(), Layer 1 VStack overlay with material backgrounds"
  - "Permission denied inline: shown as ZStack content replacement, not modal/sheet — same layout hierarchy"
  - "Session creation: HomeView sheet onConfirm creates Session, inserts into modelContext, then navigates"

requirements-completed: [CAMR-01, CAMR-02, SESS-01, SESS-02]

# Metrics
duration: 2min
completed: 2026-03-02
---

# Phase 02 Plan 02: Camera + Session View Wiring Summary

**Live camera feed wired into full-bleed SwiftUI ZStack via UIViewRepresentable layerClass override, with SessionConfigSheet creating SwiftData Session records on every session start**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-02T18:53:26Z
- **Completed:** 2026-03-02T18:55:38Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Replaced Session @Model empty scaffold with Phase 2 minimum schema (startedAt, skill, targetDuration)
- Created CameraPreviewView using PreviewUIView layerClass override — hardware-accelerated, full-bleed, no frame copying
- Replaced LiveSessionView placeholder with full-bleed ZStack: camera preview filling screen edge-to-edge, flip button top-right, End Session bottom-left (small), gear icon bottom-right
- Created SessionConfigSheet: Handstand-only skill label, 5-second-increment target hold stepper, @AppStorage persistence across sessions, onConfirm closure for dual-context reuse
- Updated HomeView: Start Session now opens SessionConfigSheet; onConfirm creates Session @Model, inserts into SwiftData, navigates to liveSession

## Task Commits

Each task was committed atomically:

1. **Task 1: Update Session @Model with Phase 2 minimum properties** - `c50279d` (feat)
2. **Task 2: CameraPreviewView, LiveSessionView ZStack, SessionConfigSheet, HomeView sheet** - `0add2a2` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `CaliTimer/Storage/Models/Session.swift` - Session @Model with startedAt, skill, targetDuration; init(skill:targetDuration:)
- `CaliTimer/UI/LiveSession/CameraPreviewView.swift` - PreviewUIView (layerClass = AVCaptureVideoPreviewLayer) + CameraPreviewView UIViewRepresentable wrapper
- `CaliTimer/UI/LiveSession/LiveSessionView.swift` - Full-bleed ZStack: camera feed + overlaid controls + permission denied inline fallback
- `CaliTimer/UI/LiveSession/SessionConfigSheet.swift` - Handstand skill label, target hold stepper, @AppStorage persistence, onConfirm closure
- `CaliTimer/UI/Home/HomeView.swift` - Start Session opens sheet; onConfirm creates Session + navigates
- `CaliTimer.xcodeproj/project.pbxproj` - Regenerated via XcodeGen to include new Swift files

## Decisions Made

- Used PreviewUIView `layerClass` override so the UIView's own backing layer IS the AVCaptureVideoPreviewLayer — standard Apple pattern, hardware-accelerated, no secondary layer allocation
- `flipCamera()` invoked via `Task { @CameraActor in cameraManager.flipCamera() }` — CameraActor isolation prevents direct call from @MainActor SwiftUI context
- `stopSession()` in `.onDisappear` uses same `Task { @CameraActor in }` pattern for consistency
- SessionConfigSheet accepts `onConfirm` closure so it can be reused in both HomeView (creates Session + navigates) and LiveSessionView (mid-session config update, deferred to Phase 6)
- Session @Model limited to startedAt/skill/targetDuration — endedAt, holds relationship, and SkillPersonalBest linkage deferred to Phase 6

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CAMR-01 (live camera feed), CAMR-02 (camera flip), SESS-01 (session navigation flow), SESS-02 (Session @Model) are functionally complete
- Plan 02-03 (human verification) can proceed: build and run on simulator to verify camera feed, flip button, End Session, SessionConfigSheet, and Session insert
- Phase 5 (handstand detection) will add VNDetectHumanBodyPoseRequest wired to CameraManager's video output
- Phase 6 will expand Session @Model with endedAt and holds relationship

## Self-Check: PASSED

- FOUND: CaliTimer/Storage/Models/Session.swift
- FOUND: CaliTimer/UI/LiveSession/CameraPreviewView.swift
- FOUND: CaliTimer/UI/LiveSession/LiveSessionView.swift
- FOUND: CaliTimer/UI/LiveSession/SessionConfigSheet.swift
- FOUND: CaliTimer/UI/Home/HomeView.swift
- FOUND commit c50279d (feat(02-02): add Phase 2 minimum properties to Session @Model)
- FOUND commit 0add2a2 (feat(02-02): wire CameraManager into SwiftUI views + SessionConfigSheet)
- FOUND: .planning/phases/02-camera-setup-session-view/02-02-SUMMARY.md

---
*Phase: 02-camera-setup-session-view*
*Completed: 2026-03-02*
