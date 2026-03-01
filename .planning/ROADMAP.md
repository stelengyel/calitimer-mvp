# Roadmap: CaliTimer

## Overview

CaliTimer ships in three v1 phases ordered by dependency and risk. Phase 1 validates the highest-risk unknown — handstand detection accuracy — and delivers a fully working timer app with session history. It also includes a minimal video upload tool (no polished UX) so developers can feed real handstand footage into the PoseDetector and HoldStateMachine without physically performing handstands on every iteration. Phase 2 adds per-hold video recording and completes the video upload pipeline with full review UX, both of which share the Phase 1 detection engine. Phase 3 hardens the complete pipeline for real-world conditions: thermal throttling, interruption recovery, and edge case cleanup. A fourth phase covers multi-skill expansion post-PMF validation.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation + Core Detection** - Working handstand timer with session history, plus minimal video import tool for developer testing of detection pipeline
- [ ] **Phase 2: Video Capture + Upload Mode** - Per-hold automatic recording with keep/discard review and full video import UX
- [ ] **Phase 3: Robustness + Polish** - Interruption recovery, thermal throttling, and production hardening
- [ ] **Phase 4: Multi-Skill Expansion** - Front Lever, Back Lever, Planche, Human Flag (v2 / post-PMF)

## Phase Details

### Phase 1: Foundation + Core Detection
**Goal**: Athletes can run a training session, have their handstand holds automatically detected and timed, and review session history with personal bests — all with no manual input during training; developers can also import a video to test the detection pipeline against real footage without a live camera session
**Depends on**: Nothing (first phase)
**Requirements**: DETE-01, DETE-02, DETE-03, DETE-04, DETE-05, DETE-06, DETE-07, CAMR-01, CAMR-02, SESS-01, SESS-02, HIST-01, HIST-02, VIDU-01, VIDU-02
**Success Criteria** (what must be TRUE):
  1. User starts a session, points the camera at a handstand, and the app automatically detects and times the hold with no button presses
  2. The detection state indicator transitions visibly through searching / detected / timing states and correctly resets after the hold ends
  3. The live timer counts up on screen during an active hold and stops cleanly when the hold breaks; a haptic alert fires when the user-set target duration is reached
  4. The skeleton overlay renders on the camera feed and can be toggled on and off independently of the detection state indicator
  5. Session history shows all holds from the session (skill, duration, date, camera) and the personal best per skill is tracked and updated correctly
  6. A video can be imported from the camera roll and the detection pipeline runs against it, producing a console or debug view showing detected holds and timestamps — no clip review UX required at this stage
**Plans**: 6 plans

Plans:
- [ ] 01-01-PLAN.md — Project scaffolding, CameraActor global actor, CameraManager, CameraPreviewView, session screen shell
- [ ] 01-02-PLAN.md — PoseDetector, HandstandClassifier, HoldStateMachine (TDD — tested detection core)
- [ ] 01-03-PLAN.md — SessionCoordinator, live timer (10Hz ContinuousClock), haptic/beep alert, HomeView, navigation
- [ ] 01-04-PLAN.md — SkeletonRenderer (Canvas), DetectionStateOverlay (colored ring), independent toggles
- [ ] 01-05-PLAN.md — SwiftData schema (Session, Hold, SkillPersonalBest), history log view, PB card on home
- [ ] 01-06-PLAN.md — VideoFrameReader (AVAssetReader), PHPicker video import, debug hold list output

### Phase 2: Video Capture + Upload Mode
**Goal**: Every hold attempt is automatically captured on video; athletes review each clip immediately after the hold ends and choose to keep or discard it; athletes can also import existing footage and receive the full review experience — trimmed clips per hold with keep/discard review — matching live mode output
**Depends on**: Phase 1
**Requirements**: VIDL-01, VIDL-02, VIDL-03, VIDU-03
**Success Criteria** (what must be TRUE):
  1. A video clip starts recording automatically when a hold is detected and stops when the hold ends, with no user action required
  2. After a hold ends the keep/discard review appears immediately; kept clips are saved to the camera roll and discarded clips are deleted from temp storage with no leftover files
  3. User can import a video from the camera roll and receive full live-mode output: detected skill, hold durations, trimmed clip per hold, keep/discard review
**Plans**: TBD

Plans:
- [ ] 02-01: Recorder actor (circular pre-roll buffer + AVAssetWriter, eager init)
- [ ] 02-02: ClipReviewView, keep/discard logic, PHPhotoLibrary save, temp cleanup
- [ ] 02-03: VideoUploadCoordinator, clip trimming, full review UX wired to Phase 1 detection output

### Phase 3: Robustness + Polish
**Goal**: The app behaves correctly under real-world conditions — phone calls during a hold, app backgrounding mid-clip, elevated device temperature — and never leaves the user with corrupt data or orphaned files
**Depends on**: Phase 2
**Requirements**: ROBU-01, ROBU-02, ROBU-03
**Success Criteria** (what must be TRUE):
  1. A phone call or app backgrounding during an active hold ends the session and recording cleanly — no corrupt video files and no crash on return
  2. On app launch after an interrupted session, temporary video files from that session are swept and removed automatically
  3. When device thermal state is elevated, frame processing rate drops and the app remains responsive; battery drain under sustained use is acceptable (validated with Instruments Energy gauge)
**Plans**: TBD

Plans:
- [ ] 03-01: Interruption handling (AVCaptureSessionWasInterrupted, AVAssetWriter.finishWriting, session termination)
- [ ] 03-02: Orphan file sweep on launch, temp directory cleanup audit
- [ ] 03-03: Thermal throttling (ProcessInfo.thermalState observer, dynamic FPS reduction), Instruments profiling

### Phase 4: Multi-Skill Expansion
**Goal**: Athletes can detect and time Front Lever, Back Lever, Planche, and Human Flag holds using the same pipeline architecture established in Phase 1 (post-PMF, gated on Phase 1 detection quality validation)
**Depends on**: Phase 3 (and external: Phase 1 accuracy validated with real user data)
**Requirements**: SKIL-01, SKIL-02, SKIL-03, SKIL-04, SKIL-05
**Note**: v2 milestone — do not begin until Phase 1 handstand detection accuracy is validated with real-world user feedback
**Success Criteria** (what must be TRUE):
  1. User can select a skill (Handstand, Front Lever, Back Lever, Planche, Human Flag) before a session and the correct classifier activates
  2. Each supported skill is detected and timed with accuracy comparable to handstand detection validated in Phase 1
  3. Session history and personal bests correctly record skill name per hold across all supported skills
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Core Detection | 0/6 | Not started | - |
| 2. Video Capture + Upload Mode | 0/3 | Not started | - |
| 3. Robustness + Polish | 0/3 | Not started | - |
| 4. Multi-Skill Expansion (v2) | 0/TBD | Not started | - |
