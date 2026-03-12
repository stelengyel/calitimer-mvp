---
created: 2026-03-12T16:22:07.956Z
title: Handstand detection post-Phase-5 polish
area: general
files:
  - CaliTimer/Vision/HandstandClassifier.swift
  - CaliTimer/Vision/HoldStateMachine.swift
  - CaliTimer/Vision/VisionProcessor.swift
  - CaliTimer/UI/LiveSession/LiveSessionView.swift
  - CaliTimer/UI/Upload/UploadModeView.swift
---

## Problem

Phase 5 is signed off and all manual checks pass, but the handstand detection system is not yet 100% production-ready. Known areas needing attention before production:

- Threshold tuning (confidence cutoffs, wristY < ankleY margin, shoulder/hip fallback sensitivity)
- Performance optimizations (frame processing, state machine efficiency)
- UI adjustments (indicator states, timer display, feedback timing)

Deferred from Phase 5 sign-off — acceptable for current milestone but should be addressed before shipping.

## Solution

TBD — revisit after Phase 6 (Session History) is complete. Review detection accuracy against real-world training footage, tune thresholds empirically, then address UI polish based on athlete feedback.
