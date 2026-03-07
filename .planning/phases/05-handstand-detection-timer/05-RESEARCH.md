# Phase 5: Handstand Detection + Timer - Research

**Researched:** 2026-03-07
**Domain:** SwiftUI state machines, Vision pose geometry, AVFoundation frame extraction, AudioToolbox
**Confidence:** HIGH (all core decisions locked; implementation uses first-party Apple APIs verified against existing codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Handstand Classifier**
- Primary criterion: At least 1 wrist AND 1 ankle detected with confidence > 0.2, where wrist Y < ankle Y in Vision normalized space (wrists below ankles = inverted)
- Minimum joints: 1 wrist + 1 ankle (lenient — supports side-on camera angles). Flagged as tunable: this threshold is empirically determined and likely to be adjusted during testing
- Stricter criteria (NOT used): Requiring all 4 joints (both wrists + both ankles) or additional body alignment was rejected in favor of side-on angle support

**Debounce + Accuracy (Hold State Machine)**
- Entry debounce: ~5 consecutive inverted frames required before transitioning searching to timing. Prevents false starts from jump-throughs or kip-up passes.
- Exit debounce: 10-15 consecutive non-inverted frames required before ending a hold. Prevents phantom terminations from single bad frames mid-hold.
- Backdated timing (critical): On frame 1 of inversion, record `potentialStart` timestamp. On confirmed entry (frame ~5), start displaying the timer but set start time = `potentialStart`. Same for exit: record `potentialEnd` on first non-inverted frame; use it as hold end time once exit is confirmed. Measured hold duration is accurate from actual first/last inverted frame, not from when debounce resolves. Timer display may lag ~0.2s behind real start — acceptable.

**Detection State Indicator**
- Location: Top-center in the LiveSessionView ZStack overlay, not blocking the body in frame
- Visual: Icon-only colored dot (no text label) — minimal footprint
  - Grey = searching
  - Ember (brand orange) = detected (pose seen, entry debounce not yet confirmed)
  - Green = timing (hold confirmed, timer running)
- Animation: Dot pulses (gentle breathing animation) during timing state only
- Persistence: Always visible during a session (no auto-hide)
- Toggle: Independently toggleable via the session gear icon (SessionConfigSheet) and the main Settings page — same pattern as skeleton overlay toggle

**Timer Display**
- Location: Top-center, directly below the detection indicator dot — they form a grouped cluster at top of camera overlay
- Format: MM:SS (e.g. `0:12`, `1:04`) — whole seconds, no tenths
- Active hold behavior: Counts up continuously. After target is reached, timer turns green and continues counting (does not stop at target)
- When hold ends: Freezes on the final hold time — persists until the next hold starts, then resets. If no hold has occurred yet, shows `0:00`
- Between holds: Always visible showing the last hold's final time (or `0:00` if none)

**Target Alert**
- Visual alert: Timer text color changes to green when target duration is reached. No flash, no banner — subtle and non-disruptive mid-hold
- Audio alert: System sound (AudioServicesPlaySystemSound short beep) — fires once at target duration. No haptics.
- Post-target behavior: Timer keeps counting past the target. Green color persists for the remainder of the hold.
- Silent mode: System sound respects device silent mode — no sound if silenced (acceptable)

**Upload Mode Output**
- Processing trigger: Automatically starts scanning on video import — no user tap required
- UI during scan: Same detection state dot and timer shown as in live session mode. This doubles as a debug view for validating the classifier against real training footage
- Results list: After scan completes, a scrollable list populates in Zone 3 of UploadModeView (the Phase 3 stability contract area). Each row shows: `[n]. [start time] - [end time] - [duration]` e.g. `1. 0:23 - 0:35 - 12s`
- No video playback during scan: Detection runs at full speed (not real-time playback rate) — scanner seeks through frames independently
- Empty state: If no holds detected, show a message in Zone 3 (e.g. "No handstand holds detected")

### Claude's Discretion
- Exact debounce frame counts within the specified ranges (entry: ~5, exit: 10-15)
- Confidence threshold (0.2 baseline — adjust if false positives/negatives are observed during testing)
- Exact pulse animation parameters (period, scale factor) for the timing-state dot
- System sound ID selection (specific beep from iOS built-in sounds)
- Zone 3 layout details (list row styling, spacing, empty state illustration)

### Deferred Ideas (OUT OF SCOPE)
- Using joint angles (e.g. feet-hips-wrists) in handstand criteria for stricter hold definition. This is something we might implement at a later date if necessary.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DETE-01 | App automatically detects handstand hold via geometric pose classifier (feet above head in normalized coords) — no manual start/stop required | HandstandClassifier reads `DetectedPose.joints` already published by `VisionProcessor.$detectedPose`; wrist Y < ankle Y in Vision's lower-left-origin space encodes inversion |
| DETE-02 | Hold state machine transitions through searching → detected → timing → hold ended with debounce (10-15 frame threshold to prevent phantom holds) | `HoldStateMachine` is a new `@MainActor` class consuming `DetectedPose?`; entry frame counter and exit frame counter drive state transitions; `potentialStart`/`potentialEnd` timestamps enable backdating |
| DETE-03 | Detection state indicator shown on screen with 3 distinct visual states (searching / detected / timing), independently toggleable | New `DetectionIndicatorPreference` (mirrors `SkeletonPreference`); dot view wired to `HoldStateMachine.state`; pulse via `withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true))` |
| DETE-04 | Timer counts up during active hold, visible on screen in real-time | `HoldStateMachine` exposes `displayedElapsed: TimeInterval` driven by `Timer.publish` at 1-second granularity; SwiftUI formats with `formattedElapsed` helper |
| DETE-06 | Visual and haptic alert fires when user-set target hold duration is reached | `AudioServicesPlaySystemSound(1057)` once on elapsed crossing target; `hasAlerted` guard prevents repeat; text color toggled to green in `HoldTimerView` |
| DETE-07 | User can set target hold duration on-the-fly during a session (no pre-session config required) | `SessionConfigSheet` already exposes `targetHoldDurationSeconds` via `@AppStorage`; `onConfirm` closure already plumbed to `LiveSessionView`; Phase 5 passes value to state machine |
| VIDU-02 | Detection pipeline runs against imported video and identifies holds with timestamps | Upload mode uses `AVAssetReader` (faster-than-realtime sequential read) feeding `VisionProcessor.process()`; same `HoldStateMachine` accumulates holds; results list rendered in Zone 3 of `UploadModeView` |
</phase_requirements>

---

## Summary

Phase 5 is entirely first-party Apple (Vision, AVFoundation, AudioToolbox, SwiftUI) with zero new external dependencies. The hard part is not technology selection — it is correctness in the state machine: backdated timestamps, debounce symmetry, and the upload mode scan pipeline running at full-speed without interfering with the existing periodic AVPlayerItemVideoOutput observer.

The codebase enters Phase 5 with `VisionProcessor` already publishing `DetectedPose?` on `@MainActor`, `SkeletonPreference` establishing the UserDefaults-toggle pattern, `SessionConfigSheet` already holding `targetHoldDurationSeconds`, and `UploadModeView.Zone 3` reserved as a stability contract. Phase 5 wires these together with three new artifacts: `HandstandClassifier` (pure function), `HoldStateMachine` (`@MainActor` ObservableObject), and an `AVAssetReaderScanner` (background task, replaces the AVPlayerItemVideoOutput observer for upload mode scan).

The most significant architectural decision for upload mode is switching from the Phase 4 `AVPlayerItemVideoOutput` periodic observer (which only fires at realtime playback rate, and only when playing) to `AVAssetReader.copyNextSampleBuffer()` in a background `Task`, which reads frames as fast as the decoder allows — typically 5-30x realtime on modern iPhones. This makes upload scanning practical on long videos and avoids having to play the video to scan it.

**Primary recommendation:** Build in four sequential units — (1) `HandstandClassifier` + `HoldStateMachine`, (2) `HoldIndicatorView` + `HoldTimerView` wired into `LiveSessionView`, (3) target alert (`AudioServicesPlaySystemSound`), (4) upload mode `AVAssetReaderScanner` + results list.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vision (`VNHumanBodyPoseObservation`) | iOS 14+ | Joint coordinate source | Already integrated in `VisionProcessor`; provides `leftWrist`, `rightWrist`, `leftAnkle`, `rightAnkle` with normalized coords |
| AudioToolbox (`AudioServicesPlaySystemSound`) | All iOS | One-shot system beep for target alert | Zero setup, respects silent mode, no AVAudioSession category changes needed |
| SwiftUI `Timer.publish` | All iOS | 1 Hz UI clock for elapsed display | `@MainActor`-safe via `.receive(on: RunLoop.main)`; `onReceive` integrates cleanly with existing patterns |
| AVFoundation `AVAssetReader` | iOS 4+ | Full-speed frame extraction for upload scan | Sequential `copyNextSampleBuffer()` runs faster-than-realtime; AVPlayer periodic observer is realtime-rate only |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `withAnimation(.easeInOut.repeatForever)` | SwiftUI | Breathing pulse on timing-state dot | Applied only when `state == .timing`; toggled via `isAnimating` `@State` flag |
| `UserDefaults` via `@AppStorage` | All iOS | Detection indicator toggle persistence | Same pattern as `SkeletonPreference`; new `DetectionIndicatorPreference` class |
| `Date()` / `TimeInterval` | Foundation | Hold timestamps and elapsed calculation | Used in `HoldStateMachine` for `potentialStart`, `confirmedStart`, `potentialEnd` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `AVAssetReader` for upload scan | Keep AVPlayerItemVideoOutput + playback | AVPlayerItemVideoOutput requires the video to be playing at 1x speed, making a 3-minute video take 3 minutes to scan. AVAssetReader reads sequentially at decoder speed — dramatically faster |
| `Timer.publish` for elapsed | `CADisplayLink` | CADisplayLink gives 60Hz precision but timer displays whole seconds only; Timer at 1Hz is sufficient and simpler under Swift 6 MainActor isolation |
| `AudioServicesPlaySystemSound` | `AVAudioPlayer` | AVAudioPlayer requires file loading and AVAudioSession management; system sound fires in one line with no state |

**Installation:** No new packages. All APIs are first-party frameworks already linked in the project.

---

## Architecture Patterns

### Recommended Project Structure (new files this phase)

```
CaliTimer/
├── Vision/
│   ├── VisionProcessor.swift          # existing — no changes
│   ├── SkeletonPreference.swift       # existing — no changes
│   ├── HandstandClassifier.swift      # NEW: pure static func, no state
│   ├── HoldStateMachine.swift         # NEW: @MainActor ObservableObject
│   └── DetectionIndicatorPreference.swift  # NEW: mirrors SkeletonPreference
├── Upload/
│   ├── VideoImportManager.swift       # existing — add scan trigger hook
│   └── AVAssetReaderScanner.swift     # NEW: background Task, publishes hold list
├── UI/
│   ├── LiveSession/
│   │   ├── LiveSessionView.swift      # modified — add state machine + overlay
│   │   ├── SessionConfigSheet.swift   # modified — add indicator toggle row
│   │   ├── HoldIndicatorView.swift    # NEW: colored dot with pulse
│   │   └── HoldTimerView.swift        # NEW: MM:SS text, color changes
│   ├── Upload/
│   │   └── UploadModeView.swift       # modified — add scanner + results list
│   └── Settings/
│       └── SettingsView.swift         # modified — add indicator toggle
```

### Pattern 1: HandstandClassifier — Pure Static Classifier

**What:** A struct or enum with a single `static func isHandstand(_ pose: DetectedPose?) -> Bool` that has no state and no side effects. Receives the published `DetectedPose?` value.

**When to use:** Called on every frame from `HoldStateMachine.process(pose:)`. Pure function enables unit testing without mocking.

**Example:**
```swift
// HandstandClassifier.swift
enum HandstandClassifier {
    // Vision normalized space: (0,0)=bottom-left, (1,1)=top-right
    // In a handstand, wrists are near the floor (low Y) and ankles near top (high Y).
    // So: wristY < ankleY == inverted == handstand.
    static func isHandstand(_ pose: DetectedPose?) -> Bool {
        guard let joints = pose?.joints else { return false }
        // Require at least 1 wrist + 1 ankle (lenient for side-on angles)
        let wristKeys = ["left_wrist_joint", "right_wrist_joint"]
        let ankleKeys = ["left_ankle_joint", "right_ankle_joint"]
        let wristY = wristKeys.compactMap { joints[$0]?.y }.min()
        let ankleY = ankleKeys.compactMap { joints[$0]?.y }.max()
        guard let wy = wristY, let ay = ankleY else { return false }
        return wy < ay   // wrist below ankle in Vision space = inverted
    }
}
```

**Critical note on joint key strings:** `VisionProcessor` stores joints using `jointName.rawValue.rawValue` — a double `.rawValue` call because `VNHumanBodyPoseObservation.JointName` is a struct wrapping a `VNRecognizedPointKey` (which itself is a struct wrapping a String). The actual strings are like `"left_wrist_2_joint"`, `"right_wrist_2_joint"`, `"left_ankle_joint"`, `"right_ankle_joint"`. **These must be verified at integration time by printing the actual keys from a live `DetectedPose`.** Do not hard-code assumed strings.

### Pattern 2: HoldStateMachine — @MainActor State Machine

**What:** `@MainActor final class HoldStateMachine: ObservableObject` with a 4-state enum and frame counters. Consumes `DetectedPose?` via `process(pose:)`, publishes `state`, `displayedElapsed`, `lastHoldDuration`, and `completedHolds`.

**State enum:**
```swift
enum HoldState: Equatable {
    case searching
    case detected    // debouncing entry
    case timing      // hold confirmed
    case ended       // hold just ended (briefly, then back to searching)
}
```

**Backdated timestamp logic:**
```swift
// On first inverted frame:
if potentialStart == nil { potentialStart = Date() }
entryFrameCount += 1

// On reaching entry threshold (e.g. 5 frames):
confirmedStart = potentialStart   // timer display uses confirmedStart, not now
state = .timing

// On first non-inverted frame while timing:
if potentialEnd == nil { potentialEnd = Date() }
exitFrameCount += 1

// On reaching exit threshold (e.g. 12 frames):
let holdDuration = potentialEnd!.timeIntervalSince(confirmedStart!)
completedHolds.append(HoldRecord(start: confirmedStart!, end: potentialEnd!, duration: holdDuration))
lastHoldDuration = holdDuration
reset to searching state
```

**Timer clock (elapsed display):**
```swift
// In LiveSessionView/UploadModeView body — or in HoldStateMachine using Combine:
// Subscribe to Timer.publish only while state == .timing.
// displayedElapsed = max(0, Date().timeIntervalSince(confirmedStart))
// Format: "\(Int(displayedElapsed) / 60):\(String(format: "%02d", Int(displayedElapsed) % 60))"
```

**Target alert guard:**
```swift
// On each timer tick while .timing:
if let target = targetDuration, !hasAlerted,
   displayedElapsed >= target {
    AudioServicesPlaySystemSound(1057)  // "Tink" — short, clean
    hasAlerted = true
}
// Reset hasAlerted when entering new hold.
```

### Pattern 3: DetectionIndicatorPreference — Toggle (mirrors SkeletonPreference)

```swift
// DetectionIndicatorPreference.swift
@MainActor
final class DetectionIndicatorPreference: ObservableObject {
    private static let defaultsKey = "detectionIndicatorEnabled"
    @Published var isEnabled: Bool
    // ... same init + Combine sink pattern as SkeletonPreference
}
```

Add a toggle row to `SessionConfigSheet` (same `HStack` pattern as Skeleton Overlay row).
Add the same toggle to `SettingsView`.

### Pattern 4: HoldIndicatorView — Dot with Pulse

```swift
// HoldIndicatorView.swift
struct HoldIndicatorView: View {
    let state: HoldState
    @State private var isAnimating = false

    var dotColor: Color {
        switch state {
        case .searching: return Color(hex: 0x888888)       // grey
        case .detected:  return Color.brandEmber            // ember orange
        case .timing, .ended: return Color.green
        }
    }

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
            .scaleEffect(isAnimating ? 1.4 : 1.0)
            .opacity(isAnimating ? 0.7 : 1.0)
            .animation(
                state == .timing
                    ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                    : .default,
                value: isAnimating
            )
            .onChange(of: state) { _, newState in
                isAnimating = (newState == .timing)
            }
            .onAppear {
                isAnimating = (state == .timing)
            }
    }
}
```

### Pattern 5: AVAssetReaderScanner — Full-Speed Upload Scan

**What:** A background `Task` that uses `AVAssetReader` to read all video frames sequentially at decoder speed (faster-than-realtime), sending each `CMSampleBuffer` to `VisionProcessor.process()`, running the same `HoldStateMachine`. When complete, publishes the hold list.

**Why not keep the existing AVPlayerItemVideoOutput approach:** The Phase 4 periodic observer fires every 33ms at realtime playback rate. A 5-minute video would take 5 real minutes to scan. `AVAssetReader` reads as fast as the decoder allows — typically 5-30x realtime on modern iPhones.

**Key setup:**
```swift
// In AVAssetReaderScanner (or inside VideoImportManager):
let asset = AVURLAsset(url: videoURL)
let reader = try AVAssetReader(asset: asset)
let track = try await asset.loadTracks(withMediaType: .video).first!
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
])
reader.add(output)
reader.startReading()

// Read loop — runs on Task.detached or background actor
while reader.status == .reading {
    guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    visionProcessor.process(sampleBuffer: sampleBuffer, orientation: pixelOrientation)
    // HoldStateMachine.process() is called via the $detectedPose publisher
    // OR pass CMTime pts into HoldStateMachine so hold timestamps are video-time, not wall-clock
}
```

**Timestamp semantics for upload mode:** In live mode, hold timestamps are wall-clock `Date()`. In upload mode, they must be video timestamps (`CMTime` converted to seconds from video start) so the results list shows meaningful `0:23 - 0:35` times. The `HoldStateMachine` needs a `videoTimestamp: CMTime?` parameter on `process(pose:videoTime:)` — or the scanner passes `CMTime` directly and builds `HoldRecord` without routing through `HoldStateMachine`'s wall-clock path.

**Recommended approach:** Give `HoldStateMachine` a `currentFrameTime: CMTime?` property that the scanner sets on each frame before calling `process(pose:)`. State machine uses `currentFrameTime` (upload mode) or `Date()` (live mode) for all timestamp recording.

### Anti-Patterns to Avoid

- **Don't use `AVPlayerItemVideoOutput` for upload scanning.** It is realtime-rate only; a 3-minute video takes 3 real minutes.
- **Don't start the timer display from confirmed-entry time.** The display must backdate to `potentialStart` — otherwise measured hold duration is 0.2-0.5s shorter than actual.
- **Don't fire `AudioServicesPlaySystemSound` on every Timer tick.** Guard with `hasAlerted: Bool` that resets only at start of each new hold.
- **Don't use `@CameraActor` for `HoldStateMachine`.** CLAUDE.md preference: use `@MainActor`. State machine receives already-bridged `DetectedPose` on MainActor; no camera-queue work needed.
- **Don't embed business logic in SwiftUI views.** `HandstandClassifier` and `HoldStateMachine` are testable Swift types; views only read published state.
- **Don't hard-code joint key strings without verification.** The double `.rawValue` in `VisionProcessor` produces the actual Vision string keys — print them in a debug build first.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Short beep sound | Custom AVAudioPlayer + audio file | `AudioServicesPlaySystemSound(1057)` | One line, no file bundling, no session config, respects silent mode |
| Repeating animation | Manual Timer + state toggling | SwiftUI `withAnimation(.repeatForever)` on `scaleEffect` + `opacity` | Declarative, auto-cancelled when view disappears |
| Elapsed display clock | CADisplayLink at 60Hz | `Timer.publish(every: 1.0, ...)` with `onReceive` | Display resolution is whole seconds; 1Hz is sufficient; clean MainActor integration |
| Video frame iteration | Custom seek-based random access | `AVAssetReader.copyNextSampleBuffer()` loop | Sequential read is the intended pattern; random access with AVAssetReader is not supported |

---

## Common Pitfalls

### Pitfall 1: Vision Joint Key String Mismatch

**What goes wrong:** `HandstandClassifier` uses assumed key strings like `"left_wrist"`, but `VisionProcessor` stores them as `jointName.rawValue.rawValue` which produces strings like `"left_wrist_2_joint"`. The classifier always returns `false` because no keys match.

**Why it happens:** `VNHumanBodyPoseObservation.JointName` wraps a `VNRecognizedPointKey` which wraps a String — `.rawValue` on `JointName` gives `VNRecognizedPointKey`, and `.rawValue` on that gives the underlying String. The nesting is non-obvious.

**How to avoid:** On first integration, add a `print(detectedPose?.joints.keys)` log to `LiveSessionView.onReceive` and confirm actual strings before writing `HandstandClassifier`. The verified strings from the existing codebase's 8 joints are what `HandstandClassifier` must use.

**Warning signs:** Classifier always returns `false`, detection indicator stays grey even when standing in front of camera with skeleton visible.

### Pitfall 2: Upload Mode Hold Timestamps Are Wall-Clock Instead of Video-Time

**What goes wrong:** `HoldStateMachine` uses `Date()` for timestamps. In upload mode, holds get wall-clock times (e.g. `2026-03-07T14:23:41`) instead of video-time offsets (e.g. `0:23`). The results list shows nonsensical timestamps.

**Why it happens:** State machine was designed for live mode (wall-clock). Upload mode requires video-timeline offsets derived from `CMSampleBufferGetPresentationTimeStamp`.

**How to avoid:** Pass `CMTime?` as an optional parameter to `HoldStateMachine.process(pose:videoTime:)`. When non-nil (upload mode), use it for hold start/end timestamps. When nil (live mode), use `Date()`.

**Warning signs:** Results list shows hold durations as correct but start times are wrong; or start times count from an unexpected epoch.

### Pitfall 3: Entry Debounce Resets When Vision Drops a Frame

**What goes wrong:** During the entry debounce window, Vision occasionally returns `nil` for one frame (occlusion, motion blur). The frame counter resets to 0, extending entry debounce indefinitely.

**Why it happens:** Naive implementation: `if !isHandstand { entryFrameCount = 0 }` treats nil as a non-handstand frame.

**How to avoid:** During `.detected` state, only reset on consecutive non-inverted frames using the exit debounce counter. A single nil frame should not cancel entry debounce. Option: treat nil pose as non-inverted only if N consecutive frames are nil (use same exit debounce logic for both nil and explicit non-inverted).

**Warning signs:** Detection indicator flickers between grey and orange, never reaching green.

### Pitfall 4: Timer.publish Continues After Hold Ends

**What goes wrong:** `Timer.publish` subscription is active outside of `.timing` state, causing unnecessary CPU wake-ups and potential `displayedElapsed` drift.

**Why it happens:** SwiftUI's `onReceive(Timer.publish(...))` starts immediately and doesn't auto-cancel when state changes.

**How to avoid:** Use `.onReceive` conditioned on state, OR cancel/restart the Combine timer subscription when state transitions. Alternatively, compute elapsed as `Date().timeIntervalSince(confirmedStart)` on each tick and only display it when in `.timing` state — the timer keeps firing but the value doesn't affect display.

### Pitfall 5: AVAssetReader Scan Blocks MainActor

**What goes wrong:** `AVAssetReader` read loop runs on `@MainActor`, blocking the UI completely during video scan.

**Why it happens:** Caller runs scanner in a `Task` without `Task.detached` or a background actor.

**How to avoid:** Run the `AVAssetReader` read loop in `Task.detached { }` or on a `nonisolated` method. Bridge back to MainActor only for `HoldStateMachine.process()` calls and UI updates. The existing `VisionProcessor.process()` is already `nonisolated`, matching this pattern.

### Pitfall 6: Zone 3 Outer Layout Changes Break Phase 3 Contract

**What goes wrong:** Adding the holds results list requires restructuring `UploadModeView`'s outer ZStack, breaking the Phase 3 stability contract.

**Why it happens:** New content is added outside Zone 3's designated area.

**How to avoid:** Zone 3 is the outer ZStack's inner content only — the Phase 3 contract says inner content in Zone 3 is replaced, outer layout must not change. The holds list and "no holds" empty state slot entirely inside Zone 3 without touching the ZStack structure or toolbar.

---

## Code Examples

Verified patterns from existing codebase and official sources:

### SkeletonPreference Pattern (template for DetectionIndicatorPreference)
```swift
// Source: CaliTimer/Vision/SkeletonPreference.swift (existing)
@MainActor
final class DetectionIndicatorPreference: ObservableObject {
    private static let defaultsKey = "detectionIndicatorEnabled"
    @Published var isEnabled: Bool
    private var cancellable: AnyCancellable?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.defaultsKey) != nil {
            self.isEnabled = defaults.bool(forKey: Self.defaultsKey)
        } else {
            self.isEnabled = true
            defaults.set(true, forKey: Self.defaultsKey)
        }
        cancellable = $isEnabled.sink { newValue in
            UserDefaults.standard.set(newValue, forKey: Self.defaultsKey)
        }
    }
}
```

### AudioServicesPlaySystemSound
```swift
// Source: Apple AudioToolbox documentation
import AudioToolbox
AudioServicesPlaySystemSound(1057)   // "Tink" — short, clean tap sound
// Alternative: 1322 (SMS received tone — slightly longer)
// Respects device silent switch. No setup required.
```

### SwiftUI Breathing Pulse
```swift
// Source: SwiftUI withAnimation repeatForever pattern (verified community 2025)
// Applied to HoldIndicatorView dot during .timing state only
Circle()
    .fill(dotColor)
    .frame(width: 10, height: 10)
    .scaleEffect(isAnimating ? 1.35 : 1.0)
    .opacity(isAnimating ? 0.7 : 1.0)
    .animation(
        isAnimating
            ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            : .default,
        value: isAnimating
    )
```

### MM:SS Formatting
```swift
// Pure Swift — no import needed
func formattedElapsed(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds))
    return "\(s / 60):\(String(format: "%02d", s % 60))"
}
// Produces: "0:00", "0:12", "1:04", "10:30"
```

### AVAssetReader Sequential Read Loop
```swift
// Source: Apple AVFoundation documentation — AVAssetReader
// Run inside Task.detached or nonisolated context
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(
    track: videoTrack,
    outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String:
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    ]
)
reader.add(output)
reader.startReading()

while reader.status == .reading {
    guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    // process() is nonisolated — safe to call here
    visionProcessor.process(sampleBuffer: sampleBuffer, orientation: pixelOrientation)
    // Bridge pts to MainActor for state machine
    await MainActor.run {
        holdStateMachine.setCurrentVideoTime(pts)
    }
}
```

### VisionProcessor.process Integration Point (live mode)
```swift
// Source: CaliTimer/UI/LiveSession/LiveSessionView.swift (existing)
.onReceive(cameraManager.visionProcessor.$detectedPose) { pose in
    // existing skeleton code ...
    holdStateMachine.process(pose: pose)  // ADD this line
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-frame `VNSequenceRequestHandler` creation | Single handler reused per session | Phase 4 | Prevents jitter, reduces CPU |
| `AVPlayerItemVideoOutput` for upload scanning | `AVAssetReader` sequential loop | Phase 5 (new) | 5-30x faster than realtime playback |
| Random `Date()` for all timestamps | `potentialStart` / `potentialEnd` backdating | Phase 5 (new) | Hold duration accuracy from first/last inverted frame |

**Deprecated/outdated:**
- Realtime-rate upload scanning via `AVPlayerItemVideoOutput`: acceptable for skeleton overlay display (Phase 4) but not for batch scan (Phase 5)

---

## Open Questions

1. **Exact Vision joint key strings for wrist and ankle**
   - What we know: `VisionProcessor` uses `jointName.rawValue.rawValue` — double unwrap of `VNHumanBodyPoseObservation.JointName`
   - What's unclear: The exact strings without running the code. Likely `"left_wrist_2_joint"`, `"right_wrist_2_joint"`, `"left_ankle_joint"`, `"right_ankle_joint"` based on Vision framework internals, but must be confirmed
   - Recommendation: Wave 0 task — add a debug print in `LiveSessionView.onReceive` or in `HandstandClassifier` itself; confirm before any classifier logic ships

2. **AVAssetReader threading model under Swift 6 strict concurrency**
   - What we know: `AVAssetReader` is not `Sendable`; must be confined to a single context
   - What's unclear: Whether `Task.detached` or a `nonisolated` func on `VideoImportManager` is the cleanest approach under Swift 6
   - Recommendation: Follow the existing `VisionProcessor.process()` pattern — `nonisolated` method that creates and runs the reader, bridges results back via `Task { @MainActor in ... }`

3. **Upload mode HoldStateMachine instance — shared or separate**
   - What we know: Live mode and upload mode each have their own `VisionProcessor` instance (one per `CameraManager`, one per `VideoImportManager`)
   - What's unclear: Whether `HoldStateMachine` should be one shared instance or two independent instances
   - Recommendation: Two independent instances (one per mode) — they run at different times and accumulate different hold lists. Upload mode machine is reset each time a new video is scanned.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None installed — no test target exists in project |
| Config file | None — see Wave 0 |
| Quick run command | N/A — see Wave 0 |
| Full suite command | N/A — see Wave 0 |

**Note:** The project has no test target as of Phase 4 completion. Phase 5 business logic (`HandstandClassifier`, `HoldStateMachine`) is structured as pure Swift types specifically to enable unit testing. Wave 0 should evaluate whether adding an XCTest target is worth the Xcode project configuration cost given the project's device-validation-first approach (see STATE.md: "Phase 5 identified as center of gravity requiring robust manual testing").

Given the project's established validation pattern of manual device testing (all 4 phases verified on physical device), and the fact that `HandstandClassifier` is a pure function easily verified by running the app against known-good training footage in upload mode, the most pragmatic Wave 0 decision is to defer XCTest infrastructure to a future phase and rely on upload mode as the classifier's test harness — as explicitly noted in CONTEXT.md: "Upload mode is intentionally used for testing and debugging the classifier."

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DETE-01 | Handstand detected when wristY < ankleY in Vision space | Manual (device) — upload mode scan against known handstand footage | N/A | N/A |
| DETE-02 | State machine transitions correctly; debounce prevents phantom holds | Manual (device) — live session + deliberate false-start movements | N/A | N/A |
| DETE-03 | Indicator shows 3 states; toggle hides/shows it | Manual (device) — visual inspection + gear sheet toggle | N/A | N/A |
| DETE-04 | Timer counts up during hold, freezes on end | Manual (device) — time 10s hold, verify display | N/A | N/A |
| DETE-06 | Beep fires once at target, not repeatedly | Manual (device) — set target, hold past it | N/A | N/A |
| DETE-07 | Target changed mid-session takes effect immediately | Manual (device) — open gear sheet during active session | N/A | N/A |
| VIDU-02 | Upload scan produces correct hold list with timestamps | Manual (device) — import video with known holds; compare results list | N/A | N/A |

### Sampling Rate
- **Per task commit:** Build + launch on simulator; verify no crash, state indicator visible
- **Per wave merge:** Full device test session covering all 7 requirements above
- **Phase gate:** All 7 manual test cases pass on physical device before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] No XCTest target — decision: defer automated tests; use upload mode as classifier test harness
- [ ] Confirm Vision joint key strings via debug print before Wave 1 classifier implementation

*(If adding XCTest: `xcodegen generate` after adding test target to `project.yml`; no CocoaPods or SPM setup needed)*

---

## Sources

### Primary (HIGH confidence)
- Existing codebase: `VisionProcessor.swift`, `SkeletonPreference.swift`, `LiveSessionView.swift`, `UploadModeView.swift`, `VideoImportManager.swift`, `SessionConfigSheet.swift` — direct code inspection
- Apple AVFoundation documentation (AVAssetReader) — sequential read pattern confirmed
- Apple AudioToolbox documentation (AudioServicesPlaySystemSound) — one-liner system sound API

### Secondary (MEDIUM confidence)
- WebSearch: SwiftUI `withAnimation(.repeatForever)` breathing pulse — multiple consistent sources (Hacking with Swift, Sarunw, Apple Dev Forums) confirming the `.scaleEffect` + `.opacity` + `.repeatForever(autoreverses: true)` pattern
- WebSearch: `AudioServicesPlaySystemSound(1057)` — "Tink" system sound; confirmed across iOSSystemSoundsLibrary (GitHub), community articles
- WebSearch: `AVAssetReader` sequential frame extraction — confirmed by Apple Dev Forums and official documentation as the intended faster-than-realtime approach

### Tertiary (LOW confidence)
- Assumed Vision joint key strings (e.g. `"left_wrist_2_joint"`) — not verified by running code; MUST be confirmed in Wave 0

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies; all APIs in existing codebase or first-party frameworks
- Architecture: HIGH — locked decisions from CONTEXT.md; patterns mirror existing Phase 4 work
- Pitfall: HIGH — joint key mismatch and backdated timestamp pitfalls identified from direct codebase inspection; AVAssetReader threading from official docs
- Upload scan approach: HIGH — AVAssetReader sequential read is the documented intended use; realtime-rate limitation of AVPlayerItemVideoOutput confirmed

**Research date:** 2026-03-07
**Valid until:** 2026-06-07 (stable Apple first-party APIs; Vision joint name strings may change only on major iOS version)
