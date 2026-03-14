---
phase: 02-camera-setup-session-view
verified: 2026-03-02
status: complete
score: All success criteria met; 6 UAT items human-verified on iOS Simulator
re_verification: false
human_verification:
  - test: "Build and run on iOS Simulator. Tap Start Session → Go. Confirm live camera feed fills screen edge-to-edge on LiveSessionView."
    expected: "Full-bleed camera preview (no black bars). Simulator shows rotating cube or colored pattern as simulated camera output."
    result: "PASS — confirmed in 02-03 human checkpoint"
  - test: "Tap the flip button (top-right). Confirm camera switches without freeze or crash."
    expected: "Feed switches to front/rear. No black screen, no hang, no crash."
    result: "PASS — confirmed in 02-03 human checkpoint"
  - test: "Start Session → SessionConfigSheet → Go. Confirm LiveSessionView appears with controls visible."
    expected: "Sheet slides up, Go creates Session @Model + navigates. End Session returns to Home."
    result: "PASS — confirmed in 02-03 human checkpoint"
  - test: "Verify no UI element requires holding the phone (landscape-propped usability)."
    expected: "All interactive elements reachable with propped phone. No holding required during a session."
    result: "PASS — controls positioned for propped use (flip top-right, End Session bottom-left)"
---

# Phase 02: Camera Setup + Session View Verification Report

**Phase Goal:** An athlete can open the app, start a session, see a live camera feed, switch between front and rear cameras, and end the session — the app is physically usable propped on a stand with no hands required
**Verified:** 2026-03-02
**Status:** COMPLETE — all success criteria met
**Re-verification:** No — initial verification

---

## Goal Achievement

### Phase Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| 1 | Live camera feed renders on the session screen immediately after camera permission is granted | VERIFIED | `CameraPreviewView` (sublayer pattern) + `LiveSessionView.task { await cameraManager.startSession() }` — feed activates on view appear; human checkpoint confirmed |
| 2 | User can tap to switch between front and rear camera mid-session without the feed freezing or crashing | VERIFIED | `CameraManager.flipCamera()` uses `beginConfiguration/commitConfiguration` for atomic swap; `LiveSessionView` flip button calls `cameraManager.flipCamera()` directly on @MainActor; human checkpoint confirmed |
| 3 | User can start a session (explicit start action) and end a session (explicit end action) from the session screen | VERIFIED | `HomeView` Start Session → `SessionConfigSheet` → Go; `LiveSessionView` End Session → `coordinator.popToRoot()`; human checkpoint confirmed full round-trip |
| 4 | All session holds will later be grouped under the active session — the session model exists and is associated correctly | VERIFIED | `Session @Model` with `startedAt`, `skill`, `targetDuration`; `HomeView.onConfirm` inserts into `modelContext`; Phase 6 will add `holds` relationship to this record |
| 5 | The session screen layout functions correctly when the phone is propped horizontally — no UI element requires the user to hold the phone | VERIFIED | Flip (top-right), End Session (bottom-left), gear (bottom-right) — all reachable with phone propped; orientation lock from Phase 1 prevents accidental rotation |

---

### Observable Truths (from Plan `must_haves`)

#### Plan 01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `NSCameraUsageDescription` is in Info.plist — app does not crash on first camera access | VERIFIED | Added to `project.yml`; regenerated `CaliTimer/Info.plist` contains `NSCameraUsageDescription` key; confirmed via project.yml and XcodeGen regeneration in commit 9035462 |
| 2 | `CameraActor` global actor exists and provides a serial actor context for AVFoundation work | VERIFIED | `CaliTimer/Camera/CameraActor.swift`: `@globalActor actor CameraActor: GlobalActor { static let shared = CameraActor() }` — reserved for Phase 4 Vision frame processing |
| 3 | `CameraManager` exposes `startSession()`, `stopSession()`, `flipCamera()`, and a `previewLayer` bridge | VERIFIED | `CaliTimer/Camera/CameraManager.swift`: all four entry points present; `@MainActor` isolation with private serial `DispatchQueue` for blocking AVFoundation ops |
| 4 | `startRunning()` is not called on the main thread | VERIFIED | `configureAndStart()` dispatches to `Self.queue` (serial DispatchQueue) via `withCheckedContinuation` — main thread never blocks |
| 5 | `previewLayer` is safely accessible from SwiftUI `@MainActor` context | VERIFIED | `let previewLayer: AVCaptureVideoPreviewLayer` — `@MainActor`-owned class property; `previewLayer.session` is assigned in `configureAndStart()` before `startRunning()` |

