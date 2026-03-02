# Roadmap: CaliTimer

## Overview

CaliTimer ships in 9 phases ordered by dependency and risk. The first phase establishes navigation and screen shells so every subsequent phase has a real surface to build on. Phase 2 brings the live camera feed to life. Phase 3 adds the video upload shell (UI only). Phase 4 plugs in raw pose detection. Phase 5 is the center of gravity — the full handstand detection state machine, live timer, and video-import detection wired together. Phases 6–8 complete the product with session history, per-hold video recording, and real-world robustness. Phase 9 covers multi-skill expansion post-PMF validation.

## Phases

**Phase Numbering:**
- Integer phases (1–9): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (created via /gsd:insert-phase, execute between surrounding integers)

- [x] **Phase 1: App Layout & Navigation** - Screen shells, tab/nav structure, navigation plumbing — no features, just a real app skeleton that builds and runs
- [ ] **Phase 2: Camera Setup + Session View** - Live camera feed in app, session start/end controls, front/rear camera switch
- [ ] **Phase 3: Video Upload Shell** - PHPicker import, video playback UI scaffold (detection not wired yet)
- [ ] **Phase 4: Pose Detection** - Vision framework running on live and uploaded frames, skeleton overlay rendered and toggleable
- [ ] **Phase 5: Handstand Detection + Timer** - HoldStateMachine, live timer, detection indicator, haptic/visual alert, target duration, detection wired to imported video
- [ ] **Phase 6: Session History & Personal Bests** - SwiftData schema, session history log, personal best tracking
- [ ] **Phase 7: Video Capture** - Automatic per-hold recording, keep/discard review, camera roll save, upload mode clip output
- [ ] **Phase 8: Robustness + Polish** - Interruption recovery, orphan file cleanup, thermal throttling
- [ ] **Phase 9: Multi-Skill Expansion** - Front Lever, Back Lever, Planche, Human Flag (v2 / post-PMF)

## Phase Details

### Phase 1: App Layout & Navigation
**Goal**: A real app exists on the simulator — screens are navigable, the build succeeds, and every subsequent phase has a concrete surface to build features into
**Depends on**: Nothing (first phase)
**Requirements**: None (infrastructure phase — enables all subsequent phases)
**Success Criteria** (what must be TRUE):
  1. The app builds and launches on simulator with no errors or warnings
  2. All top-level screens exist as named shells (Session, History, Upload, Settings or equivalent structure derived from design)
  3. Navigation between all screens works — tapping a tab or back button reaches the correct destination every time
  4. Each screen shell renders its placeholder title/content so it is unambiguous which screen is active
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Xcode project scaffold: AppCoordinator, brand system (BrandColors, BrandFonts, JetBrains Mono), empty SwiftData @Model scaffolds
- [x] 01-02-PLAN.md — Five screen shells: HomeView (ember hero), LiveSessionView (full-screen), HistoryView, UploadModeView (three-zone), SettingsView
- [x] 01-03-PLAN.md — DrawerView + full navigation wiring + human verify on simulator

### Phase 2: Camera Setup + Session View
**Goal**: An athlete can open the app, start a session, see a live camera feed, switch between front and rear cameras, and end the session — the app is physically usable propped on a stand with no hands required
**Depends on**: Phase 1
**Requirements**: CAMR-01, CAMR-02, SESS-01, SESS-02
**Success Criteria** (what must be TRUE):
  1. Live camera feed renders on the session screen immediately after camera permission is granted
  2. User can tap to switch between front and rear camera mid-session without the feed freezing or crashing
  3. User can start a session (explicit start action) and end a session (explicit end action) from the session screen
  4. All session holds will later be grouped under the active session — the session model exists and is associated correctly (verifiable via SwiftData inspector or debug log)
  5. The session screen layout functions correctly when the phone is propped horizontally on a stand — no UI element requires the user to hold the phone
**Plans**: 3 plans

Plans:
- [ ] 02-01-PLAN.md — NSCameraUsageDescription + CameraActor + CameraManager (AVFoundation infrastructure)
- [ ] 02-02-PLAN.md — Session @Model properties + CameraPreviewView + LiveSessionView ZStack + SessionConfigSheet + HomeView sheet wiring
- [ ] 02-03-PLAN.md — Build + run on simulator + human verify camera/session flow

### Phase 3: Video Upload Shell
**Goal**: A user can open the upload screen, pick a video from their photo library, and see it play back inside the app — the detection pipeline is not wired yet but the UI scaffold is complete and ready for Phase 5 to plug into
**Depends on**: Phase 1
**Requirements**: VIDU-01
**Success Criteria** (what must be TRUE):
  1. User can tap an import action and the PHPicker sheet appears with video-only filtering
  2. After selecting a video, it loads into the in-app player and plays back correctly
  3. The upload screen has clearly designated space for detection output (holds list, skill label) even though that area is empty/placeholder at this stage — Phase 5 can wire into it without layout changes
**Plans**: TBD

### Phase 4: Pose Detection
**Goal**: Raw pose data flows from the Vision framework into the app on both live camera frames and imported video frames, and the skeleton overlay renders correctly on the camera feed — no hold classification or state machine yet, just verified pose data
**Depends on**: Phase 2, Phase 3
**Requirements**: DETE-05
**Success Criteria** (what must be TRUE):
  1. VNDetectHumanBodyPoseRequest runs on every live camera frame and joint coordinates are logged or visually confirmed (skeleton overlay renders)
  2. The skeleton overlay can be toggled on and off independently without affecting any other UI element
  3. VNDetectHumanBodyPoseRequest runs against frames from an imported video and produces joint coordinate output (confirmed via debug log or overlay on video thumbnail)
  4. No frame drops or UI freezes observed during sustained live pose estimation on device
