# Project Research Summary

**Project:** CaliTimer MVP
**Domain:** iOS on-device real-time pose estimation timer for calisthenics (handstand detection)
**Researched:** 2026-03-01
**Confidence:** MEDIUM-HIGH

## Executive Summary

CaliTimer is a narrow-niche iOS app that solves a genuine product gap: no existing app combines automatic camera-based pose detection, session-scoped hold timing, automatic per-hold video capture with keep/discard review, and personal-best history in a single offline-first package. The competitive analysis confirms this white space — the closest rival (Handstand Timer, 2.3 stars) fails on false positives and opaque UX, and no competitor strings together all four capabilities. The recommended approach is a fully first-party Apple stack (Swift 6, SwiftUI, Vision, AVFoundation, SwiftData) with zero external dependencies, targeting iOS 17+ and using `VNDetectHumanBodyPoseRequest` for pose detection. This stack is technically validated, eliminates build complexity from CocoaPods and third-party models, and keeps the architecture entirely on-device.

The core technical challenge — and the highest-risk element — is handstand detection accuracy. Apple's Vision framework is explicitly documented to degrade on inverted poses (WWDC20 session 10653: "if people are bent over or upside down, the body pose algorithm will not perform as well"). The mitigation is geometric rather than confidence-based: classify the handstand by joint-relationship rules (feet above head in normalized coordinates, wrists near midline, body vertical alignment angle) rather than relying on per-joint confidence scores that become unreliable when inverted. This must be validated in Phase 1 before any other feature is built on top of it. If Vision accuracy proves insufficient after testing, a custom CoreML model is the phase-2 fallback — MediaPipe BlazePose is eliminated because its orientation anchor fails for fully inverted athletes.

The second highest-risk area is the dual-pipeline video architecture: simultaneous pose estimation on `AVCaptureVideoDataOutput` frames plus `AVAssetWriter` recording with a circular pre-roll buffer. This combination is the correct approach (AVCaptureMovieFileOutput cannot do both simultaneously), but carries concrete pitfalls: CMSampleBuffer pool exhaustion from retained buffers, AVAssetWriter initialization latency of 5-7 seconds on first call, Swift 6 concurrency compile errors from AVFoundation's non-Sendable types, and camera session interruption leaving writers in corrupt state. Each of these has a known prevention strategy that must be designed in from day one, not retrofitted.

---

## Key Findings

### Recommended Stack

The entire stack is first-party Apple frameworks with no external dependencies and no Swift Package Manager entries required. Swift 6 with Xcode 16+ is required for safe AVFoundation actor isolation. SwiftUI is the UI root with one `UIViewRepresentable` wrapping `AVCaptureVideoPreviewLayer` as a leaf — not the root — keeping all `@Observable` bindings, navigation, and sheets idiomatic. SwiftData handles persistence cleanly given CaliTimer's simple data model (sessions, holds, personal bests) and iOS 17+ target; Core Data would be overkill. The `@Observable` macro (iOS 17+) replaces ObservableObject/Combine throughout.

**Core technologies:**
- **Swift 6 / Xcode 16+**: Primary language — required for safe concurrency with AVFoundation actors and Vision async API
- **SwiftUI (iOS 17+)**: All UI — `@Observable` macro, ZStack overlay composition, navigation; camera preview is a UIViewRepresentable leaf
- **Vision `VNDetectHumanBodyPoseRequest`**: Body pose detection — first-party, Neural Engine accelerated, zero dependency, frame-relative coordinates work for inverted poses
- **AVFoundation (`AVCaptureVideoDataOutput` + `AVAssetWriter`)**: Camera capture + recording — only combination that allows simultaneous Vision frame processing and pre-roll buffering
- **SwiftData (iOS 17+)**: Session/hold/personal-best persistence — fits data model, no complex predicates needed
- **Swift Observation (`@Observable`)**: Reactive state across CameraActor, PoseDetector, SessionCoordinator — more granular re-renders than ObservableObject
- **VideoToolbox (built-in)**: Hardware H.264 encoding for pre-roll buffer — reduces ring buffer memory 10x vs. raw pixel buffers

**What NOT to use:**
- MediaPipe BlazePose — face-detection-based orientation anchor fails for handstand (inverted athlete)
- `AVCaptureMovieFileOutput` — cannot simultaneously deliver frames to Vision
- Combine/ObservableObject — superseded by `@Observable` on iOS 17+
- `VNDetectHumanBodyPose3DRequest` — requires LiDAR, excludes non-Pro devices, unnecessary complexity for hold detection