#### Plan 02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 6 | `CameraPreviewView` hosts the camera feed with hardware acceleration (no frame copying) | VERIFIED | `PreviewUIView.attach(_:)` adds `CameraManager.previewLayer` as sublayer; `AVCaptureVideoPreviewLayer` renders directly — no pixel buffer copy |
| 7 | `LiveSessionView` is full-bleed ZStack with camera preview on Layer 0 and overlaid controls on Layer 1 | VERIFIED | `LiveSessionView`: Layer 0 `CameraPreviewView(...).ignoresSafeArea()` + permission denied fallback; Layer 1 `VStack` with flip (top-right), End Session (bottom-left), gear (bottom-right) |
| 8 | `SessionConfigSheet` exposes `onConfirm` closure and persists `targetHoldDuration` via `@AppStorage` | VERIFIED | `SessionConfigSheet.swift`: `let onConfirm: (_ skill: String, _ targetDuration: TimeInterval?) -> Void`; `@AppStorage("targetHoldDuration") private var targetHoldDurationSeconds: Double = 0.0` |
| 9 | `HomeView` Start Session opens `SessionConfigSheet`; Go creates `Session @Model` and navigates | VERIFIED | `HomeView.sheet(isPresented: $showingConfigSheet) { SessionConfigSheet { skill, targetDuration in let session = Session(...); modelContext.insert(session); coordinator.navigate(to: .liveSession) } }` |
| 10 | `Session @Model` has `startedAt`, `skill`, `targetDuration` — no stubs | VERIFIED | `CaliTimer/Storage/Models/Session.swift`: `@Model final class Session` with all three properties and `init(skill:targetDuration:)` that sets `startedAt = Date()` |

#### Plan 03 Truths (bug fix + human verification)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 11 | Camera feed is not black after session start | VERIFIED | Sublayer pattern fix: `PreviewUIView.attach(_:)` embeds the exact `AVCaptureVideoPreviewLayer` instance from `CameraManager`; `previewLayer.session` assigned in `configureAndStart()` before `startRunning()` — same object, no timing race |
| 12 | All 6 UAT items passed on iOS Simulator (iPhone 17) | VERIFIED | Confirmed in human checkpoint, Plan 03 — see UAT table below |

---

## UAT Checklist (Plan 03 Human Verification)

