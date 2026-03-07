---
phase: 03-video-upload-shell
plan: 02
subsystem: ui
tags: [swift6, phppicker, avplayer, avfoundation, swiftui, uploadmodeview]

# Dependency graph
requires:
  - phase: 03-video-upload-shell
    plan: 01
    provides: "VideoImportManager, PHPickerSheet, VideoPlayerView — all three components consumed by UploadModeView"

provides:
  - "Fully wired UploadModeView: 3-zone layout with PHPicker import, AVPlayer playback, iCloud download progress, inline error state, long-video warning, and Analyzing spinner"
  - "NSPhotoLibraryUsageDescription in project.yml — enables Photos permission prompt on first use"
  - "Stable Zone 3 structure for Phase 5 detection wiring (outer ZStack layout contract locked)"

affects:
  - 05-handstand-detection-timer

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AVPlayer owned by UploadModeView (not VideoPlayerView) — enables Phase 5 external playback control"
    - "onChange(of: manager.videoURL) drives player creation and duration check with Task.sleep deferral before asset.load(.duration)"
    - "Zone 3 outer ZStack structure is a Phase 5 stability contract — inner content will be replaced, outer layout must not change"

key-files:
  created: []
  modified:
    - CaliTimer/UI/Upload/UploadModeView.swift
    - project.yml
    - CaliTimer.xcodeproj/project.pbxproj
    - CaliTimer/Info.plist

key-decisions:
  - "AVPlayer owned by parent UploadModeView via @State — VideoPlayerView consumes it, Phase 5 can control playback externally"
  - "Long video warning (>30 min) uses Task.sleep(0.5s) before asset.load(.duration) to wait for AVPlayerItem readiness"
  - "Zone 3 outer ZStack padding/background/frame must NOT change — Phase 5 stability contract"

patterns-established:
  - "3-zone state machine: Zone 1 always visible (button label toggles), Zone 2 switches on isDownloading/importError/player state, Zone 3 switches on hasVideo"
  - "Non-blocking dismissible warning banner: local @State var showLongVideoWarning drives visibility, xmark button dismisses"

requirements-completed: [VIDU-01]

# Metrics
duration: ~18min (checkpoint overhead)
completed: 2026-03-03
---

# Phase 3 Plan 2: Wire UploadModeView + Human Verify Import and Playback Flow Summary

**Full 3-zone UploadModeView wired with PHPickerSheet, AVPlayer playback, iCloud progress, inline error state, long-video warning banner, and Phase 5-stable Zone 3 placeholder — human verified on simulator**

## Performance

- **Duration:** ~18 min (includes checkpoint wait for human verification)
- **Started:** 2026-03-03T18:52:10Z
- **Completed:** 2026-03-03T19:10:51Z
- **Tasks:** 2 (Task 1: auto, Task 2: checkpoint:human-verify)
- **Files modified:** 4

## Accomplishments

- UploadModeView wired with all three zones and full state machine (import action, player, results placeholder)
- PHPicker sheet presents video-only filter; label changes from "Import Video" to "Import different video" after load
- Zone 2 handles four states: empty placeholder, iCloud download progress bar, AVPlayer (VideoPlayerView), inline error with "Try again"
- Zone 3 shows "Import a video to see detected holds" before import; "Analyzing…" spinner after import — structurally stable for Phase 5
- Long video warning banner (>30 min, non-blocking, dismissible) implemented in Zone 1
- NSPhotoLibraryUsageDescription added to project.yml and Info.plist
- Human verification approved — PHPicker opens, video autoplays in Zone 2, Zone 1 label changes, Zone 3 shows spinner

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire UploadModeView + add NSPhotoLibraryUsageDescription** - `e0b9fa2` (feat)
2. **Task 2: Human verify import and playback flow** - approved via checkpoint (no code commit needed)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `CaliTimer/UI/Upload/UploadModeView.swift` - Fully wired 3-zone upload screen: Zone 1 (PHPicker button + long-video warning), Zone 2 (iCloud progress / AVPlayer / error / empty), Zone 3 (Analyzing spinner / empty state — Phase 5 wiring point)
- `project.yml` - Added NSPhotoLibraryUsageDescription for PHPicker Photos access
- `CaliTimer.xcodeproj/project.pbxproj` - XcodeGen regenerated to include updated Info.plist
- `CaliTimer/Info.plist` - NSPhotoLibraryUsageDescription key added

## Decisions Made

- `AVPlayer` created in `onChange(of: manager.videoURL)` and stored as `@State var player: AVPlayer?` — VideoPlayerView consumes it, Phase 5 can control playback externally without going through VideoPlayerView
- Long video duration check uses `Task.sleep(for: .seconds(0.5))` before `item.asset.load(.duration)` to allow AVPlayerItem to become ready before reading asset properties
- Zone 3 outer ZStack structure (background, stroke, padding, `frame(maxHeight: .infinity)`) is locked as a Phase 5 stability contract — Phase 5 replaces only the inner content

## Deviations from Plan

None - plan executed exactly as written. The implementation structure provided in the plan compiled cleanly under Swift 6 with no errors or warnings.

## Issues Encountered

None — UploadModeView compiled on first attempt with no Swift 6 concurrency issues. Build succeeded, human verification approved.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VIDU-01 fully satisfied: user can import a video from camera roll and watch it play back in-app
- Zone 3 is structurally stable — Phase 5 (Handstand Detection + Timer) plugs detection results list into the ZStack inner content without layout changes
- VideoImportManager.videoURL is the signal Phase 5 observes to begin detection on the imported video
- AVPlayer ownership is in UploadModeView — Phase 5 can seek/pause/play externally for frame-accurate analysis

## Self-Check

- FOUND: CaliTimer/UI/Upload/UploadModeView.swift
- FOUND: project.yml (NSPhotoLibraryUsageDescription)
- FOUND: e0b9fa2 (Task 1 commit)
- FOUND: .planning/phases/03-video-upload-shell/03-02-SUMMARY.md

## Self-Check: PASSED

---
*Phase: 03-video-upload-shell*
*Completed: 2026-03-03*
