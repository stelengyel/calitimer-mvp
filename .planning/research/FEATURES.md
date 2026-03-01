# Feature Research

**Domain:** iOS pose-detection automatic hold timer for calisthenics
**Researched:** 2026-03-01
**Confidence:** MEDIUM — Core feature landscape well-established through competitor analysis; specific athlete expectations extrapolated from adjacent products and community signals due to narrow niche

---

## Competitive Context

Three types of competitors inform this analysis:

- **VideoFit** — Closest in UX philosophy (video-first, form-check, keep/discard). Manual timer only, no CV detection.
- **Handstand Timer** (App Store, id1370178499) — Uses Apple Watch motion-based approach. 2.3/5 stars across 7 reviews. Fails because false-positive triggering, unclear UX, requires Watch. Not pose-estimation.
- **Handstand Timer MJ** (App Store, id6563139554) — Camera-based pose detection. 5.0/5 stars but only 1 review. Very new. iOS 13+, 127MB. No session history or video recording evident.
- **Handstand Quest** — Voice-controlled ("say start/say stop"). No automatic CV detection. Video recording with timer overlay. Personal best progress over time. Strong in structured programming, weak in zero-friction timing.

The automatic CV-triggered, zero-touch hold timer is a genuine gap. No existing app nails: automatic detection + session-based video keep/discard + personal best history, all offline.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Real-time skeleton overlay on camera feed | Every CV fitness app (QuickPose, Handstand Timer MJ, Apple Vision demos) shows skeleton; users associate it with proof that detection is working | MEDIUM | Toggle on/off: power users want it, others find it cluttered. Both modes needed. |
| Visible detection state indicator | Without clear feedback (searching / detecting / timing) users assume the app is broken; Handstand Timer's 2.3 stars are partly from this confusion | LOW | Three states minimum: searching, detected, timing. Color + icon change. |
| Live timer counting up during hold | Core primitive — athletes glance at screen to see live seconds; without this the app provides no real-time value | LOW | Large, legible digits. Center of screen during active hold. |
| Session start/end control | Athletes train in sessions, not isolated reps; grouping holds under a session is expected by anyone who has used any workout tracker | LOW | Explicit start/end. Not automatic session detection — too magical and unpredictable. |
| Automatic hold detection (no manual start/stop) | This is the core differentiator but also now a user expectation for any app claiming CV detection — if the CV exists but still needs manual trigger, users will be disappointed | HIGH | The entire value prop. State machine: body not visible → body visible but not pose → pose detected → timing → pose broken. |
| Hold duration saved per attempt | Every competitor (Handstand Quest, Kyle Weiger, VideoFit) logs attempt durations. Missing this makes the session ephemeral — no reason to use the app again | LOW | Store: skill, duration (ms precision), timestamp, session ID. |
| Session history log | Users expect to see past sessions and holds. Without history, the app is a stopwatch, not a tracker | MEDIUM | Grouped by session. Each session shows date, skill, holds with durations. |
| Personal best per skill | Table stakes for any timing/athletic performance app. Users expect to know their PR. Athletes are deeply motivated by PBs. | LOW | Single value per skill (longest hold ever). Show on session summary and history. |
| Front and rear camera support | Athletes train with phone propped at varying distances and angles. Front camera is needed for mirror feedback; rear is needed for distance shots | LOW | Simple toggle in session UI. |
| Haptic alert when target duration reached | When inverted (handstand), athletes cannot look at the screen. Haptic is the only reliable signal. Critical for the use case. | LOW | Single strong haptic when target hit. Optional audio alert as well. |
| Target duration settable on the fly | Athletes set goals per session attempt, not globally. Must be adjustable without leaving session mode | LOW | Inline control on main screen. No modal, no settings screen. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required for entry, but create genuine competitive advantage over VideoFit and manual tracking.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Immediate post-hold video review with keep/discard | VideoFit validates this pattern. Zero athletes want to manage a camera roll full of failed 2-second attempts. Instant review with one-tap keep/discard is the UX gold standard. Without it, athletes either record everything (storage nightmare) or record nothing (no form feedback). | HIGH | Show clip immediately after hold ends. Keep → save to camera roll. Discard → delete immediately. No intermediate storage. Buffered recording during hold; clip starts a few seconds before detection to capture approach. |
| Automatic video capture scoped to hold duration | Recording the whole session gives athletes an uneditable blob. Auto-clipping to hold start/end means every clip is a usable form-check. Competitors don't do this. | HIGH | Requires pre-roll buffer (circular buffer 2–3 sec before detection). Clip is trimmed to hold + buffer. |
| Video upload mode (import existing video, extract holds) | Athletes record training sessions already — either with another device or in VideoFit. The ability to run the same detection pipeline on an imported video means CaliTimer can extract structured data from footage athletes already have. No competitor offers this. | HIGH | Same detection engine, applied to AVAsset frame-by-frame. Output: list of detected holds with timestamps. Same keep/discard review per hold. |
| Multi-skill expansion (Phase 2: Front Lever, Back Lever, Planche, Human Flag) | No dedicated app supports all 5 elite static skills in one place. This is the long-term moat. Phase 1 validates detection quality; Phase 2 creates the category-defining product. | HIGH | Each skill requires its own pose classifier. Phase 1 must prove detection quality before Phase 2 investment. |
| Fully offline, no account required | VideoFit: no sign-up (good model). Most fitness apps require accounts, cloud sync, etc. Privacy-conscious and technically sophisticated athletes explicitly value on-device processing. | LOW | Marketing differentiator as well as technical fact. Reinforce in onboarding. |
| Confidence threshold visibility (advanced mode) | Power users — the calisthenics community skews technically literate — want to understand why a hold was or wasn't detected. Showing detection confidence helps trust and helps athletes adjust body position. | MEDIUM | Optional debug overlay. Hidden by default. Accessible via long-press or settings. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for CaliTimer's specific use case and audience.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Social sharing / feed / community | Every fitness app adds this. Athletes like showing off PRs. | Requires accounts, server infrastructure, moderation. Destroys the "no account, fully offline" value prop. Premature optimization — validate product first. | Allow share-to-system-sheet of a single clip or PR screenshot. No in-app social graph. |
| Apple Health integration | Users expect fitness apps to sync to Health. Calories, workout minutes, etc. | Handstand holds don't map cleanly to Apple Health's workout types. Estimating calories for a 30-second handstand is unreliable and provides low value. Can be added post-PMF if users request it. | Log workout metadata locally. Note in onboarding that Health sync is not included. |
| iCloud sync / cross-device | Multi-device access is a common request. | Offline-first architecture. iCloud sync adds significant complexity (conflict resolution, data migration, CloudKit schema changes are painful). No competitive pressure to add it — no competitor has it. | Export/import as JSON. Manual backup. Note: data is local by design. |
| Progress charts / analytics graphs | Feels like a natural addition to personal best tracking. | Charting requires meaningful data volume. In Phase 1, athletes may have 20–100 data points. Charts will feel empty and give false signal. Premature at MVP. | Show raw history log and personal best prominently. Single line "Your PB: 45s" is more actionable than a sparse chart. |
| Coaching cues / form feedback | CV is already running — why not add form scoring? | Real-time form analysis for handstands is a research-grade problem. Body positioning judgment (hollow vs. arched, straight vs. bent) requires multi-joint angle analysis and training data. Adding inaccurate cues destroys trust faster than having none. | Phase 3+ consideration after core detection is solid. |
| Guided programs / workout plans | Competitors (Calisteniapp, Thenx) have these. | CaliTimer is a timing tool, not a coach. Adding programs competes with established apps in their core area, dilutes focus, and adds massive content/UX complexity. | Position as the best tool for athletes already following any program. |
| Apple Watch companion | Athletes training handstands might want glanceable data. | Adds a separate codebase, WatchConnectivity layer, and separate UX to maintain. Post-launch validation feature. | The haptic alert on iPhone addresses the core need (knowing when target is hit without looking at screen). |
| Manual hold entry (type in a duration) | Power users want to log holds from sessions they didn't record. | Corrupts the integrity of auto-detected data. Mixed manual/automatic data makes session history harder to trust. | Phase 2 consideration with explicit "manually logged" tagging. Not MVP. |
| Video filters / slow-mo replay | Athletes watching form checks might want better review tools. | Scope creep. VideoFit exists for deep video review. CaliTimer's video feature is keep-or-discard, not a video editor. Adding filters competes with VideoFit on their strength. | Standard playback only. Athletes use VideoFit for deep form analysis. |
| Automatic session detection (no explicit start/end) | Feels more magical and frictionless. | Ambiguity about what's "in a session" creates data confusion. False-positive session boundaries corrupt history. Athletes starting a warm-up, pausing, coming back later would create messy sessions. | Explicit session start/end is the right call. Takes 2 taps total. |

