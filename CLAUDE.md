# CaliTimer MVP — Claude Instructions

## iOS Build Rule

**ALWAYS use XcodeBuildMCP tools for any iOS build, run, or test operations.**

Never use `xcodebuild`, `xcrun`, or shell-based build commands directly (via Bash) for iOS targets. Use the dedicated MCP tools instead:

- `build_sim` — compile only
- `build_run_sim` — build and launch on simulator
- `test_sim` — run tests on simulator
- `clean` — clean build products

Before any build operation, call `session_show_defaults` to confirm the active project/scheme/simulator configuration. If defaults are not set, use `session_set_defaults` to configure them first.

## Context7 Rule

**Before writing code that calls a specific Apple framework API, query Context7 for current method signatures, delegate patterns, and known caveats.**

Use Context7 when:
- Implementing or referencing a specific API (e.g. `VNDetectHumanBodyPoseRequest`, `AVAssetWriter`, `@ModelActor`, `PHPickerViewController`)
- The correct usage isn't already established in the planning docs (STACK.md, RESEARCH.md, PLAN.md)
- A known caveat or version difference is relevant (e.g. iOS 17 vs 18 Vision API)