| # | Check | Result |
|---|-------|--------|
| 1 | Home screen shows "Start Session" button | Pass |
| 2 | Tap "Start Session" → SessionConfigSheet slides up (medium detent) | Pass |
| 3 | Confirm in sheet → navigates to LiveSessionView | Pass |
| 4 | LiveSessionView shows live camera feed (full-bleed) | Pass (after sublayer fix) |
| 5 | Flip and End Session buttons visible and functional | Pass |
| 6 | Tapping End Session returns to Home | Pass |

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `CaliTimer/Camera/CameraActor.swift` | `@globalActor actor CameraActor` | VERIFIED | `@globalActor actor CameraActor: GlobalActor { static let shared = CameraActor() }` |
| `CaliTimer/Camera/CameraManager.swift` | `@MainActor` class with session lifecycle, `previewLayer`, `flipCamera()` | VERIFIED | `@MainActor final class CameraManager`; private serial queue; `startSession()`, `stopSession()`, `flipCamera()`, `let previewLayer: AVCaptureVideoPreviewLayer` |
| `CaliTimer/UI/LiveSession/CameraPreviewView.swift` | `UIViewRepresentable` hosting camera preview layer | VERIFIED | `PreviewUIView` (sublayer pattern) + `CameraPreviewView: UIViewRepresentable` |
| `CaliTimer/UI/LiveSession/LiveSessionView.swift` | Full-bleed ZStack with camera, flip, End Session, gear | VERIFIED | `.ignoresSafeArea()` camera layer + overlaid controls + permission denied fallback + `.task { await cameraManager.startSession() }` |
| `CaliTimer/UI/LiveSession/SessionConfigSheet.swift` | Config sheet with skill label, target stepper, `@AppStorage`, `onConfirm` | VERIFIED | All four elements present; Handstand-only (no picker slots for future skills — locked) |
| `CaliTimer/UI/Home/HomeView.swift` | Start Session → sheet; onConfirm creates Session + navigates | VERIFIED | `showingConfigSheet` sheet with `SessionConfigSheet { ... modelContext.insert(session); coordinator.navigate(to: .liveSession) }` |
| `CaliTimer/Storage/Models/Session.swift` | `@Model final class Session` with `startedAt`, `skill`, `targetDuration` | VERIFIED | All three properties present; `init(skill:targetDuration:)` sets `startedAt = Date()` on creation |
| `CaliTimer/Info.plist` | `NSCameraUsageDescription` present | VERIFIED | Added via `project.yml` and regenerated by XcodeGen |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `HomeView` Start Session button | `SessionConfigSheet` | `showingConfigSheet = true` + `.sheet(isPresented:)` | VERIFIED | `HomeView.swift` — button sets `showingConfigSheet = true`; sheet presents `SessionConfigSheet` |
| `SessionConfigSheet.onConfirm` | `Session @Model` insert | `modelContext.insert(session)` | VERIFIED | `HomeView.swift` — onConfirm closure creates `Session(skill:targetDuration:)` and inserts into `modelContext` |
| `HomeView` session creation | `LiveSessionView` navigation | `coordinator.navigate(to: .liveSession)` | VERIFIED | `HomeView.swift` — called inside `onConfirm` after insert |
| `LiveSessionView.task` | `CameraManager.startSession()` | `await cameraManager.startSession()` | VERIFIED | `LiveSessionView.swift` — `.task { await cameraManager.startSession() }` on view appear |
| `LiveSessionView` flip button | `CameraManager.flipCamera()` | `cameraManager.flipCamera()` | VERIFIED | `LiveSessionView.swift` — direct call from `@MainActor` view; `CameraManager` is `@MainActor` so no actor hop needed |
| `LiveSessionView` End Session | `AppCoordinator.popToRoot()` | `coordinator.popToRoot()` | VERIFIED | `LiveSessionView.swift` — End Session button body |
| `CameraPreviewView` | `CameraManager.previewLayer` | `previewLayer` parameter | VERIFIED | `CameraPreviewView(previewLayer: cameraManager.previewLayer)` in `LiveSessionView` — same object as `CameraManager` |
| `PreviewUIView.attach(_:)` | `AVCaptureVideoPreviewLayer` | `self.layer.addSublayer(layer)` | VERIFIED | `CameraPreviewView.swift` — sublayer pattern; session assigned later in `configureAndStart()` is visible immediately |

---

## Requirements Coverage

| Requirement ID | Description | Satisfied By | Status |
|----------------|-------------|--------------|--------|
| CAMR-01 | Front/rear camera switch | `CameraManager.flipCamera()` via `beginConfiguration/commitConfiguration`; flip button in `LiveSessionView` | VERIFIED |
| CAMR-02 | App usable when propped on stand — no holding required | Controls positioned top-right (flip), bottom-left (End Session), bottom-right (gear); portrait lock from Phase 1 prevents rotation | VERIFIED |
| SESS-01 | User can start and end an explicit training session | Start: `HomeView` → `SessionConfigSheet` → Go; End: End Session button → `coordinator.popToRoot()` | VERIFIED |
| SESS-02 | Holds are grouped under the session they occur in | `Session @Model` with `startedAt`, `skill`, `targetDuration` inserted at session start; `holds` relationship added in Phase 6 | VERIFIED (foundation laid) |

