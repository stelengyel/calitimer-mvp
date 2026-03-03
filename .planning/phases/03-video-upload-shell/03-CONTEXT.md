# Phase 3: Video Upload Shell - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the video import and playback UI on the Upload screen — PHPicker integration, in-app video player, and placeholder zones for Phase 5 detection output. The detection pipeline is NOT wired in this phase. Phase 5 plugs into the scaffold built here.

Requirements covered: VIDU-01 (User can import an existing video from camera roll)

</domain>

<decisions>
## Implementation Decisions

### Video player controls
- Full controls: play/pause button + seek scrubber + time display (elapsed / total)
- Player adapts its height to match the video's natural aspect ratio (portrait videos show portrait, landscape shows landscape) — no fixed 16:9 constraint, no cropping
- Autoplay immediately when video finishes loading
- Stops at end (no loop) — training clips can be long; looping would be annoying

### Detection trigger
- No "Analyze" button — detection fires automatically when a video is imported
- The only reason to import a video is to run detection; explicit trigger adds unnecessary friction
- Phase 5 hooks into the import completion callback to start the detection pipeline

### Zone 1 state machine (import action area)
- Before import: "Import Video" button (current shell)
- After import: button label changes to "Import different video" — allows swapping clip without hunting for a control
- Zone 1 stays visible throughout both states

### Zone 3 state machine (results area)
- Before any video imported: empty state with label "Import a video to see detected holds"
- After video imported (shell phase, detection not wired): show "Analyzing…" activity spinner + label
- Phase 5 replaces the spinner with real progress + results list

### Import loading: iCloud assets
- If selected video is not locally available (iCloud sync), show a progress bar in Zone 2 while it downloads
- Progress bar should be labeled (e.g., "Downloading from iCloud…") with a percentage or byte count if available via PHPickerViewController progress API
- Zone 2 player appears only after download completes

### Import error handling
- If import fails (network error, iCloud timeout, unsupported format): show inline error in Zone 2
- Error state: brief message ("Could not load video") + "Try again" button that re-opens PHPicker
- No modal/alert — stays in context, user can retry immediately
- Zone 3 returns to empty state on failure

### Long video warning
- Soft warning for videos over 30 minutes (typical training session is 20–30 min; longer likely includes non-training footage)
- Warning is non-blocking — user can proceed anyway
- No hard limit in Phase 3; Phase 5 will determine if detection needs duration constraints

### Claude's Discretion
- Exact seek scrubber style (native-feel vs custom)
- Progress bar visual design (color, position within Zone 2)
- Warning presentation style (inline banner vs subtle alert within Zone 1)
- AVPlayer buffering indicator (spinner overlaid on player while buffering after load)

</decisions>

<specifics>
## Specific Ideas

- Zero-friction ethos: detection auto-starts, no buttons for things that always happen
- Upload mode is a secondary workflow (most use is live); the UI should feel complete but not over-designed

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UploadModeView` (`CaliTimer/UI/Upload/UploadModeView.swift`): already has exact 3-zone ZStack structure with commented Phase 3/5 integration points — replace placeholders, don't restructure
- `Color.brandEmber`, `Color.brandBackground`, `Color.textPrimary`, `Color.textSecondary`: brand color system via `BrandColors.swift`
- `.font(.mono(x))` / `.font(.monoBold(x))`: font pattern via `BrandFonts.swift`
- `CameraManager` (@MainActor + private serial DispatchQueue): established pattern for AV-heavy managers — replicate for `VideoImportManager` or similar

### Established Patterns
- `@MainActor` + `@State private var manager = Manager()` in SwiftUI views — use this for any video import state manager
- No external dependencies — PHPickerViewController and AVPlayer are the correct first-party tools
- `.sheet(isPresented:)` pattern used in `LiveSessionView` for `SessionConfigSheet` — same pattern for PHPicker sheet presentation

### Integration Points
- `UploadModeView` is reached via `DrawerView` → `AppCoordinator` — no navigation changes needed
- Zone 3 results area must remain structurally stable — Phase 5 populates it with detected holds list; don't hardcode its empty/spinner content in a way that blocks replacement

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-video-upload-shell*
*Context gathered: 2026-03-03*
