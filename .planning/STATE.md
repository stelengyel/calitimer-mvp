---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: verifying
stopped_at: Completed 05-handstand-detection-timer-01-PLAN.md
last_updated: "2026-03-07T14:03:27.550Z"
last_activity: 2026-03-06 — Ember skeleton verified on live camera + upload mode on device; all 4 success criteria confirmed
progress:
  total_phases: 9
  completed_phases: 0
  total_plans: 4
  completed_plans: 1
  percent: 44
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** Automatic hold timing with zero manual input — the app knows when the hold starts and when it breaks, so athletes can focus entirely on the skill.
**Current focus:** Phase 5 — Handstand Detection + Timer

## Current Position

Phase: Phase 4 (Pose Detection) — 4 of 4 plans complete, phase DONE
Plan: 11 of 11 plans complete across Phases 1–4
Status: Phase 4 COMPLETE — all plans done, DETE-05 satisfied, human verification approved on device
Last activity: 2026-03-06 — Ember skeleton verified on live camera + upload mode on device; all 4 success criteria confirmed

Progress: [████░░░░░░] 44% (4 of 9 phases complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: ~8 min/plan
- Total execution time: ~36 min (Phase 1) + ~17 min (Phase 2) + ~22 min (Phase 3) = ~75 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-app-layout-navigation | 3 | ~36 min | ~12 min |
| 02-camera-setup-session-view | 3 | ~17 min | ~6 min |
| 03-video-upload-shell | 2 | ~22 min | ~11 min |

**Recent Trend:**
- Last 5 plans: P01 (18min), P02 (3min), P03 (15min), 02-P01 (10min), 02-P02 (2min), 02-P03 (5min)
- Trend: Stable, fast

*Updated after each plan completion*
| Phase 01-app-layout-navigation P01 | 18 | 2 tasks | 13 files |
| Phase 01-app-layout-navigation P02 | 3 | 2 tasks | 5 files |
| Phase 01-app-layout-navigation P03 | 15 | 2 tasks | 3 files |
| Phase 02-camera-setup-session-view P01 | 10 | 2 tasks | 5 files |
| Phase 02-camera-setup-session-view P02 | 2 | 2 tasks | 6 files |
| Phase 02-camera-setup-session-view P03 | 5 | 2 tasks | 1 file |
| Phase 03-video-upload-shell P01 | 4 | 2 tasks | 4 files |
| Phase 03-video-upload-shell P02 | 18 | 2 tasks | 4 files |
| Phase 04-pose-detection P01 | 8 | 2 tasks | 3 files |
| Phase 04-pose-detection P02 | 2 | 2 tasks | 5 files |
| Phase 04-pose-detection P03 | 2 | 2 tasks | 2 files |
| Phase 04-pose-detection P04 | - | verification | 0 files |
| Phase 05-handstand-detection-timer P01 | 3 | 2 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Research]: Stack is fully first-party Apple (Swift 6, SwiftUI, Vision, AVFoundation, SwiftData) — zero external dependencies
- [Research]: Handstand detection uses geometric classifier (feet above head in normalized coords), NOT per-joint confidence — Vision degrades on inverted poses
- [Research]: CameraActor (GlobalActor) + serial videoDataOutputQueue from day one — cannot be retrofitted; Swift 6 strict concurrency
- [Research]: VNSequenceRequestHandler created once per session (not per frame) — prevents jitter and CPU waste
- [Research]: AVAssetWriter initialized eagerly at session start to eliminate 5-7s initialization latency on hold detection
- [Roadmap]: Redesigned from 4-phase to 9-phase structure — phases 1–3 isolate infrastructure, camera, and upload shell before detection is wired in; Phase 5 (Handstand Detection + Timer) identified as center of gravity requiring robust manual testing
- [Phase 01-app-layout-navigation]: Used XcodeGen (project.yml) for Xcode project generation — reproducible and git-friendly vs binary pbxproj hand-editing
- [Phase 01-app-layout-navigation]: JetBrains Mono PostScript names confirmed as JetBrainsMono-Regular and JetBrainsMono-Bold (v2.304)
- [Phase 01-app-layout-navigation]: Empty @Model classes require explicit init() in Swift 6 — required by @Model macro, not optional
- [Phase 01-app-layout-navigation]: Custom Color extensions require explicit Color.textPrimary syntax — dot-shorthand fails in SwiftUI foregroundStyle() ShapeStyle context under Swift 6 strict concurrency
- [Phase 01-app-layout-navigation]: No @Environment(AppCoordinator) on non-navigating views (HistoryView, UploadModeView, SettingsView) — drawer and back button handle all navigation for those screens
- [Phase 01-app-layout-navigation]: Conditional dim overlay (if coordinator.isDrawerOpen) required — always-present transparent overlay blocks NavigationStack swipe-back gesture
- [Phase 01-app-layout-navigation]: DrawerView receives .environment(coordinator) separately as overlay — overlays outside NavigationStack do not inherit nav stack environment
- [Phase 01-app-layout-navigation]: .environment(coordinator) must be scoped to HomeView inside NavigationStack — not on NavigationStack itself — for correct propagation through navigationDestination views
- [Phase 02-camera-setup-session-view]: CameraManager is @MainActor + private serial DispatchQueue — simpler SwiftUI integration than @CameraActor; blocking ops dispatched via withCheckedContinuation + Self.queue; CameraActor @globalActor preserved for Phase 4 Vision frame processing
- [Phase 02-camera-setup-session-view]: CameraPreviewView uses sublayer pattern (PreviewUIView.attach(_:)) not layerClass override — layerClass creates a new AVCaptureVideoPreviewLayer whose session is nil at makeUIView time; sublayer uses the exact same layer object from CameraManager, no timing race
- [Phase 02-camera-setup-session-view]: permissionDenied @Published var on @MainActor CameraManager — enables direct SwiftUI binding without bridging
- [Phase 02-camera-setup-session-view]: SessionConfigSheet onConfirm closure pattern enables reuse in HomeView (pre-session) and LiveSessionView (mid-session) contexts
- [Phase 02-camera-setup-session-view]: Session @Model Phase 2 minimum: startedAt/skill/targetDuration only — endedAt and holds deferred to Phase 6
- [Phase 03-video-upload-shell]: handlePickerResult is async to satisfy @MainActor call from Task { @MainActor in } in PHPickerSheet.Coordinator
- [Phase 03-video-upload-shell]: Timer stored on self (not captured in closure) + MainActor.assumeIsolated pattern to avoid sending non-Sendable Timer across actor boundaries in Swift 6
- [Phase 03-video-upload-shell]: AVPlayer owned by parent view — VideoPlayerView consumes it — enables Phase 5 external playback control
- [Phase 03-video-upload-shell]: Zone 3 outer ZStack structure is a Phase 5 stability contract — inner content replaced by Phase 5 holds list, outer layout must not change
- [Phase 03-video-upload-shell]: Long video warning (>30 min) uses Task.sleep(0.5s) before asset.load(.duration) to wait for AVPlayerItem readiness before reading asset properties
- [Phase 04-pose-detection]: VisionProcessor uses @CameraActor isolation per plan contract — nonisolated(unsafe) + Task { @MainActor in } bridges to SwiftUI bindings
- [Phase 04-pose-detection]: project.yml requires no Vision group entry — path: CaliTimer is recursive, XcodeGen picks up Vision/ subdirectory automatically
- [Phase 04-pose-detection]: Task.detached used for nonisolated VisionProcessor.process() in upload pipeline — @CameraActor not used, @MainActor is the actual isolation per CLAUDE.md preference
- [Phase 04-pose-detection]: AVPlayerItemVideoOutput + periodic time observer at 33ms interval is the upload-mode frame tap pattern — hasNewPixelBuffer guard holds skeleton when paused without extra state
- [Phase 04-pose-detection]: captureOutput calls visionProcessor.process() directly (nonisolated on both sides) — no Task actor bridge needed, zero actor hop overhead per frame
- [Phase 04-pose-detection]: skeletonPref passed as let parameter to SessionConfigSheet from LiveSessionView — single instance shared mid-session; independent instances in HomeView and SettingsView share UserDefaults key
- [Phase 05-handstand-detection-timer]: Lenient 1+1 joint check (min wrist Y < max ankle Y) used for handstand classifier — 4-joint requirement explicitly rejected per CONTEXT.md
- [Phase 05-handstand-detection-timer]: Entry debounce = 5 frames, exit debounce = 12 frames for HoldStateMachine — within CONTEXT.md specified ranges
- [Phase 05-handstand-detection-timer]: Hold timestamps backdated: start = first inverted frame, end = first non-inverted frame; upload mode uses CMTime delta not wall clock

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: HandstandClassifier angle thresholds (wrist-y < ankle-y margin, vertical alignment tolerance, joint confidence cutoffs) must be determined empirically — no specific values from research
- [Phase 5]: Detection accuracy floor needs a concrete acceptance criterion before Phase 5 is considered complete (research suggests validating against 50-100 real handstand frames)
- [Phase 7]: Clip-start delay (1–2s accepted) needs user validation — right value for athletes must be confirmed with real use
- [Phase 9]: Human Flag detection may require architecture-level camera orientation decisions — needs research before planning

## Session Continuity

Last session: 2026-03-07T14:03:27.548Z
Stopped at: Completed 05-handstand-detection-timer-01-PLAN.md
Resume file: None
