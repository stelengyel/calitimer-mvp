# Phase 2: Camera Setup + Session View - Context

**Gathered:** 2026-03-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Live camera feed running in the session screen, front/rear camera toggle, session start/end controls, and a pre-session config sheet (skill + target hold time). The app must be fully usable propped on a stand with no hands required after session starts. Detection, timing, and hold recording are out of scope for this phase.

</domain>

<decisions>
## Implementation Decisions

### Camera Layout
- Full-bleed camera feed — camera takes the entire screen edge-to-edge
- Controls overlaid on top of feed (not below in a panel)
- Front/rear flip button: top-right corner (matches iOS Camera app convention)
- End Session button: bottom-left, smaller (less prominent, reduces accidental taps)
- Minimal chrome: only flip button and End Session visible during active session — nothing else overlaid until Phase 5 adds detection UI

### Phone Orientation
- Whole app locked to portrait only
- No per-screen orientation logic needed — single system-wide lock

### Session Start Flow
- Camera feed is live immediately on screen arrival (no extra tap to activate camera)
- Pre-session config sheet appears from the Home screen's "Start Session" button:
  - Sheet contains: skill picker (Phase 2 = Handstand only) + optional target hold time
  - Athlete taps Go → navigates to live session screen
- Mid-session config: gear icon overlaid on camera feed reopens same sheet
  - Changes apply immediately without ending the session
- Skill picker: Handstand only in Phase 2 — no placeholder slots for future skills
- Session `@Model` record created on session start (when athlete taps Go from the sheet)

### Permission UX
- Camera permission: system dialog only, triggered automatically when the camera activates on session screen arrival (no custom pre-prompt)
- Permission denied state: inline message within the camera area with an "Open Settings" deep-link button to app settings — no full-screen takeover

### Claude's Discretion
- Exact styling of overlaid controls (opacity, blur, button shape)
- AVCaptureSession configuration details
- Session model properties needed for Phase 2 (minimum viable — Phase 6 fills out the full schema)
- Camera preview aspect ratio handling (fill vs fit for portrait mode)

</decisions>

<specifics>
## Specific Ideas

- The session config sheet (skill + target hold time) is a shared component used in two places: Home screen pre-session, and mid-session via gear icon. Design it once, use it twice.
- The target hold time set in the config sheet should persist between sessions (remembered for next time).

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LiveSessionView` — existing shell with full-screen dark background and `.toolbar(.hidden)`. Phase 2 replaces the placeholder rectangle with a live `CameraPreviewView (UIViewRepresentable)`. Controls currently below the camera area — Phase 2 restructures to overlaid ZStack layout.
- `AppCoordinator.navigate(to: .liveSession)` — already wired; drawer tap navigates here. The pre-session sheet will intercept the flow before this navigation fires (or sheet triggers navigation).
- `AppCoordinator.popToRoot()` — wired to End Session button already. Keep this.
- `Session` @Model — empty scaffold at `Storage/Models/Session.swift`. Phase 2 adds minimum properties: `startedAt: Date`, `skill: String`, `targetDuration: TimeInterval?`.
- Brand system (`BrandColors`, `BrandFonts`) — use for control styling.

### Established Patterns
- `@Observable` + `@MainActor` for view models (established by AppCoordinator)
- `UIViewRepresentable` expected for camera preview (comment in LiveSessionView confirms this pattern)
- SwiftData `@Model` scaffolds in `Storage/Models/`

### Integration Points
- `HomeView` — "Start Session" CTA needs to trigger the pre-session config sheet instead of navigating directly
- `AppCoordinator.navigate(to: .liveSession)` — called after athlete confirms in the config sheet
- `CaliTimerApp.swift` — `NavigationStack` + `navigationDestination` cases; `LiveSessionView` is already registered

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-camera-setup-session-view*
*Context gathered: 2026-03-02*