### Expected Features

The automatic CV-triggered, zero-touch hold timer is a genuine competitive gap. No competitor delivers automatic detection + session-scoped video keep/discard + personal-best history, all offline.

**Must have (table stakes — launch with these):**
- Automatic handstand detection via pose estimation — the entire value proposition
- Detection state indicator (searching / detected / timing) — the trust signal that prevents user confusion
- Live timer counting up during hold — real-time athlete feedback loop
- Skeleton overlay on camera feed (toggleable) — proof detection is working
- Haptic + audio alert when target duration reached — critical for inverted athletes who cannot see screen
- Target duration settable on-the-fly from main screen — inline, no modal
- Session start/end with holds grouped — data integrity foundation
- Hold duration saved per attempt — makes the session durable
- Personal best per skill — motivational core, takes ~10 lines on top of storage
- Front/rear camera toggle — athletes train at varying distances and angles
- Session history log (date, skill, duration per hold) — makes repeat use worthwhile
- Automatic video capture per hold (pre-roll buffer) — enables keep/discard
- Post-hold keep/discard review — VideoFit-validated UX that turns video from liability into asset
- Video upload mode (import existing footage, extract holds) — same pipeline, different input source

**Should have (competitive differentiators, add post-validation):**
- Detection confidence debug overlay — for power users who want to understand detection behavior
- Onboarding calibration flow — if false-positive rates are reported in early feedback
- Offline export/backup — when users accumulate significant data history

**Defer (v2+):**
- Multi-skill expansion: Front Lever, Back Lever, Planche, Human Flag — each needs its own classifier; gated on Phase 1 detection quality validation
- Progress charts — premature with sparse early data; raw history log and PB are more actionable
- Apple Watch companion — haptic on iPhone addresses the core need
- Apple Health integration — handstand holds don't map cleanly to Health workout types; low value-to-complexity
- Social/sharing features — destroys "no account, fully offline" value proposition

**Anti-features to explicitly avoid:**
- Automatic session detection — false session boundaries corrupt history; explicit start/end takes 2 taps
- Manual hold entry — corrupts integrity of auto-detected data
- Coaching cues/form scoring — inaccurate cues destroy trust faster than no cues; research-grade problem
- iCloud sync — adds conflict resolution and CloudKit schema migration complexity; no competitive pressure

### Architecture Approach

The architecture follows a strict layered actor-per-concern model to satisfy Swift 6 strict concurrency requirements and keep the AVFoundation + Vision pipeline off the main thread. `SessionCoordinator` is the single `@MainActor @Observable` orchestrator that drives UI state; all processing subsystems are isolated actors or dedicated serial queues. The camera, pose detection, recording, and state machine are separate components with explicit boundaries — preventing the "one ViewModel to rule them all" anti-pattern that causes data races and untestability.

**Major components:**
1. **`CameraActor`** (custom GlobalActor) — owns `AVCaptureSession`, manages inputs/outputs, delivers `CMSampleBuffer` to subscribers; never imported by UI
2. **`PoseDetector`** (background serial queue) — runs `VNDetectHumanBodyPoseRequest` per frame; returns `PoseObservation` (joint dict + confidence); input-agnostic (works for live and upload modes)
3. **`HandstandClassifier`** — stateless geometric rule engine: checks wrist-y < ankle-y (inverted), body vertical alignment angle, joint confidence filtering; separate from detection code
4. **`HoldStateMachine`** (`@MainActor @Observable`) — evidence accumulation state machine: requires N consecutive frames meeting threshold before transitioning; resets independently for entry and exit; prevents flickering
5. **`Recorder`** (isolated actor) — circular pre-roll buffer (VideoToolbox-compressed) + `AVAssetWriter`; initialized eagerly at session start; emits clip URL on hold completion
6. **`SessionCoordinator`** (`@MainActor @Observable`) — wires all components; owns session record; triggers haptic at target; saves Hold records to SwiftData; presents clip review
7. **`VideoUploadCoordinator`** — same `PoseDetector` + `HoldStateMachine` wired to `AVAssetReader` instead of `CameraActor`; no `Recorder` needed (clips trimmed from source via `AVAssetExportSession`)
8. **`SwiftData Store`** — `Session`, `Hold`, `SkillPersonalBest` `@Model` classes; personal best is a computed query, not a stored entity

