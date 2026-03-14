# CaliTimer

## What This Is

CaliTimer is an iOS app (iPhone only, iOS 17+) that uses on-device pose estimation to automatically detect and time calisthenics static skill holds in real-time. Athletes point their phone at their training space, start a session, and the app handles detection and timing with no manual input required during training. Fully offline — all processing and storage is on-device.

v1.0.0 shipped with the full handstand detection core: live camera feed, geometric pose classifier, 3-state hold machine, live timer, target duration alerts, skeleton overlay, and upload mode (detect holds in imported video). Session history, video capture, and robustness are deferred to the next milestone.

## Core Value

Automatic hold timing with zero manual input — the app knows when the hold starts and when it breaks, so athletes can focus entirely on the skill.

## Requirements

### Validated

- ✓ User can start and end an explicit training session — v1.0.0
- ✓ Holds are grouped under the session they occur in — v1.0.0
- ✓ App automatically detects handstand hold via pose estimation (no start/stop buttons) — v1.0.0
- ✓ Timer counts up during hold, visible on screen in real-time — v1.0.0
- ✓ Detection state shown on screen (searching → pose detected → timing) — v1.0.0
- ✓ Skeleton overlay visible on camera feed, independently toggleable — v1.0.0
- ✓ Detection state indicator independently toggleable — v1.0.0
- ✓ User can set target hold duration on the fly during a session — v1.0.0
- ✓ Visual and audio alert fires when target duration is reached — v1.0.0 (audio-only; haptics deferred by user decision)
- ✓ App works with front and rear camera — v1.0.0
- ✓ App works with phone propped or on a stand — v1.0.0
- ✓ User can import existing video from camera roll — v1.0.0
- ✓ Detection pipeline runs against imported video (identifies holds) — v1.0.0

### Active

**Session History**
- [ ] Session history log shows all holds (skill, duration, date, camera used) grouped by session
- [ ] Personal best per skill tracked locally

**Video — Live Mode**
- [ ] Each hold attempt is recorded automatically (buffered in temp storage)
- [ ] User reviews each clip immediately after hold ends (keep/discard)
- [ ] Kept clips are saved to camera roll; discarded clips are deleted immediately

**Video — Upload Mode**
- [ ] Output matches live mode: detected skill, hold durations, trimmed clip per hold, keep/discard review

**Robustness**
- [ ] App recovers gracefully from interruptions (phone calls, backgrounding)
- [ ] Temporary video files from interrupted sessions are cleaned up on next app launch
- [ ] Pose estimation frame processing is throttled when thermal state is elevated

### Out of Scope

- Dynamic movement detection (reps, pull-ups, etc.) — static skills only for v1
- Multi-skill detection in v1.0 — Handstand only at launch; Front Lever, Back Lever, Planche, Human Flag in v2
- Apple Watch companion — defer post-launch
- iCloud / cross-device sync — offline-first; no cloud
- Social or sharing features — out of scope
- Apple Health integration — out of scope
- Progress charts / analytics UI — raw history log is sufficient for v1
- Coaching or guided programs — out of scope
- Monetization — free MVP; validate first, monetize later
- Pre-roll circular video buffer — accepted 1-2s clip-start delay; complexity not justified

## Context

- **Brand assets:** `design-assets/` submodule contains app icons, logos, and a style guide. In-app UI aligns with brand identity (colors, typography). No in-app Figma designs.
- **Closest competitor:** VideoFit — validates keep/discard video workflow but is manual countdown. CaliTimer's differentiator is automatic pose-triggered timing.
- **Target user:** Solo calisthenics athletes (beginner to advanced) who already record their sets and manually track hold durations.
- **Current codebase state:** ~2,532 Swift LOC, fully first-party Apple stack (Swift 6, SwiftUI, Vision, AVFoundation, SwiftData, XcodeGen).
- **Skill rollout:** v1.0 = Handstand only. v2 = Front Lever, Back Lever, Planche, Human Flag + progressions.
- **Known tech debt:** HandstandClassifier angle thresholds need empirical tuning with real training data. debugPrintKeys() still in production build — should be gated before App Store submission.

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
| iOS 17+ minimum | Modern SwiftUI (@Observable), Vision framework improvements, ~85%+ device coverage | ✓ Good — no compatibility issues |
| Apple Vision (VNDetectHumanBodyPoseRequest) | First-party, no dependencies, sufficient for geometric classifier | ✓ Good — works well for handstand; joint confidence degrades on inverted poses (mitigated with lowered threshold) |
| Explicit session model | Explicit start/end enables session-level history grouping and cleaner data model | ✓ Good |
| Target duration set on the fly | Simplest UX — no pre-session config needed; adjustable mid-session | ✓ Good — validated in Phase 5 |
| Handstand-only for v1 | Focus detection accuracy on one skill before expanding; faster to ship and validate | ✓ Good |
| Free MVP | Validate product-market fit before monetization decision | — Pending |
| XcodeGen (project.yml) | Reproducible, git-friendly project generation | ✓ Good — avoids binary .pbxproj conflicts |
| CameraManager @MainActor + serial DispatchQueue | Simpler SwiftUI integration; CameraActor preserved for Vision frame processing | ✓ Good |
| Lenient 1+1 joint classifier (min wrist Y < max ankle Y) | Avoids false negatives on side-on angles; can be tightened empirically | ⚠️ Revisit — needs threshold tuning with real data |
| Audio-only target alert (no haptics) | User decision during Phase 5 | ✓ Good |
| Upload mode = live mode UX (realtime, not fast-scan) | AVAssetReader fast-scan caused skeleton/timer sync issues; realtime mirror is simpler and consistent | ✓ Good |
| VisionProcessor confidence threshold lowered to > 0.1 | Vision degrades on inverted poses; 0.2 caused missed detections on device | ✓ Good — shoulder/hip fallback also added |

---
*Last updated: 2026-03-14 after v1.0.0 milestone*
