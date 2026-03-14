# Phase 5: Handstand Detection + Timer - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

HoldStateMachine, live timer, detection state indicator, target alert (audio), target duration control wired live, and the same detection pipeline running against imported video in upload mode — producing a hold list with timestamps. Video recording (Phase 7) and session history persistence (Phase 6) are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Handstand Classifier

- **Primary criterion:** At least 1 wrist AND 1 ankle detected with confidence > 0.2, where wrist Y < ankle Y in Vision normalized space (wrists below ankles = inverted)
- **Minimum joints:** 1 wrist + 1 ankle (lenient — supports side-on camera angles). Flagged as tunable: this threshold is empirically determined and likely to be adjusted during testing
- **Stricter criteria (NOT used):** Requiring all 4 joints (both wrists + both ankles) or additional body alignment was rejected in favor of side-on angle support

### Debounce + Accuracy (Hold State Machine)

- **Entry debounce:** ~5 consecutive inverted frames required before transitioning searching to timing. Prevents false starts from jump-throughs or kip-up passes.
- **Exit debounce:** 10-15 consecutive non-inverted frames required before ending a hold. Prevents phantom terminations from single bad frames mid-hold.
- **Backdated timing (critical):** On frame 1 of inversion, record `potentialStart` timestamp. On confirmed entry (frame ~5), start displaying the timer but set start time = `potentialStart`. Same for exit: record `potentialEnd` on first non-inverted frame; use it as hold end time once exit is confirmed. Measured hold duration is accurate from actual first/last inverted frame, not from when debounce resolves. Timer display may lag ~0.2s behind real start — acceptable.

### Detection State Indicator

- **Location:** Top-center in the LiveSessionView ZStack overlay, not blocking the body in frame
- **Visual:** Icon-only colored dot (no text label) — minimal footprint
  - Grey = searching
  - Ember (brand orange) = detected (pose seen, entry debounce not yet confirmed)
  - Green = timing (hold confirmed, timer running)
- **Animation:** Dot pulses (gentle breathing animation) during timing state only
- **Persistence:** Always visible during a session (no auto-hide)
- **Toggle:** Independently toggleable via the session gear icon (SessionConfigSheet) and the main Settings page — same pattern as skeleton overlay toggle

### Timer Display

- **Location:** Top-center, directly below the detection indicator dot — they form a grouped cluster at top of camera overlay
- **Format:** MM:SS (e.g. `0:12`, `1:04`) — whole seconds, no tenths
- **Active hold behavior:** Counts up continuously. After target is reached, timer turns green and continues counting (does not stop at target)
- **When hold ends:** Freezes on the final hold time — persists until the next hold starts, then resets. If no hold has occurred yet, shows `0:00`
- **Between holds:** Always visible showing the last hold's final time (or `0:00` if none)

### Target Alert

- **Visual alert:** Timer text color changes to green when target duration is reached. No flash, no banner — subtle and non-disruptive mid-hold
- **Audio alert:** System sound (AudioServicesPlaySystemSound short beep) — fires once at target duration. No haptics.
- **Post-target behavior:** Timer keeps counting past the target. Green color persists for the remainder of the hold.
- **Silent mode:** System sound respects device silent mode — no sound if silenced (acceptable)

### Upload Mode Output

- **Processing trigger:** Automatically starts scanning on video import — no user tap required
- **UI during scan:** Same detection state dot and timer shown as in live session mode. This doubles as a debug view for validating the classifier against real training footage
- **Results list:** After scan completes, a scrollable list populates in Zone 3 of UploadModeView (the Phase 3 stability contract area). Each row shows: `[n]. [start time] - [end time] - [duration]` e.g. `1. 0:23 - 0:35 - 12s`
- **No video playback during scan:** Detection runs at full speed (not real-time playback rate) — scanner seeks through frames independently
- **Empty state:** If no holds detected, show a message in Zone 3 (e.g. "No handstand holds detected")

### Claude's Discretion

- Exact debounce frame counts within the specified ranges (entry: ~5, exit: 10-15)
- Confidence threshold (0.2 baseline — adjust if false positives/negatives are observed during testing)
- Exact pulse animation parameters (period, scale factor) for the timing-state dot
- System sound ID selection (specific beep from iOS built-in sounds)
- Zone 3 layout details (list row styling, spacing, empty state illustration)

</decisions>

<specifics>
## Specific Ideas

- Upload mode is intentionally used for testing and debugging the classifier — the detection state dot and timer should behave identically to live mode while scanning a video
- The 1-wrist + 1-ankle minimum is a conscious trade-off for side-on camera support — document it clearly so it is easy to change to 4-joint minimum if false positives emerge during real-world testing
- Timer + indicator grouped at top-center: athlete can glance at the top of frame to see both state and time without moving their eyes across the screen

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets

- `VisionProcessor` (CaliTimer/Vision/VisionProcessor.swift): Already publishes `DetectedPose?` to `@MainActor`. Contains 8 joints: wrists, shoulders, hips, ankles. Confidence threshold >0.2 already implemented. `HoldStateMachine` consumes `$detectedPose` stream.
- `SkeletonPreference` (CaliTimer/Vision/SkeletonPreference.swift): Pattern for UserDefaults-backed toggle with independent toggle in `SessionConfigSheet` + Settings. Detection indicator toggle should use the same pattern.
- `SessionConfigSheet` (CaliTimer/UI/LiveSession/SessionConfigSheet.swift): Already has `targetHoldDurationSeconds` via `@AppStorage` + 5s stepper. Phase 5 wires this value to the state machine — no layout changes needed.
- `LiveSessionView` ZStack layers (established): camera -> skeleton overlay -> controls. Detection indicator + timer slot in above skeleton, in the controls layer at top-center.

### Established Patterns

- `@MainActor` + `@Published` for all SwiftUI-bound state — `HoldStateMachine` should be `@MainActor`
- `nonisolated` processing methods called from camera queue (see `VisionProcessor.process()`) — state machine receives already-bridged data on MainActor
- `onReceive(visionProcessor.$detectedPose)` in both `LiveSessionView` and `UploadModeView` — state machine plugs into this same stream
- `SkeletonPreference` UserDefaults toggle pattern — reuse for detection indicator toggle

### Integration Points

- `LiveSessionView.onReceive(cameraManager.visionProcessor.$detectedPose)` — add `holdStateMachine.process(pose:)` call here
- `UploadModeView.onReceive(manager.visionProcessor.$detectedPose)` — same machine processes upload frames
- Zone 3 of `UploadModeView` (outer ZStack) — Phase 3 stability contract: inner content here is the holds result list. Outer layout must not change.
- `SessionConfigSheet.onConfirm` closure — already passes `targetDuration: TimeInterval?` to `LiveSessionView`; state machine receives this value

</code_context>

<deferred>
## Deferred Ideas

- Using joint angles (e.g. feet-hips-wrists) in handstand criteria for stricter hold definition. This is something we might implement at a later date if necessary.

</deferred>

---

*Phase: 05-handstand-detection-timer*
*Context gathered: 2026-03-07*
