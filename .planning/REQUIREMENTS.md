# Requirements: CaliTimer

**Defined:** 2026-03-01
**Core Value:** Automatic hold timing with zero manual input — the app knows when the hold starts and when it breaks, so athletes can focus entirely on the skill.

## v1 Requirements

### Detection & Timing

- [ ] **DETE-01**: App automatically detects handstand hold via geometric pose classifier (feet above head in normalized coords) — no manual start/stop required
- [ ] **DETE-02**: Hold state machine transitions through searching → detected → timing → hold ended with debounce (10–15 frame threshold to prevent phantom holds)
- [ ] **DETE-03**: Detection state indicator shown on screen with 3 distinct visual states (searching / detected / timing), independently toggleable
- [ ] **DETE-04**: Timer counts up during active hold, visible on screen in real-time
- [ ] **DETE-05**: Skeleton overlay rendered on camera feed, independently toggleable
- [ ] **DETE-06**: Visual and haptic alert fires when user-set target hold duration is reached
- [ ] **DETE-07**: User can set target hold duration on-the-fly during a session (no pre-session config required)

### Camera

- [x] **CAMR-01**: App works with front and rear camera (user selects during session)
- [x] **CAMR-02**: App functions with phone propped on a stand without user holding it

### Session

- [x] **SESS-01**: User can start and end an explicit training session
- [x] **SESS-02**: All holds detected during a session are grouped under that session

### Video — Live Mode

- [ ] **VIDL-01**: Each hold attempt is recorded automatically starting at hold detection (1–2s clip-start delay accepted — no pre-roll buffer)
- [ ] **VIDL-02**: User reviews each clip immediately after hold ends with keep/discard choice
- [ ] **VIDL-03**: Kept clips are saved to camera roll; discarded clips are deleted from temp storage immediately

### Video — Upload Mode

- [x] **VIDU-01**: User can import an existing video from camera roll
- [ ] **VIDU-02**: Detection pipeline runs against imported video and identifies holds with timestamps
- [ ] **VIDU-03**: Output matches live mode: detected skill, hold durations, trimmed clip per hold, keep/discard review

### History & Tracking

- [ ] **HIST-01**: Session history log shows all holds (skill, duration, date, camera) grouped by session
- [ ] **HIST-02**: Personal best per skill tracked locally

### Robustness

- [ ] **ROBU-01**: App recovers gracefully from interruptions (phone calls, backgrounding) — session and recording state preserved or cleanly terminated, never corrupt
- [ ] **ROBU-02**: Temporary video files from interrupted sessions are cleaned up on next app launch
- [ ] **ROBU-03**: Pose estimation frame processing is throttled when thermal state is elevated to prevent excessive battery drain

## v2 Requirements

### Multi-Skill Detection

- **SKIL-01**: App detects and times Front Lever holds
- **SKIL-02**: App detects and times Back Lever holds
- **SKIL-03**: App detects and times Planche holds
- **SKIL-04**: App detects and times Human Flag holds
- **SKIL-05**: App detects progressions and variations of supported skills

### History & Analytics

- **ANLT-01**: Progress charts showing hold duration trends over time per skill

## Out of Scope

| Feature | Reason |
|---------|--------|
| Pre-roll circular video buffer | Accepted 1-2s clip-start delay for v1; VideoToolbox encoding complexity not justified |
| Dynamic movement detection (reps, pull-ups) | Static skills only for v1; fundamentally different CV pipeline |
| Apple Watch companion | Defer post-launch |
| iCloud / cross-device sync | Offline-first; no cloud for MVP |
| Social / sharing features | Out of scope |
| Apple Health integration | Out of scope |
| Coaching / guided programs | Out of scope |
| Monetization | Free MVP — validate first |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CAMR-01 | Phase 2 | Complete |
| CAMR-02 | Phase 2 | Complete |
| SESS-01 | Phase 2 | Complete |
| SESS-02 | Phase 2 | Complete |
| VIDU-01 | Phase 3 | Complete |
| DETE-05 | Phase 4 | Pending |
| DETE-01 | Phase 5 | Pending |
| DETE-02 | Phase 5 | Pending |
| DETE-03 | Phase 5 | Pending |
| DETE-04 | Phase 5 | Pending |
| DETE-06 | Phase 5 | Pending |
| DETE-07 | Phase 5 | Pending |
| VIDU-02 | Phase 5 | Pending |
| HIST-01 | Phase 6 | Pending |
| HIST-02 | Phase 6 | Pending |
| VIDL-01 | Phase 7 | Pending |
| VIDL-02 | Phase 7 | Pending |
| VIDL-03 | Phase 7 | Pending |
| VIDU-03 | Phase 7 | Pending |
| ROBU-01 | Phase 8 | Pending |
| ROBU-02 | Phase 8 | Pending |
| ROBU-03 | Phase 8 | Pending |
| SKIL-01 | Phase 9 (v2) | Pending |
| SKIL-02 | Phase 9 (v2) | Pending |
| SKIL-03 | Phase 9 (v2) | Pending |
| SKIL-04 | Phase 9 (v2) | Pending |
| SKIL-05 | Phase 9 (v2) | Pending |
| ANLT-01 | Phase 9 (v2) | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓
- v2 requirements: 6 total (mapped to Phase 9, gated on Phase 5 accuracy validation)
- Phase 1 note: Infrastructure phase — no direct v1 requirements, enables all subsequent phases

---
*Requirements defined: 2026-03-01*
*Last updated: 2026-03-01 after roadmap redesign (9-phase structure)*