---

## Feature Dependencies

```
[Session Model]
    └──requires──> [Hold Storage with session_id]
                       └──requires──> [Detection State Machine]
                                          └──requires──> [Pose Estimation Engine]

[Video Keep/Discard Review]
    └──requires──> [Automatic Video Capture]
                       └──requires──> [Pre-roll Buffer]
                                          └──requires──> [Detection State Machine]

[Personal Best per Skill]
    └──requires──> [Hold Storage with skill + duration]
                       └──requires──> [Detection State Machine]

[Target Duration Alert]
    └──requires──> [Live Timer]
                       └──requires──> [Detection State Machine]

[Video Upload Mode]
    └──requires──> [Detection State Machine] (same pipeline, different input)
    └──requires──> [Video Keep/Discard Review] (same UX, post-processing output)

[Skeleton Overlay] ──enhances──> [Detection State Indicator] (visual confirmation they agree)

[Phase 2: Multi-skill]
    └──requires──> [Phase 1 detection proven accurate for Handstand]
    └──requires──> [Hold Storage schema supports skill field] (already in Phase 1 design)
```

### Dependency Notes

- **Session Model requires Detection State Machine:** You cannot group holds into sessions without reliable detection to know when a hold starts/ends.
- **Video Keep/Discard requires Pre-roll Buffer:** Athletes want video that starts slightly before the detected hold, not just the hold itself. Pre-roll captures the approach.
- **Video Upload Mode reuses Detection pipeline:** This is a Phase 1 investment that pays off in Phase 1 (offline import) without requiring new detection work.
- **Personal Best requires Hold Storage:** Storage schema must include skill + duration from day one to support PB calculation. Retrofitting this is costly.
- **Phase 2 Multi-skill requires Phase 1 accuracy validation:** Expanding to harder-to-detect skills (Front Lever, Human Flag) without first proving Handstand detection quality is sound would compound accuracy problems.