**Key architectural patterns:**
- Evidence accumulation before state transition (WWDC20 pattern) — N consecutive frames required, prevents false hold events
- Circular pre-roll buffer with VideoToolbox compression — keeps ring buffer memory ~5-6MB at 720p vs. hundreds of MB raw
- Shared detection pipeline, dual input sources — live camera and video upload reuse 100% of detection logic
- `AVCaptureVideoPreviewLayer` via `UIViewRepresentable` — bypasses SwiftUI rendering for camera preview, skeleton as `CAShapeLayer` on top

**Build order (mandated by dependencies):**
1. `CameraActor` + `CameraPreviewView` (foundation)
2. `PoseDetector` (needs frames)
3. `HandstandClassifier` + `HoldStateMachine` (needs pose observations)
4. `HoldTimer` + `SessionCoordinator` skeleton (needs state machine)
5. `Recorder` + pre-roll buffer (needs frames + state machine; test state machine first)
6. `SkeletonRenderer` (cosmetic, can be added late)
7. SwiftData models + `StorageService` (scaffold early, wire when coordinator is stable)
8. `VideoUploadCoordinator` + `VideoFrameReader` (last; reuses steps 2-4)

### Critical Pitfalls

Research identified 15 pitfalls across the four domains. The top five by severity and prevention urgency:

1. **Vision inverted-pose accuracy degradation** — Apple explicitly documented that `VNDetectHumanBodyPoseRequest` performs poorly on inverted bodies. Avoid by classifying handstand via geometric joint relationships (feet above head in normalized coordinates) rather than per-joint confidence. Validate with 50-100 handstand frames before building any dependent features. This is the single highest-risk item — if Vision is insufficient, fall back to custom CoreML model.

2. **Threading architecture wrong from day one** — Running `AVCaptureSession.startRunning()` on main thread freezes UI; running Vision inference on main thread drops the camera preview to single-digit FPS. Running either on the wrong thread under Swift 6 strict concurrency produces compile errors that developers paper over with `@unchecked Sendable`. Fix: `CameraActor` with its own GlobalActor, dedicated serial `videoDataOutputQueue` for Vision, all results published to `@MainActor` via `Task { @MainActor in ... }`. Retrofitting this is a high-cost recovery.

3. **Circular pre-roll buffer memory blowup** — Retaining raw `CMSampleBuffer` references exhausts AVFoundation's pixel buffer pool and causes OOM kills at 200-300MB+. Fix: Hardware-encode frames with VideoToolbox before buffering (10-50x compression); cap pre-roll at 2 seconds; call `CFRelease` on discarded buffers immediately. Never buffer uncompressed frames.

4. **AVAssetWriter 5-7 second initialization latency** — Initializing `AVAssetWriter` on-demand when hold detection fires introduces a multi-second dead zone where no video is captured. Fix: Initialize eagerly at session start; create a new writer immediately after each clip is finalized so one is always ready.

5. **Missing debounce state machine — flickering timer** — Single-frame detection triggers create phantom hold events: timer fires and stops repeatedly during a real 2-second hold. Fix: Formal state machine with evidence accumulation counters: `searching → candidateDetected (10-15 consecutive frames) → holdActive → candidateLost (10-20 frame grace period) → holdEnded`. Never start or stop the timer on single-frame detection.

**Additional pitfalls requiring Phase 1 attention:**
- `VNSequenceRequestHandler` must be created once per session, not per frame — prevents jitter and CPU waste
- `AVCaptureVideoPreviewLayer` must be wrapped in `UIViewRepresentable`, not updated via SwiftUI pixel-buffer republishing — prevents preview lag
- `PrivacyInfo.xcprivacy` must be added on day one — App Store submission requirement since May 2024
- Detection pipeline must be behind a `PoseDetectionProvider` protocol to enable unit testing on Simulator

**Additional pitfalls requiring Phase 2 attention:**
- Temp directory video files are not auto-cleared by iOS — requires explicit cleanup on session end and orphan sweep on launch
- Camera session interruption (phone call mid-hold) must call `AVAssetWriter.finishWriting()` in the interruption handler or clips will be corrupt
- Photo library writes must use `PHPhotoLibrary.requestAuthorization(for: .addOnly)` — not the deprecated single-parameter form

