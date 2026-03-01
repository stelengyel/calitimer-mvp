# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** Automatic hold timing with zero manual input — the app knows when the hold starts and when it breaks, so athletes can focus entirely on the skill.
**Current focus:** Phase 1 — App Layout & Navigation

## Current Position

Phase: 1 of 8 v1 phases (App Layout & Navigation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-01 — Roadmap redesigned to 9-phase structure; ready to plan Phase 1

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
- [Roadmap]: Redesigned from 4-phase to 9-phase structure — phases 1–3 isolate infrastructure, camera, and upload shell before detection is wired in; Phase 5 (Handstand Detection + Timer) identified as center of gravity requiring robust manual testing

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: HandstandClassifier angle thresholds (wrist-y < ankle-y margin, vertical alignment tolerance, joint confidence cutoffs) must be determined empirically — no specific values from research
- [Phase 5]: Detection accuracy floor needs a concrete acceptance criterion before Phase 5 is considered complete (research suggests validating against 50-100 real handstand frames)
- [Phase 7]: Clip-start delay (1–2s accepted) needs user validation — right value for athletes must be confirmed with real use
- [Phase 9]: Human Flag detection may require architecture-level camera orientation decisions — needs research before planning

## Session Continuity

Last session: 2026-03-01
Stopped at: Roadmap redesigned to 9-phase structure; ROADMAP.md, STATE.md, REQUIREMENTS.md traceability updated
Resume file: None
