---
phase: 05-handstand-detection-timer
plan: 02
subsystem: ui
tags: [swiftui, hold-indicator, hold-timer, live-session, state-machine, user-defaults]

# Dependency graph
requires:
  - phase: 05-handstand-detection-timer
    plan: 01
    provides: HoldStateMachine, HoldState, DetectionIndicatorPreference, HandstandClassifier.debugPrintKeys
affects:
  - 05-03 — upload mode scanner needs holdStateMachine.resetForNewScan() and process() wired into UploadModeView
  - 05-04 — manual test wave validates indicator+timer end-to-end on device

# Tech tracking
tech-stack:
  added: []
  patterns: [conditional indicator cluster at top-center of camera overlay VStack, @ObservedObject preference sharing between LiveSessionView and SessionConfigSheet]

key-files:
  created:
    - CaliTimer/UI/LiveSession/HoldIndicatorView.swift
    - CaliTimer/UI/LiveSession/HoldTimerView.swift
  modified:
    - CaliTimer/UI/LiveSession/LiveSessionView.swift
    - CaliTimer/UI/LiveSession/SessionConfigSheet.swift
    - CaliTimer/UI/Settings/SettingsView.swift
    - CaliTimer/UI/Home/HomeView.swift

key-decisions:
  - "indicatorPref @ObservedObject passed from LiveSessionView into SessionConfigSheet — shares single instance mid-session; HomeView passes fresh DetectionIndicatorPreference() since it has no live session instance"
  - "Indicator+timer cluster placed at top-center via Spacer+VStack inside Layer 1 VStack, above the flip button row, padded .top 64 to clear notch"
  - "XcodeGen regeneration required after adding HoldIndicatorView.swift and HoldTimerView.swift — project.yml path is recursive but .xcodeproj was stale"
  - "debugPrintKeys() call left in onReceive per plan spec — intentional Wave 0 joint key verification aid, not a bug"

patterns-established:
  - "Toggle row pattern: HStack with VStack(label+subtitle) + Spacer + Toggle.labelsHidden — reused for skeleton and indicator rows in both SessionConfigSheet and SettingsView"
  - "targetReached computed property pattern: derive bool from holdStateMachine state inline in parent view rather than publishing from state machine"

requirements-completed: [DETE-03, DETE-04, DETE-06, DETE-07]

# Metrics
duration: 4min
completed: 2026-03-07
---

# Phase 5 Plan 02: Live Session UI Summary

**Detection indicator dot (grey/ember/green + pulse) and MM:SS hold timer wired into LiveSessionView, toggled from gear sheet and Settings, all driven by HoldStateMachine per-frame**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-07T14:07:00Z
- **Completed:** 2026-03-07T14:10:44Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- HoldIndicatorView: 10pt dot, grey=searching / ember=detected / green=timing, pulse animation only during .timing
- HoldTimerView: monospaced MM:SS, white normally, turns green when targetReached
- LiveSessionView fully wired: holdStateMachine processes every frame from onReceive, indicator+timer cluster at top-center conditioned on indicatorPref.isEnabled, targetDuration set on session start and updated mid-session via gear sheet
- SessionConfigSheet updated with indicatorPref parameter and second toggle row (Detection Indicator), matching existing skeleton row pattern
- SettingsView Detection section now has two rows: Skeleton Overlay and Detection Indicator

## Task Commits

Each task was committed atomically:

1. **Task 1: HoldIndicatorView + HoldTimerView** - `0d4f2e5` (feat)
2. **Task 2: Wire LiveSessionView + SessionConfigSheet + SettingsView** - `e79fbf6` (feat)

## Files Created/Modified

- `CaliTimer/UI/LiveSession/HoldIndicatorView.swift` — Colored pulse dot, grey/ember/green per HoldState, pulse during .timing only
- `CaliTimer/UI/LiveSession/HoldTimerView.swift` — MM:SS monospaced timer, turns green when targetReached
- `CaliTimer/UI/LiveSession/LiveSessionView.swift` — Added holdStateMachine + indicatorPref @StateObjects, indicator+timer cluster overlay, process() wiring in onReceive, targetDuration setup in .task and onConfirm
- `CaliTimer/UI/LiveSession/SessionConfigSheet.swift` — Added indicatorPref @ObservedObject param and Detection Indicator toggle row below Skeleton Overlay row
- `CaliTimer/UI/Settings/SettingsView.swift` — Added indicatorPref @StateObject and Detection Indicator toggle row in Detection section
- `CaliTimer/UI/Home/HomeView.swift` — Passes fresh DetectionIndicatorPreference() to SessionConfigSheet

## Decisions Made

- `indicatorPref` is shared as @ObservedObject from LiveSessionView into SessionConfigSheet (same instance mid-session). HomeView has no live session context so passes a fresh `DetectionIndicatorPreference()` — both paths read/write the same UserDefaults key, so the toggle persists correctly regardless of entry point.
- Indicator+timer cluster placed at top-center by wrapping in `HStack { Spacer() … Spacer() }` inside the existing Layer 1 VStack, before the flip button row. `.padding(.top, 64)` clears the notch/safe area without using ignoresSafeArea.
- XcodeGen must be re-run when new Swift files are added because the .xcodeproj is generated (not hand-edited) and doesn't pick up new files without regeneration.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] XcodeGen regeneration required for new view files**
- **Found during:** Task 2 verification build
- **Issue:** HoldIndicatorView and HoldTimerView not found in scope — the .xcodeproj was stale and did not include the two new files even though XcodeGen's path is recursive
- **Fix:** Ran `xcodegen generate` to regenerate CaliTimer.xcodeproj, included CaliTimer.xcodeproj/project.pbxproj in the Task 2 commit
- **Files modified:** CaliTimer.xcodeproj/project.pbxproj
- **Verification:** Build succeeded after regeneration
- **Committed in:** e79fbf6 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking — XcodeGen stale project)
**Impact on plan:** Required but minimal — standard XcodeGen workflow. No scope creep.

## Issues Encountered

None beyond the XcodeGen regeneration documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Full detection loop visible in live session: grey dot → ember → green + counting timer → frozen on hold end
- HandstandClassifier.debugPrintKeys() printing to console on each detected frame for Wave 0 joint key validation
- 05-03 (upload mode scanner integration) can now wire holdStateMachine.resetForNewScan() and process() into UploadModeView
- 05-04 (manual test wave) should validate the complete detection + indicator + timer loop on a real device

---
*Phase: 05-handstand-detection-timer*
*Completed: 2026-03-07*
