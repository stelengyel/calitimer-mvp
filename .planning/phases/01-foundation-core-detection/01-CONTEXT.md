# Phase 1: Foundation + Core Detection - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Athletes can run a handstand training session with automatic detection and timing — no manual input during training. The app detects holds, times them, fires an alert at the target duration, and saves session history with personal bests. A minimal developer tool (no polished UX) allows importing a video to test the detection pipeline against real footage.

</domain>

<decisions>
## Implementation Decisions

### App navigation structure
- The app has a **Home page** as the root screen
- Home page shows: current personal best card(s) and a Start Session button
- Tapping Start Session **pushes** to the full-screen camera session view (standard push navigation)
- History is accessed from Home via a **sliding navigation** (swipe or button reveals the history page)
- There is no tab bar — Home is the hub

### Session screen layout
- Camera preview fills the screen **edge-to-edge** (full-screen); controls and timer float as overlays on top
- **Timer**: top center, large and prominent numerals — glanceable from a distance
- **Controls**: persistent bottom toolbar, always visible — contains: skeleton toggle, detection overlay toggle, camera flip button, End Session button
- Target duration is set on the **home screen before starting**, not on the camera view

### Detection state indicator
- A **colored ring/border around the camera feed** communicates detection state
  - `searching` → gray ring (neutral/inactive)
  - `detected` (accumulating frames) → yellow ring (attention, building)
  - `timing` (active hold) → green ring (go/active)
- When a hold **ends**: ring briefly flashes and the hold duration (e.g., "12.4s") is shown for a moment before resetting to gray
- When the detection indicator is **toggled OFF**: ring completely disappears; timer still counts up as the only feedback

### Session history layout
- History page shows sessions **grouped by session, with individual holds expandable**
  - Each session row: date + total holds + best hold for that session
  - Tap session row to expand and see individual hold durations
- Home page has a **prominent PB card** at the top showing the current personal best duration

### Target duration UX
- Set on the **home screen** before starting a session
- Interaction: **tap to enter a number** (numeric keyboard) — exact seconds, any value
- When the target duration is reached during an active hold:
  - A **classic timer beep sound** plays (no silent haptic-only mode)
  - Timer **continues counting up** past the target — athlete sees how much they exceeded it
  - Beep fires once; hold continues until detection ends

### Claude's Discretion
- Exact typography, spacing, and corner radius of UI elements
- Specific sound asset for the target beep (system sound or custom short tone)
- Loading/empty states within session history (e.g., "No sessions yet")
- Exact increment step for the target duration numeric input (e.g., whether to validate a minimum value)
- Skeleton overlay and joint rendering color choices

</decisions>

<specifics>
## Specific Ideas

- "A classic timer beep" — athlete expects an audible countdown/gym-style signal when they hit their goal
- Detection ring is the primary visual feedback during training; it should be unmissable from across a room (athlete props phone on a stand and trains)
- Home page is the launch destination — not a camera view, not a history list

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing Swift code

### Established Patterns
- All patterns are being established in this phase. RESEARCH.md defines the reference architecture: CameraActor (global actor for AVCaptureSession), PoseDetector (actor), HandstandClassifier (pure struct), HoldStateMachine (value type), SessionCoordinator (@Observable @MainActor).

### Integration Points
- The ring overlay integrates with HoldStateMachine.state — state changes drive ring color transitions
- The timer label at top integrates with SessionCoordinator.currentHoldDuration, updated at 10Hz
- The bottom toolbar toggle buttons bind to SessionCoordinator.isSkeletonVisible and SessionCoordinator.isDetectionStateVisible
- The home screen target duration field binds to SessionCoordinator.targetDuration (or a pre-session config object)
- History page reads Session + Hold SwiftData entities via @Query

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-core-detection*
*Context gathered: 2026-03-01*