---

## Implications for Roadmap

Based on research, the dependency graph is clear and mandates a specific build order. The detection pipeline is the foundation everything else depends on. Video recording is the second tier. History/upload/polish are the third tier.

### Phase 1: Foundation + Core Detection Pipeline

**Rationale:** The handstand detection accuracy is the highest-risk unknown and everything else (timing, video capture, session history) is built on top of it. If detection doesn't work reliably, no amount of downstream features matter. Architecture must also be correct from day one — threading and Swift 6 actor structure cannot be retrofitted without touching every file. This phase validates the core value proposition.

**Delivers:** A working real-time handstand detector with skeleton overlay, detection state indicator, live timer, haptic/audio alert, session start/end, hold storage, and personal best tracking. No video recording yet. Users can train and track holds.

**Features from FEATURES.md:**
- Automatic handstand detection (the entire value prop)
- Detection state indicator (searching / detected / timing)
- Live timer counting up
- Skeleton overlay (toggleable)
- Haptic + audio alert at target duration
- Target duration settable on-the-fly
- Session start/end model
- Hold storage + personal best (schema must be right from day one — schema supports skill field for Phase 2)
- Front/rear camera toggle
- Session history log

**Pitfalls to prevent in this phase:**
- Vision inverted-pose failure → geometric classifier, not confidence-based
- Threading architecture wrong → CameraActor + dedicated serial queue from first commit
- VNImageRequestHandler per-frame → VNSequenceRequestHandler, created once per session
- Vision on main thread → serial background queue for all inference
- SwiftUI pixel-buffer preview → AVCaptureVideoPreviewLayer via UIViewRepresentable
- Missing debounce state machine → formal evidence accumulation from day one
- PrivacyInfo.xcprivacy → added at project creation
- Untestable CV pipeline → PoseDetectionProvider protocol before implementation

**Research flag:** NEEDS deeper research during planning — specific angle thresholds and confidence weighting for the HandstandClassifier, and the test harness strategy for validating detection accuracy on real handstand footage.

---

### Phase 2: Video Capture + Keep/Discard Review

**Rationale:** The automatic video capture + keep/discard workflow is CaliTimer's second major differentiator and the most technically complex remaining feature. It depends on Phase 1 (detection state machine must fire precisely before recording can be triggered). Video upload mode is included here because it reuses the same detection pipeline (already built in Phase 1) and only adds `AVAssetReader` + `AVAssetExportSession` — minimal new detection code, high feature value.

**Delivers:** Per-hold automatic video clips with pre-roll, keep/discard review UI, clips saved to camera roll, and video upload mode for offline analysis of existing footage.

**Features from FEATURES.md:**
- Automatic video capture (pre-roll buffer) per hold
- Post-hold keep/discard review (immediate, per hold)
- Clip saved to camera roll on keep
- Video upload mode (import video, extract holds, keep/discard)

**Architecture components from ARCHITECTURE.md:**
- `Recorder` actor (circular pre-roll buffer + AVAssetWriter)
- `VideoUploadCoordinator` + `VideoFrameReader`
- `ClipReviewView`

**Pitfalls to prevent in this phase:**
- Circular buffer memory blowup → VideoToolbox compression before buffering
- AVAssetWriter initialization latency → eagerly initialize at session start
- Temp file accumulation → cleanup on session end, orphan sweep on launch
- Camera interruption corrupt clips → finishWriting in AVCaptureSessionWasInterruptedNotification handler
- PHPhotoLibrary deprecated API → addOnly access level throughout

**Research flag:** Standard patterns — AVAssetWriter + circular buffer + PHPhotoLibrary are well-documented by Apple and community sources. No phase-level research needed, but implementation requires careful reference to the specific patterns documented in STACK.md and PITFALLS.md.

---

### Phase 3: Robustness + Polish

**Rationale:** After the two core feature phases are working, this phase hardens the app for real-world use: battery and thermal optimization, interruption recovery UX, onboarding, and edge case handling. None of these can be done meaningfully until the core pipeline exists to profile and test against real conditions.

**Delivers:** A shippable-quality app: optimized battery usage, graceful interruption handling, camera angle guidance onboarding, detection confidence debug overlay for power users, and the full "looks done but isn't" checklist from PITFALLS.md verified.

