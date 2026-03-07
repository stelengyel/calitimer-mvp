---
phase: 5
slug: handstand-detection-timer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — no XCTest target exists; upload mode serves as classifier test harness |
| **Config file** | none — Wave 0 decision: defer XCTest infrastructure |
| **Quick run command** | Build + launch on simulator (confirms no crash, indicator visible) |
| **Full suite command** | Device test session covering all 7 manual requirements |
| **Estimated runtime** | ~15 minutes (full device session) |

> **Wave 0 decision:** Project uses device-validation-first approach (all Phases 1-4 verified on physical device). `HandstandClassifier` is a pure function verifiable via upload mode against known training footage. XCTest infrastructure deferred; revisit if false-positive/negative rates are unacceptable after real-world testing.

---

## Sampling Rate

- **After every task commit:** Build + launch on simulator; verify no crash, state indicator visible
- **After every plan wave:** Full device test session covering all 7 requirements below
- **Before `/gsd:verify-work`:** All 7 manual test cases must pass on physical device
- **Max feedback latency:** ~15 minutes (per-wave device session)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 5-W0-01 | 01 | 0 | DETE-01 | manual | Build succeeds; debug prints confirm Vision joint key strings | — | ⬜ pending |
| 5-01-01 | 01 | 1 | DETE-01 | manual | Upload known handstand footage; holds detected with correct wristY < ankleY logic | N/A | ⬜ pending |
| 5-01-02 | 01 | 1 | DETE-02 | manual | Live session: deliberate false-start movements; confirm no phantom hold entry | N/A | ⬜ pending |
| 5-01-03 | 01 | 1 | DETE-02 | manual | Live session: hold 10s cleanly; confirm timer starts and state reaches .timing | N/A | ⬜ pending |
| 5-02-01 | 02 | 1 | DETE-03 | manual | 3 states visible; toggle via gear sheet hides/shows indicator | N/A | ⬜ pending |
| 5-02-02 | 02 | 1 | DETE-04 | manual | Hold 10s; timer shows correct MM:SS; freezes on hold end | N/A | ⬜ pending |
| 5-03-01 | 03 | 2 | DETE-06 | manual | Set target 5s; hold 7s; beep fires once at 5s, not again | N/A | ⬜ pending |
| 5-03-02 | 03 | 2 | DETE-07 | manual | Change target during live session via gear sheet; new target takes effect immediately | N/A | ⬜ pending |
| 5-04-01 | 04 | 2 | VIDU-02 | manual | Import video with known holds; results list shows correct timestamps and durations | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> Task IDs are placeholders until plans are written. Update with actual plan task IDs after PLAN.md files are created.

---

## Wave 0 Requirements

- [ ] Confirm Vision joint key strings — add debug `print(detectedPose?.joints.keys)` in `LiveSessionView.onReceive`; record actual strings before `HandstandClassifier` ships
- [ ] Verify build compiles cleanly after adding `HoldStateMachine` and `HandstandClassifier` stubs

*XCTest infrastructure: deferred. Upload mode is the classifier test harness (see CONTEXT.md: "Upload mode is intentionally used for testing and debugging the classifier").*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Handstand detected from wristY < ankleY | DETE-01 | Vision sensor data; no mock framework | Import video with known handstand; confirm holds appear in results list |
| State machine debounce prevents false starts | DETE-02 | Requires physical movement through camera | Perform jump-through / kip-up pass; confirm no hold recorded |
| Exit debounce prevents phantom terminations | DETE-02 | Requires simulated frame drops; hard to mock | Mid-hold, briefly wave hand in front of lens; confirm hold continues |
| Indicator 3-state visual distinction | DETE-03 | Color/animation judgment | Stand in front of camera; observe grey → ember → green transitions |
| Indicator toggle in gear sheet + Settings | DETE-03 | UI interaction | Toggle off in gear sheet; confirm dot disappears; toggle in Settings; same result |
| Timer MM:SS accuracy | DETE-04 | Requires real elapsed time | Hold 65s; verify display shows "1:05" not "65" |
| Beep fires once at target | DETE-06 | Audio output; device only | Hold past target; confirm single beep, no repeat |
| Target change mid-session | DETE-07 | Live session state | Open gear sheet during active hold; change target; confirm effect without session reset |
| Upload scan timestamps are video-time offsets | VIDU-02 | Requires known video with timestamped holds | Import video; compare result timestamps against known hold positions |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15 minutes
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
