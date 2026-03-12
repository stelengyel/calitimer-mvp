import Foundation
import AudioToolbox
import Combine
import CoreMedia

// MARK: - HoldRecord

/// A single confirmed handstand hold with accurate backdated timestamps.
struct HoldRecord: Identifiable {
    let id = UUID()
    let startDate: Date?           // nil in upload mode (use videoStartSeconds)
    let endDate: Date?             // nil in upload mode
    let videoStartSeconds: Double? // non-nil in upload mode (CMTime → seconds from video start)
    let videoEndSeconds: Double?
    let duration: TimeInterval     // always set: endTime - startTime in wall clock or video time

    /// Formatted start time for display. Upload mode uses video offset; live mode uses Date.
    func formattedStart() -> String {
        if let vs = videoStartSeconds { return formatSeconds(vs) }
        return ""  // live mode: Phase 6 will use Date
    }

    func formattedEnd() -> String {
        if let ve = videoEndSeconds { return formatSeconds(ve) }
        return ""
    }

    private func formatSeconds(_ s: Double) -> String {
        let t = max(0, Int(s))
        return "\(t / 60):\(String(format: "%02d", t % 60))"
    }
}

// MARK: - HoldState

enum HoldState: Equatable {
    case searching  // no handstand detected
    case detected   // pose seen, entry debounce counting
    case timing     // hold confirmed, timer running
}

// MARK: - HoldStateMachine

/// Tracks handstand hold state and timing from per-frame pose observations.
///
/// State transitions:
///   searching → detected (first inverted frame)
///   detected  → timing   (entryThreshold frames confirmed — entry confirmed, start backdated)
///   detected  → searching (non-inverted frame interrupts before threshold)
///   timing    → searching (exitThreshold consecutive non-inverted frames — hold confirmed, end backdated)
///
/// Upload mode: set currentVideoTime before each process() call.
/// Live mode: wall-clock Date timestamps are used automatically.
@MainActor
final class HoldStateMachine: ObservableObject {

    // MARK: - Published state (consumed by UI)

    @Published private(set) var state: HoldState = .searching
    @Published private(set) var displayedElapsed: TimeInterval = 0
    @Published private(set) var lastHoldDuration: TimeInterval = 0
    @Published private(set) var completedHolds: [HoldRecord] = []

    // MARK: - Configuration

    var targetDuration: TimeInterval? = nil

    // MARK: - Debounce constants
    // Entry: ~5 frames (~0.17s at 30fps) — fast enough to catch clean entries
    // Exit: 12 frames (~0.4s at 30fps) — within 10–15 range per CONTEXT.md
    private let entryThreshold = 5
    private let exitThreshold = 12

    // MARK: - Internal state

    private var entryFrameCount = 0
    private var exitFrameCount = 0
    private var potentialStart: Date?
    private var confirmedStart: Date?
    private var potentialEnd: Date?
    private var hasAlerted = false

    // Upload mode: set by AVAssetReaderScanner before each process() call
    var currentVideoTime: CMTime? = nil
    private var potentialStartVideoTime: CMTime?
    private var potentialEndVideoTime: CMTime?

    // MARK: - Timer (1Hz elapsed display, active only during .timing)

    private var timerCancellable: AnyCancellable?

    // MARK: - Processing

