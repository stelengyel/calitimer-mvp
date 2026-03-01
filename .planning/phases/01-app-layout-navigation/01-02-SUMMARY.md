---
phase: 01-app-layout-navigation
plan: 02
subsystem: ui

tags: [swiftui, navigation, brand-colors, brand-fonts, appcoordinator]

# Dependency graph
requires:
  - phase: 01-app-layout-navigation/01-01
    provides: AppCoordinator, BrandColors, BrandFonts, XcodeGen project scaffold

provides:
  - HomeView: ember gradient hero screen with branded Start Session CTA and hamburger toolbar
  - LiveSessionView: full-screen shell with dark camera placeholder and End Session button
  - HistoryView: empty-state shell with clock icon and 'No sessions yet' message
  - UploadModeView: three-zone layout shell (import, player, results) ready for Phase 3/5 wiring
  - SettingsView: placeholder shell with gearshape icon and deferred-settings message

affects:
  - Phase 2 (camera integration — drops CameraPreviewView into LiveSessionView camera rect)
  - Phase 3 (upload shell — PHPicker wiring into UploadModeView Zone 1 and AVPlayer into Zone 2)
  - Phase 5 (detection results — populates UploadModeView Zone 3)
  - Phase 6 (history — replaces HistoryView empty state with @Query-driven list)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SwiftUI @Environment(AppCoordinator.self) for navigation — no NavigationStack inside view files"
    - "Color.textPrimary/textSecondary must be written explicitly — dot-shorthand does not resolve for custom Color extensions in SwiftUI ShapeStyle context (Swift 6 strict concurrency)"
    - ".toolbar(.hidden, for: .navigationBar) on full-screen views (not .navigationBarHidden)"
    - ".toolbarBackground + .toolbarColorScheme for dark nav bar on drawer-destination screens"
    - "All text uses .mono()/.monoBold() — no .font(.system()) on Text"
    - "Integration point comments (// Phase N: ...) mark exactly where future phases wire in"

key-files:
  created:
    - CaliTimer/UI/Home/HomeView.swift
    - CaliTimer/UI/LiveSession/LiveSessionView.swift
    - CaliTimer/UI/History/HistoryView.swift
    - CaliTimer/UI/Upload/UploadModeView.swift
    - CaliTimer/UI/Settings/SettingsView.swift
  modified:
    - CaliTimer.xcodeproj/project.pbxproj (xcodegen regenerated to include new files, x2)

key-decisions:
  - "Explicit Color.textPrimary syntax required — dot-shorthand (.textPrimary) fails in foregroundStyle() for custom Color extensions in Swift 6 strict concurrency mode; applied to all five views"
  - "HistoryView, UploadModeView, SettingsView do not hold @Environment(AppCoordinator) — their navigation is entirely handled by the drawer and system back button; avoids unnecessary environment coupling"
  - "UploadModeView Import Video button action is intentionally empty — Phase 3 adds PHPicker sheet presentation without layout change"

patterns-established:
  - "Shell view pattern: ZStack(brandBackground) + content — all five views follow this; future feature phases add to content without restructuring"
  - "Integration comment pattern: // Phase N: [what goes here] — marks every stub zone so future phases know exactly what to drop in"

requirements-completed: []

# Metrics
duration: 3min
completed: 2026-03-01
---

# Phase 01 Plan 02: Screen Shells Summary

**Five SwiftUI screen shells using brand system — ember gradient HomeView, full-screen LiveSessionView, and empty-state/placeholder HistoryView, UploadModeView (three zones), SettingsView; all compile in Swift 6 strict concurrency mode**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-01T19:55:28Z
- **Completed:** 2026-03-01T19:58:41Z
- **Tasks:** 2
- **Files modified:** 7 (5 Swift views + 2 pbxproj regenerations)

## Accomplishments

