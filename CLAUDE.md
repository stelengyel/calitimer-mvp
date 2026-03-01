# CaliTimer MVP — Claude Instructions

## iOS Build Rule

**ALWAYS use XcodeBuildMCP tools for any iOS build, run, or test operations.**

Never use `xcodebuild`, `xcrun`, or shell-based build commands directly (via Bash) for iOS targets. Use the dedicated MCP tools instead:

- `build_sim` — compile only
- `build_run_sim` — build and launch on simulator
- `test_sim` — run tests on simulator
- `clean` — clean build products

Before any build operation, call `session_show_defaults` to confirm the active project/scheme/simulator configuration. If defaults are not set, use `session_set_defaults` to configure them first.