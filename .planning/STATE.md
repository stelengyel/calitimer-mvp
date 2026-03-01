# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** Automatic hold timing with zero manual input — the app knows when the hold starts and when it breaks, so athletes can focus entirely on the skill.
**Current focus:** Phase 1 — Foundation + Core Detection

## Current Position

Phase: 1 of 3 v1 phases (Foundation + Core Detection)
Plan: 0 of 5 in current phase
Status: Ready to plan
Last activity: 2026-03-01 — Roadmap created; research complete; ready to plan Phase 1

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Research]: Stack is fully first-party Apple (Swift 6, SwiftUI, Vision, AVFoundation, SwiftData) — zero external dependencies
- [Research]: Handstand detection uses geometric classifier (feet above head in normalized coords), NOT per-joint confidence — Vision degrades on inverted poses
- [Research]: CameraActor (GlobalActor) + serial videoDataOutputQueue from day one — cannot be retrofitted; Swift 6 strict concurrency
- [Research]: VNSequenceRequestHandler created once per session (not per frame) — prevents jitter and CPU waste
- [Research]: AVAssetWriter initialized eagerly at session start to eliminate 5-7s initialization latency on hold detection

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1]: HandstandClassifier angle thresholds (wrist-y < ankle-y margin, vertical alignment tolerance, joint confidence cutoffs) must be determined empirically — no specific values from research
- [Phase 1]: Detection accuracy floor needs a concrete acceptance criterion before Phase 1 is considered complete (research suggests validating against 50-100 real handstand frames)
- [Phase 2]: Pre-roll buffer duration (2-3s recommended) needs user validation — right value for athletes must be confirmed
- [Phase 4]: Human Flag detection may require architecture-level camera orientation decisions — needs research before planning

## Session Continuity

Last session: 2026-03-01
Stopped at: Roadmap creation complete; ROADMAP.md, STATE.md, REQUIREMENTS.md traceability written
Resume file: None
