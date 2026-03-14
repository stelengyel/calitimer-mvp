---
phase: 05-handstand-detection-timer
plan: 03
subsystem: ui
tags: [avfoundation, avassetreader, vision, swiftui, cmmediabuffer, uploadmode]

# Dependency graph
requires:
  - phase: 05-01
    provides: HoldStateMachine with resetForNewScan(), completedHolds, currentVideoTime
  - phase: 05-02
    provides: HoldIndicatorView, HoldTimerView UI components; DetectionIndicatorPreference
  - phase: 04-pose-detection
    provides: VisionProcessor.process(sampleBuffer:orientation:) nonisolated API
  - phase: 03-video-upload-shell
    provides: VideoImportManager, AVPlayerItemVideoOutput frame path, Zone 3 ZStack contract
provides:
  - AVAssetReaderScanner.scan() — full-speed CMSampleBuffer loop for upload mode video scanning
  - VideoImportManager.startScan(holdStateMachine:) — triggers scan, detaches AVPlayerItemVideoOutput
  - VideoImportManager.cancelScan() — cooperative Task cancellation
  - VideoImportManager.isScanning @Published — scan progress state for UploadModeView
  - UploadModeView Zone 3 — scrollable holds results list with [n]. start - end - duration format
  - UploadModeView scan overlay — HoldIndicatorView + HoldTimerView during active scan
  - VIDU-02 deliverable: import video -> automatic scan -> timestamped holds list
affects:
  - 05-04 (human verification/testing harness that depends on this scan output)
  - 06-session-persistence (holds recorded in upload mode will need saving)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AVAssetReader for full-speed video scanning (decoder speed, not realtime)
    - nonisolated scan function bridges to MainActor only for state machine calls
    - Detach/reattach AVPlayerItemVideoOutput pattern during scan to avoid VNSequenceRequestHandler contention
    - Cooperative Task cancellation with Task.isCancelled in read loop
    - onChange(of: videoURL) as automatic scan trigger — no user tap required

key-files:
  created:
    - CaliTimer/Upload/AVAssetReaderScanner.swift
  modified:
    - CaliTimer/Upload/VideoImportManager.swift
    - CaliTimer/UI/Upload/UploadModeView.swift

key-decisions:
  - "AVAssetReader scan detaches AVPlayerItemVideoOutput observer to prevent VNSequenceRequestHandler contention — dual processing would cause frame conflicts"
  - "HoldStateMachine passed as parameter to startScan() from UploadModeView — not stored on VideoImportManager to keep dependency direction correct (UI -> model)"
  - "onChange(of: manager.videoURL) triggers scan automatically on import — no user tap required per CONTEXT.md"
  - "Zone 3 empty state ('No handstand holds detected') only appears post-scan, not pre-import — conditioned on manager.videoURL != nil"

patterns-established:
  - "Full-speed scan pattern: nonisolated scan function + MainActor bridge only for state machine calls"
  - "Zone 3 is inner content replacement only — outer ZStack unchanged (Phase 3 stability contract)"

requirements-completed: [VIDU-02, DETE-01, DETE-02, DETE-03, DETE-04]

# Metrics
duration: 8min
completed: 2026-03-07
---

# Phase 5 Plan 03: AVAssetReader Scan + Upload Mode Zone 3 Summary

**Full-speed AVAssetReader scan pipeline replacing realtime frame path for upload mode, with HoldIndicatorView/HoldTimerView overlay during scan and scrollable timestamped holds results in Zone 3**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-07T14:13:08Z
- **Completed:** 2026-03-07T14:21:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Created AVAssetReaderScanner with nonisolated static scan() that reads all video frames at decoder speed (5-30x realtime), driving HoldStateMachine via MainActor bridges
- Modified VideoImportManager with isScanning @Published, startScan(holdStateMachine:) that detaches AVPlayerItemVideoOutput to avoid contention, and cancelScan() for cooperative task cleanup
- Wired UploadModeView with automatic scan trigger on import, scan progress overlay (indicator dot + timer), and Zone 3 holds results list with [n]. start - end - duration format

## Task Commits

Each task was committed atomically:

1. **Task 1: AVAssetReaderScanner + VideoImportManager scan hook** - `396507b` (feat)
2. **Task 2: Wire UploadModeView scan trigger + overlay + Zone 3 results** - `4b99fae` (feat)

## Files Created/Modified

- `/Users/stelengyel/Desktop/calitimer-mvp/CaliTimer/Upload/AVAssetReaderScanner.swift` - New: nonisolated enum with static scan() reading CMSampleBuffer loop via AVAssetReader
- `/Users/stelengyel/Desktop/calitimer-mvp/CaliTimer/Upload/VideoImportManager.swift` - Modified: isScanning @Published, scanTask, startScan(holdStateMachine:), cancelScan()
- `/Users/stelengyel/Desktop/calitimer-mvp/CaliTimer/UI/Upload/UploadModeView.swift` - Modified: HoldStateMachine + DetectionIndicatorPreference @StateObject, scan overlay, Zone 3 results

## Decisions Made

- AVAssetReader scan detaches AVPlayerItemVideoOutput observer before scanning and reattaches after — VNSequenceRequestHandler is not re-entrant; running both simultaneously would cause contention
- HoldStateMachine passed as parameter to startScan() from UploadModeView — keeping dependency direction correct (UI -> model, not model -> model)
- Zone 3 holdsResultsView only renders empty state when manager.videoURL != nil — prevents "No handstand holds detected" from showing on first launch before any import

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — build succeeded on first attempt for both tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- VIDU-02 fully delivered: import video → automatic scan → timestamped holds list in Zone 3
- Upload mode now functions as primary classifier debug/validation harness per CONTEXT.md
- Plan 04 can proceed with human verification of detection accuracy against real handstand footage
- AVAssetReaderScanner accepts cooperative cancellation — safe for plan 04 to test edge cases (cancel mid-scan, short videos, no handstands)

---
*Phase: 05-handstand-detection-timer*
*Completed: 2026-03-07*
