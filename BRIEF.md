# CaliTimer — Project Brief

---

## What It Is

CaliTimer is an iOS app that uses on-device computer vision to automatically detect and time calisthenics static skill holds in real-time. Point your phone at your training space, get into position, and the app handles everything — detection, timing, recording, and logging — with no manual input required.

---

## The Problem

Training static calisthenics skills (handstands, front lever, planche, etc.) requires athletes to track both form and hold duration simultaneously — which is impossible mid-skill. The current workaround: record every set on your phone, then scrub through footage afterward to find how long you held.

This creates compounding friction:

- You never know your hold time in real-time — feedback is always delayed
- You accumulate massive volumes of training footage, most of which is useless
- Reviewing footage is tedious and breaks training flow

No dedicated tool handles this automatically. Athletes are doing it manually, every session.

---

## The Solution

CaliTimer eliminates all manual steps. The app uses pose estimation to detect when the user is in a valid skill position, starts the timer automatically, and stops it the moment the hold breaks. Every hold is logged instantly. Video is recorded per hold and immediately reviewable — the user decides to keep or discard it before it ever touches their camera roll.

---

## Key Features

- **Automatic skill detection** — no start/stop buttons; timing begins when the pose is confirmed
- **Real-time hold timer** — live countdown visible on screen during the hold
- **Target duration alerts** — visual/haptic signal when a target hold time is reached
- **Per-hold video recording** — each attempt is captured automatically
- **Instant keep/discard review** — review the clip immediately after; discard it and it's gone
- **Session history log** — every hold recorded with skill, duration, date, and camera used
- **Personal best tracking** — longest hold per skill, tracked locally
- **Front and rear camera support** — works with phone propped or on a stand
- **Video upload mode** — import footage from camera roll and run the same detection pipeline against it; useful for testing and creating marketing content
- **Fully offline** — all processing and storage is on-device; no accounts, no cloud

---

## Video Upload Mode

Users can import an existing video from their camera roll and run the same pose detection pipeline against it. The app scrubs through the video, identifies holds, timestamps them, and outputs the same data as a live session — detected skill, hold durations, and a trimmed clip per hold.

**Primary use cases:**
- **Testing & development** — validate detection accuracy against real training footage without needing a live session
- **Marketing** — process existing footage to produce clean, timed clips with accurate hold data for promotional content

**Behaviour:**
- Detection output mirrors the live camera flow: holds are identified, timed, and logged
- Detected hold clips are available for keep/discard review, same as live mode
- Processed video is not automatically saved — user decides what to keep

---

## How It Works Under the Hood

- **Pose estimation** runs continuously on the live camera feed
- Each skill has a defined pose signature; when the live pose matches with sufficient confidence, a hold is registered
- Timing starts on detection and stops when the pose drops below the confidence threshold
- Video is buffered locally per hold and held in temporary storage until the user resolves it (keep/discard)
- All session data is stored locally on-device; no external calls are made at any point

**Platform:** iOS 17+, iPhone only  
**Processing:** On-device only 
**Storage:** Local, offline-first

---

## What Makes It Different

The core differentiator is **automatic detection**. Every other tool in this space — interval timers, VideoFit, manual recording setups — requires the user to start timing themselves. CaliTimer is the first tool that actually *knows* when the hold is happening.

The closest competitor, VideoFit, validates the problem and the keep/discard video review workflow. But VideoFit is a smarter manual timer — it counts down from a number the user sets. CaliTimer measures what actually happened: how long the athlete held the skill, from the moment pose was confirmed to the moment it broke.

**CaliTimer vs. VideoFit at a glance:**

| | VideoFit | CaliTimer |
|---|---|---|
| Timing method | Manual countdown | Automatic pose detection |
| Knows when hold starts | No | Yes |
| Real-time skill feedback | No | Yes |
| Requires setup per set | Yes | No |
| Keep/discard video review | Yes | Yes |

---

## Target User

Begginer-to-advanced calisthenics athletes who train static skills seriously and solo. They already record their sets to check form, already track hold durations, and already deal with video clutter — they're just doing all of it manually. CaliTimer is built for athletes who know what they're training and want the tooling to match.

---

## Skill Scope

**Phase 1 (Launch):** Handstand  
**Phase 2:** Front Lever, Back Lever, Planche, Human Flag  
**Phase 3:** Skill variations and progressions (tuck planche, straddle front lever, one-arm handstand, etc.)

---

## Privacy & Permissions

- Camera: required for detection and recording
- Photo Library (Add): required to save kept clips
- Photo Library (Read): required for video upload mode — importing existing footage
- No user account required
- No data leaves the device — ever

---

## Out of Scope (v1)

- Dynamic movement detection (reps, pull-ups, etc.)
- Apple Watch companion
- iCloud / cross-device sync
- Social or sharing features
- Apple Health integration
- Progress charts / analytics UI
- Coaching or guided programs

