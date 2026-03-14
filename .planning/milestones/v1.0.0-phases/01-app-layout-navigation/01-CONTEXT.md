# Phase 1: App Layout & Navigation - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

A real app skeleton that builds, launches on simulator, and has navigable screen shells. No features are implemented — this phase delivers structure only. Every subsequent phase has a concrete, branded surface to build features into.

</domain>

<decisions>
## Implementation Decisions

### Top-level navigation structure
- Home screen is the root/anchor of the app — not a tab bar, not the session screen directly
- Slide-out drawer (hamburger menu) for secondary screens: History, Upload, Settings
- Drawer items: History / Upload / Settings (3 items)
- "Start Session" button on the Home screen launches the session view as a full-screen push with no tab bar or navigation chrome visible — maximizes screen real estate for Phase 2 camera feed
- Session screen has a back/end button to return to Home

### Session screen shell
- Dark placeholder rectangle where the camera preview will live in Phase 2 (signals the layout intent)
- Placeholder Start/End session controls in the appropriate position
- Phase 2 drops the live camera feed directly into the existing rectangle with no layout rework

### Upload screen layout
- Three-zone layout: (1) import action, (2) video player area, (3) results area
- Empty state: prominent "Import Video" button as the primary call to action
- Video player area present but empty until Phase 3 wires it
- Results area shows "Results will appear here" placeholder — Phase 5 populates it with hold list and timestamps without changing the layout

### History screen shell
- Empty state with an icon and "No sessions yet" message
- Communicates purpose without fake data
- Phase 6 wires real session data into this existing layout

### Settings screen shell
- Empty shell with screen title and an empty list (or "Settings coming soon" placeholder)
- No non-functional stub toggles — settings are added when their features land

### Drawer navigation model
- History and Upload open via NavigationStack push from the Home context (Claude's discretion — idiomatic iOS, allows nested navigation in each section later)

### Claude's Discretion
- Exact drawer animation style and overlay treatment
- Whether the session screen's back/end button is "End Session" text or a chevron
- Precise empty-state icon choices for History and Upload

</decisions>

<specifics>
## Specific Ideas

### Brand identity applied from day one
- Background: #0C0906 (midnight) as the app background
- Ember accent (#FF6B2B): primary action elements only — Start Session button, active drawer item, accent icons
- Text: #FAF3EC (text-primary) and #B8A090 (text-secondary) from the style guide
- **JetBrains Mono as the primary font everywhere** (user preference — uniform mono aesthetic throughout the app)
- Home screen: large ember gradient hero behind the Start Session button — full background treatment with gradient/glow effect, similar to the style guide landing page feel. App name ("CaliTimer") over the hero.
- Style guide brand gradient: `linear-gradient(135deg, #FF6B2B 0%, #FFAA3B 50%, #FFD166 100%)`

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing Swift code

### Established Patterns
- SwiftUI root with @Observable (iOS 17+) — confirmed by ARCHITECTURE.md and STACK.md
- UIViewRepresentable for AVCaptureVideoPreviewLayer — camera preview is a leaf view inside the session ZStack (relevant for Phase 2 integration point)
- SwiftData configured at app root via ModelContainer — storage layer scaffold can be set up in Phase 1 even if empty

### Integration Points
- Session screen dark rectangle → Phase 2 drops CameraPreviewView (UIViewRepresentable) directly into it
- Upload screen video player area → Phase 3 adds AVPlayer-based playback
- Upload screen results area → Phase 5 populates with HoldStateMachine output (list of holds + timestamps)
- History screen empty-state layout → Phase 6 replaces with @Query-driven SwiftData list
- AppCoordinator (root navigation state) → referenced in ARCHITECTURE.md as `App/AppCoordinator.swift`

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-app-layout-navigation*
*Context gathered: 2026-03-01*
