# CaliTimer

## What This Is

CaliTimer is an iOS app (iPhone only, iOS 17+) that uses on-device pose estimation to automatically detect and time calisthenics static skill holds in real-time. Athletes point their phone at their training space, start a session, and the app handles detection, timing, video capture, and logging with no manual input required during training. Fully offline — all processing and storage is on-device.

## Core Value

Automatic hold timing with zero manual input — the app knows when the hold starts and when it breaks, so athletes can focus entirely on the skill.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Session**
- [ ] User can start and end an explicit training session
- [ ] Holds are grouped under the session they occur in

**Detection & Timing**
- [ ] App automatically detects handstand hold via pose estimation (no start/stop buttons)
- [ ] Timer counts up during hold, visible on screen in real-time
- [ ] Detection state is shown on screen (searching → pose detected → timing)
- [ ] Skeleton overlay is visible on camera feed (can be toggled on/off)
- [ ] State detection indicator can be toggled on/off independently
- [ ] User can set a target hold duration on the fly during a session
- [ ] Visual and haptic alert fires when target duration is reached

**Video**
- [ ] Each hold attempt is recorded automatically (buffered in temp storage)
- [ ] User reviews each clip immediately after hold ends (keep/discard)
- [ ] Kept clips are saved to camera roll; discarded clips are deleted immediately

**History & Tracking**
- [ ] Session history log shows all holds (skill, duration, date, camera used) grouped by session
- [ ] Personal best per skill tracked locally

**Camera**
- [ ] App works with front and rear camera (user selects)
- [ ] App works with phone propped or on a stand

**Video Upload Mode**
- [ ] User can import existing video from camera roll
- [ ] Same detection pipeline runs against imported video (identifies holds, timestamps them)
- [ ] Output matches live mode: detected skill, hold durations, trimmed clip per hold, keep/discard review

### Out of Scope

- Dynamic movement detection (reps, pull-ups, etc.) — static skills only for v1
- Multi-skill detection in Phase 1 — Handstand only at launch; Front Lever, Back Lever, Planche, Human Flag in Phase 2
- Apple Watch companion — defer post-launch
- iCloud / cross-device sync — offline-first; no cloud
- Social or sharing features — out of scope
- Apple Health integration — out of scope
- Progress charts / analytics UI — raw history log is sufficient for v1
- Coaching or guided programs — out of scope
- Monetization — free MVP; validate first, monetize later

## Context

- **Brand assets:** `design-assets/` submodule contains app icons, logos, and a style guide used for the landing page and marketing. In-app UI must align with this brand identity (colors, typography, visual style). No in-app Figma designs exist yet.
- **Closest competitor:** VideoFit — validates the keep/discard video workflow but is a manual countdown timer. CaliTimer's differentiator is automatic pose-triggered timing.
- **Target user:** Solo calisthenics athletes (beginner to advanced) who already record their sets and manually track hold durations. They want tooling that matches their training intensity.
- **Skill rollout:** Phase 1 = Handstand only. Phase 2 = Front Lever, Back Lever, Planche, Human Flag. Phase 3 = Progressions and variations.

## Constraints

- **Platform:** iOS 17+, iPhone only
- **Processing:** On-device only — no external API calls, no cloud, no accounts
- **Storage:** Local only — video stays on device until user explicitly keeps it to camera roll
- **Permissions required:** Camera (detection + recording), Photo Library Write (save kept clips), Photo Library Read (video upload mode)
- **Brand:** UI colors and visual identity must derive from `design-assets/` style guide
- **Monetization:** None for MVP

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| iOS 17+ minimum | Modern SwiftUI (@Observable), Vision framework improvements, ~85%+ device coverage | — Pending |
| Pose estimation framework | Apple Vision vs MediaPipe vs CoreML custom — research phase will determine | — Pending |
| Explicit session model | Explicit start/end enables session-level history grouping and cleaner data model | — Pending |
| Target duration set on the fly | Simplest UX — no pre-session config needed; adjustable mid-session from main screen | — Pending |
| Handstand-only for Phase 1 | Focus detection accuracy on one skill before expanding; faster to ship and validate | — Pending |
| Free MVP | Validate product-market fit before monetization decision | — Pending |

---
*Last updated: 2026-03-01 after initialization*