---

## MVP Definition

### Launch With (Phase 1 MVP)

Minimum viable product — what's needed to validate automatic CV timing value.

- [ ] Pose estimation engine detecting handstand (skeleton tracked, handstand state classified) — the entire value proposition
- [ ] Detection state machine with visible state indicator (searching / detected / timing) — core trust signal
- [ ] Real-time timer counting up during hold — athlete feedback loop
- [ ] Skeleton overlay on camera feed (toggleable) — proof detection is working
- [ ] Session start/end with holds grouped under session — data integrity foundation
- [ ] Hold duration saved per attempt — makes the session durable
- [ ] Personal best per skill (handstand only) — motivational core, takes 10 lines of code on top of storage
- [ ] Haptic + audio alert at target duration — critical for inverted athletes who can't look at screen
- [ ] Target duration settable on the fly from main screen — one stepper/slider, no modal
- [ ] Automatic video capture (pre-roll buffer) per hold — enables keep/discard
- [ ] Post-hold keep/discard review — the VideoFit-validated UX that turns video from liability into asset
- [ ] Front and rear camera selection — front for close work, rear for distance
- [ ] Session history log (holds grouped by session, date, skill, duration) — makes repeat use worthwhile
- [ ] Video upload mode (import, extract holds, keep/discard review) — high value, same pipeline

### Add After Validation (v1.x)

Features to add once core detection and UX are proven.

- [ ] Detection confidence debug overlay — add if power users request in early feedback
- [ ] Offline-first export / backup — if users accumulate significant data history
- [ ] Onboarding calibration flow — walk through detection setup if false-positive rates are reported

### Future Consideration (Phase 2+)

Features to defer until Phase 1 demonstrates product-market fit.

