# Phase 4: Pose Detection - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Vision framework running on live camera frames and imported video frames — skeleton overlay renders in both contexts and is independently toggleable. No hold classification, state machine, or hold timing. Just verified pose data flowing end-to-end with visual confirmation.

Requirements covered: DETE-05 (Skeleton overlay rendered on camera feed, independently toggleable)

</domain>

<decisions>
## Implementation Decisions

### Skeleton overlay — joints and bones
- Key handstand joints only: wrists, shoulders, hips, ankles (8 joints)
- Bone connections between them: wrist→shoulder, shoulder→hip, hip→ankle (each side), plus shoulder-to-shoulder and hip-to-hip crossbar
- No head, neck, elbows, or knees — those are not needed for handstand detection and add clutter

### Skeleton overlay — visual style
- Color: brand ember (#FF5C35) — matches app accent, high contrast on both dark and bright backgrounds
- Subtle weight: 2pt lines, 4pt joint dots
- Only renders when a person is detected — disappears cleanly when athlete steps out of frame

### Skeleton toggle — placement
- Accessible in two places: inside `SessionConfigSheet` (gear icon in LiveSessionView) AND in the main SettingsView
- Not on the main session screen surface (no additional top/bottom bar button)
- Preference persists across sessions via UserDefaults
- Default: ON for first launch (validates detection is running immediately)

### Skeleton overlay — upload mode
- Skeleton renders live on top of `VideoPlayerView` as the imported video plays — identical visual to live camera mode
- Vision processes frames from the video in real-time during playback
- When paused or scrubbed, the overlay holds on the last processed frame — athlete can inspect a specific position
- Same toggle (SessionConfigSheet / SettingsView) applies to both live and upload modes

### Claude's Discretion
- Actor isolation architecture for video frame extraction from `AVPlayer` (CMSampleBuffer tap vs periodic frame sampling)
- Coordinate space transformation from VN normalized coords to view CGPoints
- Frame processing cadence during video playback (every frame vs throttled)
- Exact `UserDefaults` key and storage pattern for skeleton preference

</decisions>

<specifics>
## Specific Ideas

- Upload mode should feel identical to live mode — same ember skeleton, same toggle, same behavior
- Skeleton persists on pause so athletes can scrub through and inspect joint detection quality on specific frames

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CameraActor` (`CaliTimer/Camera/CameraActor.swift`): global actor already defined and reserved for Vision frame processing — VisionProcessor runs here
- `CameraManager` (`CaliTimer/Camera/CameraManager.swift`): @MainActor + private serial queue pattern; needs `AVCaptureVideoDataOutput` added in Phase 4 to feed frames to VisionProcessor
- `LiveSessionView` (`CaliTimer/UI/LiveSession/LiveSessionView.swift`): ZStack with camera preview on Layer 0, controls on Layer 1 — skeleton overlay drops in as a new layer between them
- `SessionConfigSheet` (`CaliTimer/UI/LiveSession/SessionConfigSheet.swift`): already used for mid-session config — skeleton toggle row goes here
- `SettingsView` (`CaliTimer/UI/Settings/SettingsView.swift`): skeleton toggle row added here as persistent preference
- `VideoPlayerView` + `UploadModeView` (`CaliTimer/Upload/`): skeleton overlay layers over the video player in Zone 2 — same ZStack approach as LiveSessionView
- `VideoImportManager` (`CaliTimer/Upload/VideoImportManager.swift`): owns the `AVPlayer` — Phase 4 taps into player for frame extraction

### Established Patterns
- `@MainActor` + `@State private var manager = Manager()` in views — VisionProcessor follows same isolation model
- `nonisolated(unsafe)` + private serial DispatchQueue: established in CameraManager for AV operations — replicate for video output queue
- Brand color extensions (`Color.brandEmber`, etc.) and `.font(.mono(x))` — use for any skeleton UI elements
- `VNSequenceRequestHandler` created once per session (not per frame) — already decided in research

### Integration Points
- `CameraManager` needs `AVCaptureVideoDataOutput` + `AVCaptureVideoDataOutputSampleBufferDelegate` added — feeds frames to VisionProcessor on `@CameraActor`
- `VideoImportManager` needs a frame tap mechanism (likely `AVPlayerItemVideoOutput` or periodic time observer) to extract `CVPixelBuffer` frames for Vision during playback
- `SessionConfigSheet` skeleton toggle must write to `UserDefaults` and publish state back to `LiveSessionView`
- `UploadModeView` Zone 2 (video player area) needs same overlay layer as `LiveSessionView` — Phase 3 Zone 3 stability contract remains untouched

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-pose-detection*
*Context gathered: 2026-03-06*