**Features:**
- Vision inference throttling (10-15fps detection; reduce to 5fps during confirmed hold)
- Session preset `.hd1280x720` enforced (not 4K) for Vision pipeline
- Full interruption recovery UX (phone call mid-hold, app background mid-clip)
- Camera angle guidance on first launch
- Clip review queuing (allow user to continue training and review all clips at session end)
- Detection confidence debug overlay (hidden by default, long-press to reveal)
- Battery and thermal profiling with Instruments

**Pitfalls to address in this phase:**
- Battery drain from full-rate inference → throttle validated with Energy gauge
- Camera backgrounding interruption → full recovery UX, not just crash prevention
- Silent failure on bad lighting/angle → low-confidence joint hints to user

**Research flag:** Standard patterns — throttling, interruption handling, and onboarding are all well-documented iOS patterns. No phase-level research needed.

---

### Phase 4: Multi-Skill Expansion (Post-PMF)

**Rationale:** Research explicitly gates this on Phase 1 accuracy validation. The detection quality for handstands must be proven before investing in harder-to-detect skills. The `Hold` schema already includes a `skill` field (designed in Phase 1), so data model changes are minimal. Each new skill is a new `SkillClassifier` file in `Pose/` — the state machine and pipeline architecture accommodate this without structural changes.

**Delivers:** Front Lever, Back Lever, Planche detection (Phase 4a). Human Flag may require separate research — it needs a side-facing camera orientation, which is a different setup from front/rear.

**Dependencies:** Phase 1 handstand detection accuracy validated; user demand from early adopters confirmed.

**Research flag:** NEEDS deeper research during planning — each skill requires its own geometric classifier design and accuracy validation strategy. Human Flag in particular may need architecture-level decisions about camera orientation.

---

### Phase Ordering Rationale

- **Detection before recording:** Recording triggered by detection; cannot build recording without a reliable trigger
- **Detection before history:** Session history only has value if holds are reliably detected and timed
- **Upload mode in Phase 2:** Reuses Phase 1 detection pipeline at no additional detection cost; only adds file I/O and clip trimming
- **Polish after features:** Cannot profile battery drain, thermal behavior, or interruption recovery without a complete pipeline to run
- **Multi-skill after PMF:** Depends on Phase 1 accuracy validation; premature expansion risks compounding accuracy problems

### Research Flags

**Needs `/gsd:research-phase` during planning:**
- **Phase 1 — HandstandClassifier:** Specific joint angle thresholds, confidence weighting for inverted poses, and the labeled test set strategy need a dedicated research step during phase planning
- **Phase 4 — Multi-skill classifiers:** Each skill (Front Lever, Back Lever, Planche, Human Flag) needs its own geometric analysis; Human Flag may require camera orientation decisions

**Standard patterns (skip research-phase during planning):**
- **Phase 1 — Camera + threading architecture:** Well-documented in WWDC sessions and community; CameraActor pattern is established
- **Phase 2 — AVAssetWriter + circular buffer + PHPhotoLibrary:** Apple documentation and community sources provide complete patterns
- **Phase 3 — Throttling + interruption + onboarding:** Standard iOS patterns; no novel integration required

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Entire stack is first-party Apple. WWDC sessions, official documentation, and current community patterns (2024-2025) are consistent. iOS 17+ target eliminates any backcompat complexity. One caveat: Swift 6 + AVFoundation concurrency is an active friction point — patterns are documented but require care. |
| Features | MEDIUM | Competitor analysis is solid; the product gap is confirmed. Specific athlete expectations for the calisthenics niche are extrapolated from adjacent products and community signals rather than direct user research. Feature priority ordering has high confidence; specific user behavior (e.g., clip review queuing preference) needs validation with real users. |
| Architecture | HIGH | Apple WWDC20 + WWDC24 sessions, objc.io, and fatbobman's Swift 6 camera refactoring guide provide authoritative patterns. Actor-per-concern, evidence accumulation, and circular buffer approaches are verified against Apple's own guidance. |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls (inverted pose, threading, buffer memory, AVAssetWriter latency) are confirmed by Apple documentation and multiple community sources. Some severity estimates (e.g., "5-7 second AVAssetWriter initialization") are based on forum reports, not first-party benchmarks — actual latency may vary by device generation. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Handstand classifier angle thresholds:** Research identifies *that* geometric classification works but does not specify exact threshold values for wrist-y < ankle-y margin, body vertical alignment tolerance, or minimum joint confidence cutoffs. These must be determined empirically during Phase 1 implementation and validated against real handstand footage across users and lighting conditions.