- [ ] Front Lever detection — requires separate pose classifier training/validation
- [ ] Back Lever detection — same
- [ ] Planche detection — same, hardest to distinguish from non-planche horizontal positions
- [ ] Human Flag detection — requires lateral/side-facing camera; different setup from front/rear
- [ ] Progressions and variations per skill (Phase 3) — tuck front lever, straddle planche, etc.
- [ ] Apple Watch companion — haptic on iPhone is sufficient for MVP
- [ ] Apple Health integration — low value-to-complexity for hold-based skills
- [ ] Progress charts — meaningful only with sustained usage data

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Automatic handstand detection | HIGH | HIGH | P1 |
| Detection state indicator | HIGH | LOW | P1 |
| Live timer during hold | HIGH | LOW | P1 |
| Haptic/audio at target duration | HIGH | LOW | P1 |
| Session start/end model | HIGH | LOW | P1 |
| Hold storage + personal best | HIGH | LOW | P1 |
| Auto video capture + keep/discard | HIGH | HIGH | P1 |
| Session history log | HIGH | MEDIUM | P1 |
| Target duration on-the-fly | HIGH | LOW | P1 |
| Skeleton overlay (toggleable) | MEDIUM | MEDIUM | P1 |
| Front/rear camera toggle | MEDIUM | LOW | P1 |
| Video upload mode | HIGH | MEDIUM | P1 |
| Detection confidence debug overlay | LOW | LOW | P2 |
| Progress charts | LOW | MEDIUM | P3 |
| Multi-skill (Front Lever, etc.) | HIGH | HIGH | P2 (Phase 2) |
| Apple Watch companion | LOW | HIGH | P3 |
| Apple Health sync | LOW | MEDIUM | P3 |
| Social/sharing features | LOW | HIGH | Never (MVP) |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | VideoFit | Handstand Timer (id1370178499) | Handstand Timer MJ (id6563139554) | Handstand Quest | CaliTimer Approach |
|---------|----------|-------------------------------|----------------------------------|-----------------|-------------------|
| Automatic CV detection | No — manual timer | Apple Watch motion (not camera pose) | Yes — camera pose detection | No — voice commands | Yes — camera pose, on-device Vision/CoreML |
| Zero-touch during hold | No — manual start/stop | Partial — Watch auto-detects but false positives | Unknown | No | Yes — core differentiator |
| Live timer during hold | Yes — manual countdown | Yes | Unknown | Yes (voice-triggered) | Yes — count-up, visible on screen |
| Session model | No | No | Unknown | No | Yes — explicit start/end, holds grouped |
| Personal best tracking | No | Yes (longest time shown) | Unknown | Yes — tracks "best record" | Yes — per skill |
| Session history | No | No | Unknown | Yes — calendar view | Yes — date/session/skill/duration |
| Video capture auto-scoped to hold | No — records whole session | No | No | No — records per exercise not per hold | Yes — pre-roll buffer + hold clip |
| Keep/discard video review | Partial — configurable auto-delete, not per-hold | No | No | No | Yes — per-hold immediate review |
| Video upload mode (import) | No | No | No | No | Yes — same pipeline on imported video |
| Skeleton overlay | No | No | Unknown | No | Yes — toggleable |
| Offline, no account | Yes | Yes | Yes | No — requires account | Yes |
| Multi-skill support | N/A | No | Unknown | No | Phase 2: Front Lever, Back Lever, Planche, Human Flag |
| iOS-native, modern | Yes | iOS 9.2+ | iOS 13+ | Yes | iOS 17+ — enables Vision improvements, @Observable |

**Key gap:** No competitor combines automatic pose-triggered timing + session-based history + automatic per-hold video clip + keep/discard review in one app. This is CaliTimer's white space.

---

## Sources

- [VideoFit: Workout video timer app](https://www.videofit.app/en) — Keep/discard workflow, timer UX, video management
- [App Store: Handstand Timer (id1370178499)](https://apps.apple.com/us/app/handstand-timer/id1370178499) — 2.3/5 stars, failure modes (false positives, confusing UX)
- [App Store: Handstand Timer MJ (id6563139554)](https://apps.apple.com/us/app/handstand-timer-mj/id6563139554) — Camera-based pose detection, 5.0/5 (1 review), very recent
- [App Store: Handstand Quest (id1482090288)](https://apps.apple.com/us/app/handstand-quest/id1482090288) — Voice-triggered, personal best tracking, no automatic CV
- [QuickPose iOS SDK](https://quickpose.ai/products/ios-sdk/) — Hold timing capability, plank timer pattern, pose hold detection
- [QuickPose AI Plank Timer](https://quickpose.ai/exercise-library/fitness/ai-plank-timer/) — Automatic hold start/stop timer on pose detection, form-pausing behavior
- [QuickPose FitCount GitHub](https://github.com/quickpose/FitCount) — End-to-end AI fitness counter/timer demo app architecture
- [Human Pose Estimation for Fitness Apps — MobiDev](https://mobidev.biz/blog/human-pose-estimation-technology-guide) — Technical landscape and UX patterns
- [Apple HIG: Workouts patterns](https://developer.apple.com/design/human-interface-guidelines/workouts) — iOS workout UX standards
- [2025 Guide to Haptics — Medium](https://saropa-contacts.medium.com/2025-guide-to-haptics-enhancing-mobile-ux-with-tactile-feedback-676dd5937774) — Haptic feedback UX best practices
- [Fitness App UX — Stormotion](https://stormotion.io/blog/fitness-app-ux/) — Distraction-free workout UX patterns
- [The 18 Best Calisthenics Apps in 2026 — CalisthenicsworldWide](https://calisthenicsworldwide.com/apps/best-calisthenics-apps/) — Competitor landscape survey
- [Show HN: iOS app that corrects your form in real time — Hacker News](https://news.ycombinator.com/item?id=43331940) — Real-world reception of CV fitness apps

---

*Feature research for: iOS calisthenics automatic hold timer (CaliTimer)*
*Researched: 2026-03-01*