- All five SwiftUI screen shells built and compiling with zero errors
- HomeView delivers the ember gradient hero experience: midnight base + 15% gradient glow, "CaliTimer" title, branded gradient Start Session CTA, hamburger toolbar button wired to coordinator.isDrawerOpen
- LiveSessionView is full-screen with no nav chrome (.toolbar(.hidden)), dark camera placeholder rectangle labeled "Phase 2", and End Session button calling coordinator.popToRoot()
- HistoryView, UploadModeView, and SettingsView use correct dark toolbar background/color-scheme for consistent dark appearance across all navigation destinations
- UploadModeView three-zone layout (import action, 16:9 video player area, results area) is stable and ready for Phase 3 and Phase 5 to wire in without structural rework
- Discovered and documented that custom Color extensions require explicit `Color.textSecondary` syntax (not `.textSecondary` shorthand) in SwiftUI foregroundStyle calls under Swift 6

## Task Commits

Each task was committed atomically:

1. **Task 1: HomeView + LiveSessionView** - `10e0f89` (feat)
2. **Task 2: HistoryView + UploadModeView + SettingsView** - `f8198df` (feat)

## Files Created/Modified

- `CaliTimer/UI/Home/HomeView.swift` - Ember gradient hero screen with AppCoordinator navigation
- `CaliTimer/UI/LiveSession/LiveSessionView.swift` - Full-screen session shell, no nav chrome, camera placeholder
- `CaliTimer/UI/History/HistoryView.swift` - Empty state: clock icon + 'No sessions yet'
- `CaliTimer/UI/Upload/UploadModeView.swift` - Three-zone layout: import button, 16:9 player area, results area
- `CaliTimer/UI/Settings/SettingsView.swift` - Gear icon + placeholder message, no stub toggles
- `CaliTimer.xcodeproj/project.pbxproj` - Regenerated by xcodegen twice (once per task) to include new files

## Decisions Made

- **Explicit Color syntax required:** Dot-shorthand (`.textPrimary`, `.textSecondary`) does not resolve for custom `Color` extensions in `foregroundStyle()` under Swift 6 strict concurrency. All five views use `Color.textPrimary` and `Color.textSecondary` explicitly. This pattern must be followed by all future views.
- **No @Environment on non-navigating views:** HistoryView, UploadModeView, and SettingsView do not hold `@Environment(AppCoordinator.self)` since their navigation is fully managed by the drawer and system back button. Avoids unnecessary environment coupling.
- **Empty import button action:** UploadModeView's Import Video button has an empty action — Phase 3 adds PHPicker sheet presentation at exactly that point without any layout change needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Explicit Color.textXxx syntax required for custom Color extensions**
- **Found during:** Task 1 (HomeView + LiveSessionView build)
- **Issue:** Plan code samples used dot-shorthand `.textPrimary` and `.textSecondary` in `foregroundStyle()` calls. Swift 6 strict concurrency does not resolve custom `Color` static extensions via the shorthand dot syntax in `ShapeStyle` context — compiler error "type 'ShapeStyle' has no member 'textSecondary'"
- **Fix:** Replaced all `.textPrimary`/`.textSecondary` shorthand with `Color.textPrimary`/`Color.textSecondary` explicitly in both Task 1 and Task 2 views
- **Files modified:** HomeView.swift, LiveSessionView.swift, HistoryView.swift, UploadModeView.swift, SettingsView.swift
- **Verification:** `xcodebuild` BUILD SUCCEEDED with 0 errors after fix
- **Committed in:** 10e0f89 (Task 1 commit) and f8198df (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in plan code samples, dot-shorthand incompatible with Swift 6 strict concurrency)
**Impact on plan:** Essential correctness fix — code would not compile without it. No scope creep.

## Issues Encountered

- xcodegen regeneration required after each task to pick up new Swift files (project.yml uses directory glob; new files only included after regeneration). Build succeeded after each regeneration.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All five screen shells stable and ready for feature phases to wire into
- Phase 2 can drop `CameraPreviewView` into `LiveSessionView` at the marked camera placeholder ZStack
- Phase 3 can add PHPickerViewController to `UploadModeView` Zone 1 and AVPlayer to Zone 2
- Phase 5 can populate `UploadModeView` Zone 3 with detected holds without layout changes
- Phase 6 can replace `HistoryView` empty state with `@Query`-driven list without outer layout changes
- **Established pattern for all future views:** Use `Color.textPrimary` / `Color.textSecondary` explicitly — dot-shorthand does not work in Swift 6

---
*Phase: 01-app-layout-navigation*
*Completed: 2026-03-01*