**Plans**: TBD

### Phase 5: Handstand Detection + Timer
**Goal**: The app detects handstand holds automatically, counts up a live timer during each hold, alerts the athlete at their target duration, and produces the same hold-with-timestamp output from an imported video — this is the core product and must be validated thoroughly before proceeding
**Depends on**: Phase 4
**Requirements**: DETE-01, DETE-02, DETE-03, DETE-04, DETE-06, DETE-07, VIDU-02
**Success Criteria** (what must be TRUE):
  1. User starts a session, performs a handstand, and the app automatically detects and begins timing the hold with no button presses — the state machine transitions through searching → detected → timing
  2. The detection state indicator displays 3 distinct visual states (searching / detected / timing) and can be toggled on and off independently
  3. The live timer counts up on screen during an active hold and stops cleanly when the hold breaks; debounce prevents phantom hold terminations on brief pose loss
  4. A haptic and visual alert fires when the user-set target duration is reached; the user can change the target duration on-the-fly during a session without stopping
  5. When a video is imported in upload mode, the detection pipeline runs against it and produces a list of detected holds with timestamps — output is visible in the upload screen's designated result area
**Plans**: TBD

### Phase 6: Session History & Personal Bests
**Goal**: Every hold the athlete has ever recorded is queryable from history, grouped by session, and the personal best for each skill is always current and displayed correctly
**Depends on**: Phase 5
**Requirements**: HIST-01, HIST-02
**Success Criteria** (what must be TRUE):
  1. After completing a session, the history screen shows all holds from that session with skill name, duration, date, and camera used — correctly grouped under their session
  2. Personal best per skill is tracked automatically and updates immediately when a new best is achieved in a session
  3. Multiple sessions appear in history in reverse-chronological order and are correctly separated — holds from different sessions are never mixed
**Plans**: TBD

### Phase 7: Video Capture
**Goal**: Every hold attempt is automatically captured on video; athletes review each clip immediately after the hold ends; kept clips reach the camera roll and discarded clips disappear instantly; the upload mode produces the same keep/discard review experience from an imported video
**Depends on**: Phase 5
**Requirements**: VIDL-01, VIDL-02, VIDL-03, VIDU-03
**Success Criteria** (what must be TRUE):
  1. A video clip starts recording automatically when a hold is detected and stops when the hold ends — no user action required; a 1–2s clip-start delay is acceptable
  2. After a hold ends, the keep/discard review UI appears immediately with a playable preview of the clip
  3. Tapping Keep saves the clip to the camera roll and tapping Discard deletes it from temp storage — no orphaned temp files remain after either choice
  4. When a video is imported in upload mode, the result includes a trimmed clip per detected hold with keep/discard review matching live mode output
**Plans**: TBD

### Phase 8: Robustness + Polish
**Goal**: The app behaves correctly under real-world conditions — phone calls during a hold, app backgrounding mid-clip, elevated device temperature — and never leaves corrupt data or orphaned files regardless of how training is interrupted
**Depends on**: Phase 7
**Requirements**: ROBU-01, ROBU-02, ROBU-03
**Success Criteria** (what must be TRUE):
  1. Simulating a phone call during an active hold ends the session and any in-progress recording cleanly — no corrupt video files, no crash on return, and the hold that was in progress is not silently lost
  2. On app launch after an interrupted session (force-quit during recording), temporary video files from that session are swept and removed automatically before the user reaches the session screen
  3. When device thermal state is elevated (verified via Instruments or device heating), frame processing rate drops visibly and the app remains responsive — sustained use does not cause the app to be killed by iOS thermal pressure
**Plans**: TBD

### Phase 9: Multi-Skill Expansion
**Goal**: Athletes can detect and time Front Lever, Back Lever, Planche, and Human Flag holds using the same detection pipeline established in Phase 5, with progress analytics — gated on Phase 5 detection accuracy validated with real user data
**Depends on**: Phase 8 (and external: Phase 5 handstand detection accuracy validated with real-world user feedback)
**Requirements**: SKIL-01, SKIL-02, SKIL-03, SKIL-04, SKIL-05, ANLT-01
**Note**: v2 milestone — do not begin until Phase 5 handstand detection accuracy is validated with real-world user feedback
**Success Criteria** (what must be TRUE):
  1. User can select a target skill (Handstand, Front Lever, Back Lever, Planche, Human Flag) before or during a session and the correct classifier activates
  2. Each supported skill is detected and timed with accuracy comparable to handstand detection validated in Phase 5 — no skill regresses handstand detection
  3. Session history and personal bests correctly record skill name per hold across all supported skills
  4. Progress charts show hold duration trend over time per skill — athlete can see improvement across sessions
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Layout & Navigation | 3/3 | Complete | 2026-03-01 |
| 2. Camera Setup + Session View | 1/3 | In Progress|  |
| 3. Video Upload Shell | 0/TBD | Not started | - |
| 4. Pose Detection | 0/TBD | Not started | - |
| 5. Handstand Detection + Timer | 0/TBD | Not started | - |
| 6. Session History & Personal Bests | 0/TBD | Not started | - |
| 7. Video Capture | 0/TBD | Not started | - |
| 8. Robustness + Polish | 0/TBD | Not started | - |
| 9. Multi-Skill Expansion (v2) | 0/TBD | Not started | - |