- **Detection accuracy floor:** The 80% correct detection threshold cited in PITFALLS.md is a heuristic, not a tested benchmark. The actual acceptable false-positive/false-negative rate for athletes needs to be defined as a concrete acceptance criterion before Phase 1 is considered complete.

- **Pre-roll buffer duration UX:** Research recommends 2-3 seconds of pre-roll. The right value for athletes (enough to capture approach, not so long the clip starts during a previous attempt) needs user validation during Phase 2.

- **Clip review flow:** Research flags that blocking the next attempt on clip review is a UX pitfall and recommends a queued review approach. The exact interaction model (review at session end vs. background queue vs. swipe-to-decide inline) needs a design decision during Phase 2 planning.

- **iOS 17 vs. iOS 18 Vision API target:** STACK.md recommends `VNDetectHumanBodyPoseRequest` (legacy, iOS 14+) for the iOS 17 minimum target, with a mechanical migration path to the new async API when iOS 17 support is dropped. The exact minimum OS version for shipping should be confirmed before Phase 1 begins.

---

## Sources

### Primary (HIGH confidence)
- [Detect Body and Hand Pose with Vision — WWDC20](https://developer.apple.com/videos/play/wwdc2020/10653/) — evidence accumulation pattern, inverted-pose limitation documentation, handler reuse
- [Discover Swift enhancements in the Vision framework — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10163/) — new async API, iOS 18+ requirement, VN prefix removal
- [AVCaptureSession — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avcapturesession) — session configuration, startRunning threading requirement
- [AVAssetWriter — Apple Developer Documentation](https://developer.apple.com/documentation/avfoundation/avassetwriter) — writer lifecycle, expectsMediaDataInRealTime
- [Privacy manifest files — Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — App Store submission requirement since May 2024
- [Swift 6 Refactoring in a Camera App — fatbobman.com](https://fatbobman.com/en/posts/swift6-refactoring-in-a-camera-app/) — CameraActor GlobalActor pattern, nonisolated delegates
- [BlazePose pose.md — Google AI Edge GitHub](https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/pose.md) — hip-midpoint orientation anchor, face-detection-as-proxy (eliminates MediaPipe for this use case)

### Secondary (MEDIUM confidence)
- [Key Considerations Before Using SwiftData — fatbobman.com](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — enum predicate bug, optional relationship requirement, ModelActor iOS 18 issue
- [Capturing Video on iOS — objc.io](https://www.objc.io/issues/23-video/capturing-video/) — AVCaptureSession + AVAssetWriter architecture, threading model
- [Doing it Live at GIPHY with AVFoundation](https://engineering.giphy.com/doing-it-live-at-giphy-with-avfoundation/) — circular buffer + VideoToolbox compression, 10x memory reduction
- [Apple Developer Forums: "Safely use AVCaptureSession + Swift 6.2 Concurrency" — 2025](https://forums.swift.org/t/safely-use-avcapturesession-swift-6-2-concurrency/83622) — active friction documentation
- [Apple Developer Forums: AVCaptureVideoDataOutput buffer pool exhaustion](https://developer.apple.com/forums/thread/679250) — CMSampleBuffer retention pitfall
- [Apple Developer Forums: "When does iOS clear tmp directory"](https://developer.apple.com/forums/thread/680224) — confirms OS does NOT auto-clear tmp
- [VideoFit — videofit.app](https://www.videofit.app/en) — keep/discard workflow validation
- [App Store: Handstand Timer (id1370178499)](https://apps.apple.com/us/app/handstand-timer/id1370178499) — 2.3 stars; false-positive and UX failure analysis

### Tertiary (LOW confidence / needs validation)
- [iOS 18/17 new Camera APIs — Medium/YLabZ](https://zoewave.medium.com/ios-18-17-new-camera-apis-645f7a1e54e8) — API overview; blog post, not verified against official docs
- [MediaPipe for Sports Apps — it-jim.com](https://www.it-jim.com/blog/mediapipe-for-sports-apps/) — inverted-pose orientation instability; inferred from BlazePose architecture, not a controlled test
- Apple Developer Forums: AVAssetWriter 5-7 second initialization latency — forum report, device-generation dependent

---

*Research completed: 2026-03-01*
*Ready for roadmap: yes*