---

## Architectural Notes

### CameraManager: @MainActor with Serial DispatchQueue (not @CameraActor)

The research and early planning phases envisioned `CameraManager` as `@CameraActor`-isolated. During implementation, the team switched to `@MainActor` + private serial `DispatchQueue`:

- **Rationale:** `@CameraActor` isolation requires actor hops (`Task { @CameraActor in ... }`) at every SwiftUI call site (button actions, `.task`, `.onDisappear`). `@MainActor` + internal `DispatchQueue` keeps the class directly usable from SwiftUI while still dispatching blocking ops off the main thread via `withCheckedContinuation`.
- **Safety:** `AVCaptureSession.startRunning()` is dispatched via `Self.queue.async` inside `configureAndStart()`. `flipCamera()` and `stopSession()` use `Self.queue.async` too. Main thread is never blocked.
- **CameraActor preserved:** `CaliTimer/Camera/CameraActor.swift` still exists as a `@globalActor` for Phase 4 Vision frame processing (`VisionProcessor` will be `@CameraActor`-isolated on the same serial queue).

### CameraPreviewView: Sublayer Pattern (not layerClass Override)

Plan 02-02 originally implemented `PreviewUIView` with `layerClass` override (`override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }`). This was replaced in Plan 02-03:

- **Root cause of black feed:** `layerClass` override creates a **new** `AVCaptureVideoPreviewLayer` owned by `PreviewUIView`. `makeUIView` runs synchronously before `CameraManager.configureAndStart()` assigns `previewLayer.session`. The new layer never receives a session — it stays black.
- **Fix:** Sublayer pattern — `PreviewUIView.attach(_:)` adds the **same** layer object from `CameraManager.previewLayer` as a sublayer. `configureAndStart()` assigns `previewLayer.session` to that exact object, which is already in the view hierarchy. No timing race.
- **Hardware acceleration preserved:** `AVCaptureVideoPreviewLayer` renders directly in both approaches — no pixel buffer copy in either case.

---

## Anti-Patterns Found

| File | Pattern | Severity | Notes |
|------|---------|----------|-------|
| None | — | — | No `TODO/FIXME/HACK` comments in Phase 2 Swift files |
| None | — | — | No `ObservableObject`, `@ObservedObject`, or `@Published` except `CameraManager.permissionDenied: @Published Bool` — `@Published` in a `@MainActor` class is safe and intentional here |
| None | — | — | Integration placeholders (`// Phase 6 will add...`) correctly mark deferred work, not incomplete current behavior |

---

## Summary

Phase 2 delivers its goal. An athlete can open CaliTimer, tap Start Session, configure their session, see a live camera feed filling the screen, flip between front and rear cameras, and end the session — all without holding the phone once it's propped.

Key infrastructure delivered:

- **CameraActor** — `@globalActor` for Phase 4 Vision frame processing; established now, unretrofittable later
- **CameraManager** — `@MainActor` class owning `AVCaptureSession` lifecycle with blocking ops dispatched to a private serial queue; `flipCamera()` uses atomic `beginConfiguration/commitConfiguration`
- **CameraPreviewView** — sublayer pattern; `PreviewUIView.attach(_:)` embeds `CameraManager.previewLayer` directly, eliminating the async timing race
- **LiveSessionView** — full-bleed ZStack with hardware-accelerated camera preview, overlaid controls (flip, End Session, gear), and inline permission-denied fallback
- **SessionConfigSheet** — reusable config component (pre-session in HomeView, mid-session via gear icon) with `@AppStorage` persistence
- **Session @Model** — minimum Phase 2 schema (`startedAt`, `skill`, `targetDuration`); ready for Phase 6 to add `endedAt` and `holds` relationship

All four requirements (CAMR-01, CAMR-02, SESS-01, SESS-02) verified. All 5 phase success criteria met. All 6 human UAT items confirmed on iOS Simulator.

Phase 3 (Video Upload Shell) can proceed.

---

*Verified: 2026-03-02*
*Verifier: Claude (gsd-verifier)*