    /// Called on every frame from LiveSessionView.onReceive or AVAssetReaderScanner.
    /// Must be called on MainActor.
    func process(pose: DetectedPose?) {
        let isHandstand = HandstandClassifier.isHandstand(pose)

        switch state {
        case .searching:
            if isHandstand {
                // First inverted frame — record potentialStart for backdating
                if potentialStart == nil {
                    potentialStart = Date()
                    potentialStartVideoTime = currentVideoTime
                }
                entryFrameCount += 1
                state = .detected

                if entryFrameCount >= entryThreshold {
                    confirmEntry()
                }
            } else {
                resetEntryCounters()
            }

        case .detected:
            if isHandstand {
                entryFrameCount += 1
                if entryFrameCount >= entryThreshold {
                    confirmEntry()
                }
            } else {
                // Non-inverted frame during entry debounce — reset to searching.
                // Exit debounce applies only in .timing state.
                resetEntryCounters()
                state = .searching
            }

        case .timing:
            if isHandstand {
                // Hold continuing — reset exit counters
                exitFrameCount = 0
                potentialEnd = nil
                potentialEndVideoTime = nil
                // Upload mode: update displayed elapsed using video timestamps each frame.
                // Live mode uses the wall-clock Timer instead (started by confirmEntry).
                if let startVT = potentialStartVideoTime, let curVT = currentVideoTime {
                    displayedElapsed = max(0, CMTimeGetSeconds(curVT) - CMTimeGetSeconds(startVT))
                }
            } else {
                // First or subsequent non-inverted frame — start exit debounce
                if potentialEnd == nil {
                    potentialEnd = Date()
                    potentialEndVideoTime = currentVideoTime
                }
                exitFrameCount += 1
                if exitFrameCount >= exitThreshold {
                    confirmExit()
                }
            }
        }
    }

    /// Reset for a new video scan (upload mode). Does not affect targetDuration.
    func resetForNewScan() {
        state = .searching
        displayedElapsed = 0
        lastHoldDuration = 0
        completedHolds = []
        resetEntryCounters()
        exitFrameCount = 0
        potentialEnd = nil
        potentialEndVideoTime = nil
        hasAlerted = false
        stopTimer()
    }

    // MARK: - Private

    private func confirmEntry() {
        confirmedStart = potentialStart  // backdate to first inverted frame
        state = .timing
        hasAlerted = false
        exitFrameCount = 0
        potentialEnd = nil
        potentialEndVideoTime = nil
        // Upload mode uses CMTime-based elapsed updated per-frame in process().
        // Wall-clock timer is only meaningful for live sessions.
        if currentVideoTime == nil {
            startTimer()
        }
    }

    private func confirmExit() {
        stopTimer()

        // Calculate accurate duration using backdated timestamps
        let holdDuration: TimeInterval
        let startSeconds: Double?
        let endSeconds: Double?

        if let startVT = potentialStartVideoTime, let endVT = potentialEndVideoTime {
            // Upload mode: use video timestamps (CMTime-based, not wall clock)
            let s = CMTimeGetSeconds(startVT)
            let e = CMTimeGetSeconds(endVT)
            holdDuration = max(0, e - s)
            startSeconds = s
            endSeconds = e
        } else if let start = confirmedStart, let end = potentialEnd {
            // Live mode: wall clock
            holdDuration = max(0, end.timeIntervalSince(start))
            startSeconds = nil
            endSeconds = nil
        } else {
            holdDuration = displayedElapsed
            startSeconds = nil
            endSeconds = nil
        }

        let record = HoldRecord(
            startDate: confirmedStart,
            endDate: potentialEnd,
            videoStartSeconds: startSeconds,
            videoEndSeconds: endSeconds,
            duration: holdDuration
        )
        completedHolds.append(record)
        lastHoldDuration = holdDuration
        displayedElapsed = holdDuration  // freeze display on final duration

        // Reset for next hold
        resetEntryCounters()
        exitFrameCount = 0
        potentialEnd = nil
        potentialEndVideoTime = nil
        confirmedStart = nil
        state = .searching
    }

    private func resetEntryCounters() {
        entryFrameCount = 0
        potentialStart = nil
        potentialStartVideoTime = nil
    }

    private func startTimer() {
        // Timer is only for live session elapsed display.
        // Upload mode does NOT use this path — displayedElapsed is updated via confirmExit()
        // using the CMTime delta directly.
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.state == .timing, let start = self.confirmedStart else { return }
                self.displayedElapsed = Date().timeIntervalSince(start)
                self.checkTargetAlert()
            }
    }

    private func stopTimer() {
        timerCancellable = nil
    }

    private func checkTargetAlert() {
        // Fires AudioServicesPlaySystemSound once when displayedElapsed crosses targetDuration.
        // Audio only — no haptics per user decision.
        guard let target = targetDuration, !hasAlerted,
              displayedElapsed >= target else { return }
        AudioServicesPlaySystemSound(1057)  // "Tink" — short, clean; respects silent mode
        hasAlerted = true
    }
}
