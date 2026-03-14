---
phase: 05-handstand-detection-timer
plan: 01
subsystem: vision
tags: [vision, handstand, state-machine, audio, combine, coreMedia]

# Dependency graph
requires:
  - phase: 04-pose-detection
    provides: DetectedPose struct, VisionProcessor publishing per-frame joint positions in normalized Vision coords
provides:
  - HandstandClassifier.isHandstand(_ pose: DetectedPose?) -> Bool — pure lenient 1+1 geometric classifier
  - HoldStateMachine with searching/detected/timing states, backdated timestamps, CMTime upload mode, target alert
  - DetectionIndicatorPreference UserDefaults toggle mirroring SkeletonPreference pattern
affects:
  - 05-02 — UI plans build on HoldStateMachine.process(pose:) and DetectionIndicatorPreference.isEnabled
  - 05-03 — Upload mode scanner sets currentVideoTime before each process() call

# Tech tracking
tech-stack:
  added: [AudioToolbox (AudioServicesPlaySystemSound)]
  patterns: [pure enum classifier with static methods, MainActor ObservableObject state machine, CMTime video timestamp tracking]

key-files:
  created:
    - CaliTimer/Vision/HandstandClassifier.swift
    - CaliTimer/Vision/HoldStateMachine.swift
    - CaliTimer/Vision/DetectionIndicatorPreference.swift
  modified: []

key-decisions:
  - "Lenient 1+1 joint check (min wrist Y < max ankle Y) — 4-joint requirement explicitly rejected per CONTEXT.md user decision"
  - "Joint key strings (left_wrist_2_joint, right_wrist_2_joint, left_ankle_joint, right_ankle_joint) marked as empirically determined — debugPrintKeys() included for Wave 0 runtime verification"
  - "Entry debounce = 5 frames (~0.17s at 30fps), exit debounce = 12 frames (~0.4s at 30fps) — within CONTEXT.md specified ranges"
  - "Audio-only target alert (AudioServicesPlaySystemSound 1057 Tink) — no haptics per user decision"
  - "Timer.publish only active during .timing state — upload mode uses CMTime delta in confirmExit(), never wall clock"
  - "Hold timestamps backdated: start = potentialStart (first inverted frame), end = potentialEnd (first non-inverted frame)"

patterns-established:
  - "HoldRecord: Identifiable struct with both Date? and CMTime-derived Double? fields to support live and upload modes from single type"
  - "resetForNewScan() pattern for upload pipeline — clears all state except targetDuration"

requirements-completed: [DETE-01, DETE-02, DETE-06, DETE-07]

# Metrics
duration: 3min
completed: 2026-03-07
---

# Phase 5 Plan 01: Core Detection Types Summary

**Geometric handstand classifier + 3-state hold machine with backdated CMTime timestamps and single-fire audio target alert**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-07T11:59:28Z
- **Completed:** 2026-03-07T12:02:17Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- HandstandClassifier: pure static enum, lenient 1+1 wrist/ankle geometric check, debugPrintKeys() for Wave 0 runtime joint key verification
- HoldStateMachine: searching → detected (entry debounce) → timing (confirmed) → searching (exit debounce), with wall clock and CMTime dual-path timestamp tracking
- DetectionIndicatorPreference: exact mirror of SkeletonPreference, UserDefaults key "detectionIndicatorEnabled", default true

## Task Commits

Each task was committed atomically:

1. **Task 1: HandstandClassifier — pure static classifier** - `34a9c23` (feat)
2. **Task 2: HoldStateMachine + DetectionIndicatorPreference** - `502d38d` (feat)

## Files Created/Modified

- `CaliTimer/Vision/HandstandClassifier.swift` — Pure static handstand geometry classifier, lenient 1+1 check, debugPrintKeys() debug helper
- `CaliTimer/Vision/HoldStateMachine.swift` — @MainActor state machine: HoldState enum, HoldRecord Identifiable struct, process(pose:), resetForNewScan(), target alert
- `CaliTimer/Vision/DetectionIndicatorPreference.swift` — @MainActor UserDefaults-backed toggle, mirrors SkeletonPreference exactly

## Decisions Made

- Lenient 1+1 classifier: `min(wristY) < max(ankleY)` with no margin — this matches user decision to avoid false negatives on side-on camera angles; can be tightened if false positives emerge empirically
- `debugPrintKeys()` kept in production build (not behind `#if DEBUG`) intentionally for Wave 0 camera verification — callers should remove or gate before App Store submission
- `AudioServicesPlaySystemSound(1057)` (Tink): short and clean, respects silent mode, confirmed audio-only per user specification

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Build succeeded immediately on both task additions.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three foundation types ready for 05-02 (LiveSession UI wiring) and 05-03 (upload scanner integration)
- HandstandClassifier joint key strings need Wave 0 runtime verification via debugPrintKeys() before final classifier tuning
- HoldStateMachine.currentVideoTime and resetForNewScan() ready for upload pipeline in 05-03

---
*Phase: 05-handstand-detection-timer*
*Completed: 2026-03-07*
