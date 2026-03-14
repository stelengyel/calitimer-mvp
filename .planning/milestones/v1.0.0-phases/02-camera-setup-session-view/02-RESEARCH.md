# Phase 2: Camera Setup + Session View — Research

**Researched:** 2026-03-02
**Domain:** AVFoundation camera capture, SwiftUI/UIKit bridging, session management, SwiftData
**Confidence:** HIGH (core patterns verified via Apple docs and authoritative community sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Camera Layout**
- Full-bleed camera feed — camera takes the entire screen edge-to-edge
- Controls overlaid on top of feed (not below in a panel)
- Front/rear flip button: top-right corner (matches iOS Camera app convention)
- End Session button: bottom-left, smaller (less prominent, reduces accidental taps)
- Minimal chrome: only flip button and End Session visible during active session — nothing else overlaid until Phase 5 adds detection UI

**Phone Orientation**
- Whole app locked to portrait only
- No per-screen orientation logic needed — single system-wide lock

**Session Start Flow**
- Camera feed is live immediately on screen arrival (no extra tap to activate camera)
- Pre-session config sheet appears from the Home screen's "Start Session" button:
  - Sheet contains: skill picker (Phase 2 = Handstand only) + optional target hold time
  - Athlete taps Go → navigates to live session screen
- Mid-session config: gear icon overlaid on camera feed reopens same sheet
  - Changes apply immediately without ending the session
- Skill picker: Handstand only in Phase 2 — no placeholder slots for future skills
- Session `@Model` record created on session start (when athlete taps Go from the sheet)

**Permission UX**
- Camera permission: system dialog only, triggered automatically when the camera activates on session screen arrival (no custom pre-prompt)
- Permission denied state: inline message within the camera area with an "Open Settings" deep-link button to app settings — no full-screen takeover

### Claude's Discretion
- Exact styling of overlaid controls (opacity, blur, button shape)
- AVCaptureSession configuration details
- Session model properties needed for Phase 2 (minimum viable — Phase 6 fills out the full schema)
- Camera preview aspect ratio handling (fill vs fit for portrait mode)

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CAMR-01 | App works with front and rear camera (user selects during session) | AVCaptureDevice.DiscoverySession + removeInput/addInput pattern; camera flip during active session documented |
| CAMR-02 | App functions with phone propped on a stand without user holding it | Portrait lock already in project.yml + Info.plist; full-bleed preview with overlaid controls satisfies hands-free use |
| SESS-01 | User can start and end an explicit training session | Pre-session sheet → navigate to LiveSessionView; AppCoordinator.popToRoot() for end; Session @Model created on Go |
| SESS-02 | All holds detected during a session are grouped under that session | Session @Model with startedAt date established in Phase 2; hold grouping relationship added later but parent ID available from session start |
</phase_requirements>

---

## Summary

Phase 2 introduces live camera capture into the app shell built in Phase 1. The work has three independent technical pillars: (1) AVFoundation capture session with UIViewRepresentable camera preview, (2) pre-session config sheet wired into HomeView and mid-session via gear icon, and (3) Session @Model bootstrapped with minimum viable properties.

The critical architectural decision — already established in STATE.md — is that all AVFoundation work must live on a `@CameraActor` global actor with a serial GCD queue as the camera thread. This is non-negotiable for Swift 6 strict concurrency compliance and cannot be retrofitted later. Phase 2 must establish this actor boundary correctly even though no frame processing happens yet; the capture session lifecycle (start/stop/camera switch) all runs on it.

The good news for planning: portrait orientation is already locked at the Info.plist and project.yml level (`UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]`), so no per-view orientation code is needed. The only missing plist entry for this phase is `NSCameraUsageDescription`.

**Primary recommendation:** Build `CameraActor` as a `@globalActor`-isolated class owning `AVCaptureSession`, with `AVCaptureVideoPreviewLayer` exposed through a `UIViewRepresentable`. Keep it completely decoupled from SwiftUI view state — pass only a preview layer reference into the `UIViewRepresentable`, and expose a `@Published`-equivalent `@Observable` property for camera permission state.

---

## Standard Stack

### Core

| Component | Version/API | Purpose | Why Standard |
|-----------|------------|---------|--------------|
| `AVCaptureSession` | AVFoundation (iOS 17+) | Manages real-time capture pipeline | Only first-party API for live camera; zero dependencies |
| `AVCaptureDevice` | AVFoundation | Represents physical camera (front/rear) | Required for device selection and input creation |
| `AVCaptureDeviceInput` | AVFoundation | Wraps device into session input | Standard session input type for camera |
| `AVCaptureVideoPreviewLayer` | AVFoundation | Renders live camera feed as Core Animation layer | Lowest-latency preview; no frame copying |
| `UIViewRepresentable` | SwiftUI | Bridges UIView (holding preview layer) into SwiftUI | SwiftUI has no native camera view; UIKit bridge is the standard |
| `@globalActor CameraActor` | Swift Concurrency | Isolates all AVFoundation calls to serial actor | Required for Swift 6 strict concurrency; established in STATE.md |
| `SwiftData @Model Session` | SwiftData (iOS 17+) | Persists session record | Already scaffolded; matches project-wide persistence choice |
| `@AppStorage` | SwiftUI | Persists target hold time preference between sessions | Correct tier for simple scalar preference; SwiftData is overkill here |

### Supporting

| Component | Version/API | Purpose | When to Use |
|-----------|------------|---------|-------------|
| `DispatchQueue` (serial) | Foundation | Camera actor's underlying thread | AVFoundation delegate callbacks require a queue; actor wraps it |
| `AVCaptureDevice.DiscoverySession` | AVFoundation | Enumerate available cameras | Used at session init and on camera flip |
| `beginConfiguration()` / `commitConfiguration()` | AVFoundation | Atomic session reconfiguration | Required when swapping inputs (camera flip) |
| `AVCaptureDevice.requestAccess(for:)` | AVFoundation (async) | Request camera permission | Use `await` form; returns Bool |
| `AVCaptureDevice.authorizationStatus(for:)` | AVFoundation | Check permission without prompting | Check before starting session |
| `UIApplication.open(_:)` | UIKit | Deep-link to app Settings for denied permission | Standard pattern for Settings redirect |

### Alternatives Considered

| Standard Choice | Alternative | Why Standard Wins |
|-----------------|------------|-------------------|
| `AVCaptureVideoPreviewLayer` UIViewRepresentable | `Image` from `CMSampleBuffer` stream | Preview layer has zero-copy hardware path; frame-based approach adds latency and CPU; preview layer is the correct tool for a viewfinder |
| `@globalActor CameraActor` | `@MainActor` camera class | startRunning() is blocking; calling it on MainActor blocks UI; GlobalActor with its own serial queue is correct |
| `@AppStorage` for target hold time | SwiftData @Model | Target hold time is a scalar preference, not a relational record; @AppStorage / UserDefaults is the right persistence tier |

**No external packages.** Project is first-party Apple stack only (confirmed in STATE.md).

---

## Architecture Patterns

### Recommended File Structure for Phase 2

```
CaliTimer/
├── Camera/
│   ├── CameraActor.swift          # @globalActor definition
│   └── CameraManager.swift        # @CameraActor class owning AVCaptureSession
├── UI/
│   ├── LiveSession/
│   │   ├── LiveSessionView.swift      # Existing — restructured to ZStack full-bleed
│   │   ├── CameraPreviewView.swift    # UIViewRepresentable wrapping PreviewView
│   │   └── SessionConfigSheet.swift   # .sheet content — skill picker + target time
│   └── Home/
│       └── HomeView.swift             # Existing — "Start Session" opens sheet, not navigates
├── Storage/
│   └── Models/
│       └── Session.swift              # Add startedAt, skill, targetDuration
```

### Pattern 1: CameraActor (Global Actor)

**What:** A `@globalActor` Swift actor that serializes all AVFoundation work on its own thread. The `CameraManager` class is isolated to this actor.

**When to use:** Any AVFoundation call — `startRunning`, `stopRunning`, `beginConfiguration`, `commitConfiguration`, camera flip, delegate callbacks.

```swift
// Source: STATE.md (established decision) + fatbobman.com Swift 6 camera refactoring article
@globalActor
actor CameraActor: GlobalActor {
    static let shared = CameraActor()
}

@CameraActor
final class CameraManager: NSObject {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.calitimer.camera.session", qos: .userInteractive)
    private var currentInput: AVCaptureDeviceInput?

    // AVCaptureVideoPreviewLayer exposed for UIViewRepresentable
    let previewLayer: AVCaptureVideoPreviewLayer

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        super.init()
    }
}
```

**Key insight:** The `previewLayer` is initialized in `init()` and passed to the `UIViewRepresentable`. The preview layer maintains its own connection to the session — no frame data crosses thread boundaries for the viewfinder.

### Pattern 2: UIViewRepresentable Camera Preview

**What:** A SwiftUI view wrapping a `UIView` subclass whose `layerClass` is `AVCaptureVideoPreviewLayer`. This is the lowest-latency approach — the layer renders directly from the hardware capture pipeline.

**When to use:** Always for the viewfinder. Never use a frame-based approach (copying `CMSampleBuffer` → `CGImage` → SwiftUI `Image`) for preview — that path is for frame analysis (Vision), not display.

```swift
// Source: Verified pattern from neuralception.com + multiple 2024-2025 sources
final class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        // Connect the session's preview layer to the view's layer
        // Must happen on the view's layer, not replace it
        view.previewLayer.session = previewLayer.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Frame updates handled by Auto Layout / SwiftUI layout engine
    }
}
```

**Alternative approach** (simpler, avoids dual-layer confusion): Pass `AVCaptureSession` directly instead of `AVCaptureVideoPreviewLayer`, and assign it in `makeUIView`. Either works; the direct session assignment is cleaner.

### Pattern 3: Camera Permission Check + Session Start on View Appear

**What:** Check permission status in `task {}` on `LiveSessionView` appearance. If `.authorized`, start session. If `.notDetermined`, request and then start. If `.denied`/`.restricted`, show inline denied UI.

```swift
// Source: Apple Developer Docs + createwithswift.com camera tutorial
.task {
    // Runs on MainActor by default — hop to CameraActor for AVFoundation
    await cameraManager.startSession()
}

// In CameraManager (@CameraActor):
func startSession() async {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
        startRunningIfNeeded()
    case .notDetermined:
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted { startRunningIfNeeded() }
        else { await MainActor.run { permissionDenied = true } }
    case .denied, .restricted:
        await MainActor.run { permissionDenied = true }
    @unknown default:
        break
    }
}

private func startRunningIfNeeded() {
    guard !session.isRunning else { return }
    session.startRunning()  // Blocking — safe on CameraActor's serial thread
}
```

**Key caveat:** `AVCaptureDevice.requestAccess(for:)` has an async Swift concurrency overload that returns `Bool`. Use it directly — no completion handler needed.

### Pattern 4: Camera Flip (Front ↔ Rear)

**What:** Remove current input, find opposite device, create new input, add it atomically inside `beginConfiguration()`/`commitConfiguration()`.

```swift
// Source: Apple Developer Forums + appcoda.com AVFoundation guide
@CameraActor
func flipCamera() {
    guard let currentInput else { return }
    let currentPosition = currentInput.device.position
    let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

    guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: newPosition),
          let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

    session.beginConfiguration()
    session.removeInput(currentInput)
    if session.canAddInput(newInput) {
        session.addInput(newInput)
        self.currentInput = newInput
    } else {
        session.addInput(currentInput)  // Restore on failure
    }
    session.commitConfiguration()
}
```

**Critical:** Always wrap multi-step configuration changes in `beginConfiguration()`/`commitConfiguration()` for atomic application. Using both front and rear cameras simultaneously is not supported.

### Pattern 5: Session Config Sheet

**What:** A shared `SessionConfigSheet` view presented as `.sheet` from `HomeView` and also from the gear icon in `LiveSessionView`. A single Bool state in `HomeView` (or in `AppCoordinator`) gates presentation. The sheet dismisses and navigation to `liveSession` fires on "Go" tap.

**When to use:** Two-point sheet reuse. The config state (skill, targetDuration) lives in `AppCoordinator` or a lightweight `SessionConfigViewModel` so both callers read the same values.

```swift
// Source: Apple Developer Docs sheet(isPresented:) + established project pattern
// In HomeView:
@State private var showingConfigSheet = false

Button("Start Session") {
    showingConfigSheet = true
}
.sheet(isPresented: $showingConfigSheet) {
    SessionConfigSheet { skill, targetDuration in
        // Create Session @Model, then navigate
        coordinator.navigate(to: .liveSession)
    }
    .presentationDetents([.medium])  // iOS 16+ — partial sheet
}
```

**Gear icon in LiveSessionView:** Uses the same `SessionConfigSheet` but without navigation — changes apply in-place. Pass a closure that updates the in-progress session config.

### Pattern 6: Full-Bleed ZStack Layout

**What:** Replace the current `LiveSessionView` VStack with a `ZStack` — camera preview fills the screen, controls float on top.

```swift
// LiveSessionView body — Phase 2 structure
ZStack {
    // Layer 0: Camera preview — full bleed
    CameraPreviewView(previewLayer: cameraManager.previewLayer)
        .ignoresSafeArea()

    // Layer 1: Minimal controls overlaid
    VStack {
        HStack {
            Spacer()
            // Flip button — top-right
            Button(action: flipCamera) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
        Spacer()
        HStack {
            // End Session — bottom-left, smaller
            Button("End Session") { coordinator.popToRoot() }
                .padding(.leading, 24)
                .padding(.bottom, 48)
            Spacer()
            // Gear icon — bottom-right
            Button(action: { showingConfigSheet = true }) {
                Image(systemName: "gearshape")
            }
            .padding(.trailing, 24)
            .padding(.bottom, 48)
        }
    }
}
.toolbar(.hidden, for: .navigationBar)
```

### Anti-Patterns to Avoid

- **Calling `startRunning()` on MainActor:** It is a blocking call that can stall the UI for hundreds of milliseconds. Always dispatch to `CameraActor`/background.
- **Passing `AVCaptureSession` as `@Sendable` across actor boundaries:** Session is not `Sendable`. Keep it confined entirely within `CameraActor`. The preview layer maintains the session reference internally — do not pass the session to SwiftUI views.
- **Mutating session without `beginConfiguration()`/`commitConfiguration()`:** Camera flip without the atomic wrapper causes undefined behavior or crash.
- **Frame-based preview via `CMSampleBuffer`:** Using `AVCaptureVideoDataOutputSampleBufferDelegate` for the viewfinder is unnecessary and adds CPU overhead. Reserve the data output for Phase 4+ (Vision analysis). Phase 2 needs no `AVCaptureVideoDataOutput`.
- **`@MainActor` on the camera class:** Using `@MainActor` isolation on `CameraManager` forces `startRunning()` to the main thread — guaranteed UI jank. The established pattern (STATE.md) is `@CameraActor`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Camera preview rendering | Custom Metal/OpenGL renderer | `AVCaptureVideoPreviewLayer` with `layerClass` override | Hardware-accelerated zero-copy path; handles orientation, mirroring automatically |
| Camera thread safety | Manual locking (`NSLock`, `os_unfair_lock`) | `@CameraActor` global actor | Swift 6 compiler verifies isolation; manual locks are invisible to the compiler |
| Permission flow | Custom permission dialog UI | System `AVCaptureDevice.requestAccess` | App Store review requires system dialog for camera; custom pre-prompt removed from locked decisions |
| Target hold time persistence | SwiftData @Model | `@AppStorage(Double)` backed by UserDefaults | Scalar preference — SwiftData relationship overhead is not justified |
| Portrait orientation lock | Per-view `supportedInterfaceOrientations` | `project.yml` + `Info.plist` `UISupportedInterfaceOrientations` | Already done in Phase 1; confirmed in `Info.plist` |
| Camera NSPrivacyUsageDescription | --- | Add `NSCameraUsageDescription` to `project.yml` + regenerate | Missing from current `Info.plist` — app will crash at runtime without it |

**Key insight:** AVFoundation's `AVCaptureVideoPreviewLayer` is a first-class Core Animation layer rendered by the hardware video compositor. Any frame-based alternative copies data from GPU back to CPU and then back to GPU — always worse.

---

## Common Pitfalls

### Pitfall 1: Missing NSCameraUsageDescription

**What goes wrong:** App crashes immediately when the system attempts to present the camera permission dialog. Crash log: `This app has crashed because it attempted to access privacy-sensitive data without a usage description.`

**Why it happens:** iOS privacy framework requires a human-readable explanation string in Info.plist for any camera access attempt. The current `Info.plist` does not include `NSCameraUsageDescription`.

**How to avoid:** Add to `project.yml` under `info.properties`:
```yaml
NSCameraUsageDescription: "CaliTimer needs camera access to detect and time your handstand holds."
```
Then regenerate the project with XcodeGen.

**Warning signs:** App terminates on first camera permission trigger. Xcode console shows privacy violation message.

### Pitfall 2: startRunning() Called on Main Thread

**What goes wrong:** `startRunning()` is a blocking call. If called on `@MainActor` (e.g., in `.onAppear` without a Task hop), the UI freezes for 100–500ms while AVFoundation initializes. Also triggers "Main Thread Checker: AVCaptureSession.startRunning should be called from background thread" warning.

**Why it happens:** SwiftUI `.onAppear` and `.task` run on MainActor by default. Developers forget to hop to a background context.

**How to avoid:** Wrap in `Task { await cameraManager.startSession() }` where `startSession()` is `@CameraActor`-isolated. The actor hop is automatic.

**Warning signs:** UI freeze on session screen arrival; Xcode runtime warning about main thread.

### Pitfall 3: AVCaptureSession Sendable Violation

**What goes wrong:** Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete` is set in project.yml) produces compile errors when `AVCaptureSession` is accessed across actor boundaries. `AVCaptureSession` is not `Sendable`.

**Why it happens:** Developers pass `session` to SwiftUI views or access it from `@MainActor` context.

**How to avoid:** Never pass `AVCaptureSession` to SwiftUI views. Pass `AVCaptureVideoPreviewLayer` (which maintains its own `session` reference) only at init time, from the actor's `init()`, before isolation matters. Once initialized, the layer renders autonomously.

**Warning signs:** Compiler error: "Sending 'session' risks causing data races."

### Pitfall 4: Camera Flip Without beginConfiguration/commitConfiguration

**What goes wrong:** Removing an input and adding a new one in separate calls may cause the session to be in a broken intermediate state, resulting in a black preview or crash.

**Why it happens:** Session treats each mutation as immediately active without the configuration guard.

**How to avoid:** Always use `session.beginConfiguration()` before any multi-step input/output change, and `session.commitConfiguration()` when done.

### Pitfall 5: previewLayer Frame Not Updating on View Resize

**What goes wrong:** On some devices or in preview (Xcode canvas), the `AVCaptureVideoPreviewLayer` frame doesn't fill the view because it was set before Auto Layout resolved.

**Why it happens:** Layers need explicit frame setting; `AVCaptureVideoPreviewLayer` doesn't automatically track its superlayer bounds without `needsLayout`.

**How to avoid:** Override `layoutSubviews()` in `PreviewUIView` to update the layer frame:
```swift
override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer.frame = bounds
}
```
With `videoGravity = .resizeAspectFill`, this ensures full-bleed fill in all layout passes.

### Pitfall 6: Portrait Orientation of Video Feed (Mirroring/Rotation)

**What goes wrong:** The front camera preview appears mirrored or rotated incorrectly. The live preview looks fine but recorded frames would be wrong (Phase 7 concern).

**Why it happens:** `AVCaptureVideoPreviewLayer` handles preview orientation automatically; front camera is mirrored by default for mirror-like UX. This is correct behavior for the viewfinder.

**How to avoid:** Do nothing for Phase 2 — the default `videoGravity = .resizeAspectFill` and automatic mirroring are correct for a live viewfinder. Phase 7 (recording) handles output orientation separately.

### Pitfall 7: Sheet Presented from Two Places — State Management

**What goes wrong:** If `showingConfigSheet` state lives in the wrong place, the gear icon in `LiveSessionView` and the "Start Session" button in `HomeView` can't both present `SessionConfigSheet` cleanly.

**Why it happens:** Navigation stack pushes and pops views, so state in a pushed view (`LiveSessionView`) is not accessible to the parent (`HomeView`).

**How to avoid:** Keep sheet presentation state local to each calling view. Both `HomeView` and `LiveSessionView` own their own `@State var showingConfigSheet = false`. The config values (skill, targetDuration) flow through either `AppCoordinator` or a struct passed as arguments.

---

## Code Examples

Verified patterns from authoritative sources:

### CameraActor Declaration

```swift
// Source: STATE.md (established project decision) + fatbobman.com Swift 6 camera article
@globalActor
actor CameraActor: GlobalActor {
    static let shared = CameraActor()
}
```

### PreviewUIView with layerClass Override

```swift
// Source: neuralception.com + canopas.com camera tutorials (multiple consistent sources)
final class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
```

### Camera Permission (async/await)

```swift
// Source: Apple Developer Docs requestAccess(for:completionHandler:) + async overload
let granted = await AVCaptureDevice.requestAccess(for: .video)
```

### Open App Settings (Permission Denied)

```swift
// Source: Apple Developer Forums — standard pattern for Settings deep-link
if let url = URL(string: UIApplication.openSettingsURLString) {
    await UIApplication.shared.open(url)
}
```

### Camera Device Discovery

```swift
// Source: Apple Developer Docs AVCaptureDevice.default(_:for:position:)
let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
```

### @AppStorage for TimeInterval (Double)

```swift
// Source: HackingWithSwift @AppStorage docs — Double is a supported type
@AppStorage("targetHoldDuration") private var targetHoldDuration: Double = 0.0
// 0.0 = no target set; positive value = seconds
```

### Session Config Sheet Presentation

```swift
// Source: Apple Developer Docs sheet(isPresented:onDismiss:content:)
.sheet(isPresented: $showingConfigSheet) {
    SessionConfigSheet(onConfirm: { skill, duration in
        // ...
    })
    .presentationDetents([.medium])
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@StateObject` camera manager on `@MainActor` | `@CameraActor`-isolated class accessed via `await` | Swift 6 (2024) | Eliminates data races without manual locking; compiler-verified |
| `DispatchQueue.global().async { session.startRunning() }` | `@CameraActor` isolation (actor guarantees serial execution) | Swift 5.10/6 strict concurrency | Same semantics, compiler-verified |
| Custom pre-permission dialog before system prompt | System dialog only (App Store guideline evolution) | ~2022 | Simpler code; avoids App Store rejection |
| `UIInterfaceOrientationMask` override per-view | `Info.plist UISupportedInterfaceOrientations` global lock | iOS 16+ guidance | Per-view override is fragile in SwiftUI; plist lock is definitive |
| Frame-based `CMSampleBuffer` → SwiftUI Image for preview | `AVCaptureVideoPreviewLayer` via UIViewRepresentable | Always correct; rediscovered with SwiftUI adoption | Zero-copy hardware path; CPU stays free for Vision in Phase 4+ |

**Already established in this project (no action needed):**
- Portrait lock: `UISupportedInterfaceOrientations` set in `Info.plist` and `project.yml`
- `@Observable` + `@MainActor` for view models (AppCoordinator pattern)
- `UIViewRepresentable` expected for camera preview (comment in LiveSessionView)
- `@CameraActor` GlobalActor pattern: documented in STATE.md as established decision

---

## Open Questions

1. **Session preset for Phase 2**
   - What we know: `AVCaptureSession.sessionPreset` controls quality/performance. Options: `.photo`, `.high`, `.medium`, `.hd1920x1080`, `.hd4K3840x2160`.
   - What's unclear: Phase 2 has no recording or Vision output — only preview. The preset affects what's available for later phases.
   - Recommendation: Use `.hd1920x1080` now. It gives 1080p preview quality (appropriate for handstand detection accuracy in Phase 4+) without the thermal overhead of 4K. Can be locked or changed in Phase 4 when the Vision pipeline is wired in.

2. **Session @Model minimum properties**
   - What we know: `startedAt: Date` and `skill: String` are needed. `targetDuration: TimeInterval?` is noted as minimum viable.
   - What's unclear: Whether `cameraPosition: String` (front/back) is worth storing at session level in Phase 2, given Phase 6 fills out the full schema.
   - Recommendation: Add `startedAt`, `skill`, `targetDuration` per CONTEXT.md. Skip `cameraPosition` — the camera can change mid-session, so it belongs on individual holds, not the session. Phase 6 adds it there.

3. **XcodeGen regeneration requirement**
   - What we know: Adding `NSCameraUsageDescription` to `project.yml` requires running `xcodegen generate` to update Info.plist.
   - What's unclear: Whether the planner should include this as a Wave 0 task or inline with camera setup.
   - Recommendation: Make it the first task — app cannot be tested without this entry.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Docs — `AVCaptureSession` (startRunning, beginConfiguration, sessionPreset, thread safety)
- Apple Developer Docs — `AVCaptureDevice.requestAccess(for:)` async overload
- Apple Developer Docs — `UISupportedInterfaceOrientations` Info.plist key
- Apple Developer Docs — `sheet(isPresented:onDismiss:content:)`
- STATE.md — CameraActor (GlobalActor) decision established in research phase

### Secondary (MEDIUM confidence)
- [fatbobman.com — Swift 6 Refactoring in a Camera App](https://fatbobman.com/en/posts/swift6-refactoring-in-a-camera-app/) — `@globalActor CameraActor` implementation pattern; verified against STATE.md decision
- [Swift Forums — AVCaptureSession and concurrency](https://forums.swift.org/t/avcapturesession-and-concurrency/72681) — confirmed startRunning blocking + actor isolation approach
- [neuralception.com — Live camera feed in SwiftUI](https://www.neuralception.com/detection-app-tutorial-camera-feed/) — `UIViewControllerRepresentable` + `AVCaptureVideoPreviewLayer` pattern; consistent with Apple-recommended approach
- [canopas.com — iOS Camera APIs using SwiftUI](https://canopas.com/ios-how-to-integrate-camera-apis-using-swiftui-ea604a2d2d0f) — UIViewRepresentable + layerClass override; multiple sources agree
- [appcoda.com — Building a Full Screen Camera App Using AVFoundation](https://www.appcoda.com/avfoundation-swift-guide/) — camera flip removeInput/addInput pattern
- [createwithswift.com — Camera capture setup in SwiftUI](https://www.createwithswift.com/camera-capture-setup-in-a-swiftui-app/) — authorization flow

### Tertiary (LOW confidence)
- None — all critical patterns verified with primary or secondary sources.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All first-party APIs; no versions to track beyond iOS 17 minimum already set
- Architecture (CameraActor, UIViewRepresentable): HIGH — Established in STATE.md + verified by Swift Forums and Swift 6 migration articles
- Camera flip pattern: HIGH — Consistent across Apple Developer Forums and multiple tutorials
- Session config sheet: HIGH — Standard SwiftUI .sheet pattern, well documented
- Pitfalls: HIGH — startRunning blocking, NSCameraUsageDescription requirement confirmed by Apple docs; Sendable violation confirmed by Swift 6 spec

**Research date:** 2026-03-02
**Valid until:** 2026-09-02 (stable APIs; re-verify if iOS 19 SDK introduces camera API changes)
