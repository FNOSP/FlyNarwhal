---
name: native-desktop-ui-testing
description: Run and verify Flutter desktop behavior on Windows/macOS/Linux native clients. Invoke when developing, fixing, or testing PC features, user flows, interaction results, Dart MCP scenarios, or testability anchors like ValueKey.
metadata:
  author: SOLO
  version: "1.0.0"
  domain: desktop-ui-testing
  role: specialist
  scope: execution
---

# Native Desktop UI Testing

## Overview

This skill is for **this Flutter PC client project** when running or preparing UI tests for the **native desktop app**.

Supported target forms:

- Windows desktop app
- macOS desktop app
- Linux desktop app

This skill is **not** for web UI verification in this project.

## When To Use

Default to this skill for this project's desktop client work: whenever you are developing, fixing, or verifying features that affect native user flows, visible state, interaction results, session behavior, navigation outcomes, or other behavior that should be validated through the real desktop client, invoke this skill unless the task is clearly isolated from client-side behavior.

- the user asks to run or verify desktop UI flows
- the task involves `mcp_dart` UI control
- the task involves player controls, navigation, login/logout, settings, or other desktop client interactions
- the task changes logic that may not alter UI code directly but does affect desktop client behavior or user-visible outcomes
- the task requires adding or reviewing `ValueKey` for stable UI automation
- the task requires deciding whether a UI interaction should be automated or left for manual verification
- the task is developing or modifying a feature that is suitable for desktop UI testing in this project

Do not use this skill when:

- the task is isolated logic that cannot affect desktop client behavior, native user flows, or visible outcomes
- the task is only a web app verification request
- the task is a simple static code review unrelated to desktop UI execution

## Hard Rules

### 1. Always test the native desktop client

For this repository, UI testing must target the **native desktop app**, not the web build.

Required behavior:

- prefer native device targets such as `windows`, `macos`, or `linux`
- use `mcp_dart.list_devices` first, then choose a native desktop device
- launch the app with `mcp_dart.launch_app`
- if UI control is needed, use a driver-enabled native entrypoint such as `lib/driver_main.dart`

Forbidden behavior:

- do not use `chrome`
- do not use `edge`
- do not switch to web just because web is easier to automate
- do not claim desktop UI is verified if only the web version was tested

Additional expectation:

- when implementing features that are suitable for desktop UI testing, proactively use this skill to run native-client UI verification instead of waiting for the user to explicitly remind you

## 2. Build testability in during implementation

Do not wait until the testing phase to discover that the UI is hard to control.

When writing or modifying UI code, proactively add stable automation anchors to key interactive widgets.

Priority targets for `ValueKey`:

- primary navigation items
- login / logout buttons
- primary submit buttons
- critical toggles and switches
- player controls
- detail-page primary actions such as play / continue play
- list items or cards that are expected to be clicked in tests
- dialog confirm / cancel actions when they are important to flows

Good rule of thumb:

- if a widget is critical to a main user path and may be used in automation, give it a stable `ValueKey`

Avoid weak selectors:

- text-only selectors for frequently changing copy
- structure-based assumptions about widget nesting
- selectors that depend on hover-only state if a stable key can be added without changing product behavior

## 3. Never change product behavior just to satisfy automation

Do not modify the real interaction design merely because MCP or automation has difficulty operating it.

Examples of unacceptable changes:

- changing a hover-only control to tap-open only for easier testing
- simplifying real interaction flows just to make automation pass
- adding non-product behavior that users do not actually have

Correct fallback:

- if the real interaction is hard to automate with MCP and should remain as designed, keep the product behavior unchanged
- explain the automation limitation clearly
- ask the user to perform that part manually
- report which steps were automated and which steps require manual verification

Manual-test escalation is preferred over changing requirements.

## Recommended Execution Workflow

### Step 1. Confirm native target

- run `mcp_dart.list_devices`
- choose `windows`, `macos`, or `linux`
- do not choose browser targets

### Step 2. Confirm entrypoint

- use the normal entrypoint when only launching is required
- use a driver-enabled entrypoint when `flutter_driver` commands are required
- keep the app logic the same; only add a dedicated driver entrypoint when needed

Recommended pattern:

- extract shared bootstrap logic into a reusable entrypoint like `lib/app.dart`
- keep `lib/main.dart` for normal startup
- keep `lib/driver_main.dart` for driver-enabled startup

## Step 3. Connect runtime tooling

- launch with `mcp_dart.launch_app`
- connect using `mcp_dart.connect_dart_tooling_daemon`
- confirm the app instance with `mcp_dart.list_running_apps`

## Step 4. Inspect before acting

Before trying to tap anything:

- inspect with `mcp_dart.get_widget_tree`
- use actual runtime tree data to decide finders
- prefer `ByValueKey` for stable interactions
- use `ByText`, `ByTooltipMessage`, or `ByType` only when appropriate

Recommended finder priority:

1. `ByValueKey`
2. `ByTooltipMessage`
3. `ByText`
4. `ByType`

## Step 5. Verify user-visible evidence

Do not treat a successful command response as enough.

Always verify with one or more of:

- another `waitFor`
- screenshot evidence
- visible text change
- page title change
- widget tree state change
- runtime logs when relevant

If screenshots are captured for testing:

- use them only as temporary verification artifacts
- delete them immediately after the verification result is confirmed
- do not leave test screenshots in the repository or workspace after the task is done

## Step 6. Check runtime issues

After important actions:

- inspect `mcp_dart.get_runtime_errors`
- inspect app logs if behavior is suspicious

## Project-Specific Lessons

### Successful patterns from this repository

- navigation items already work well when they have stable keys
- desktop native startup can be verified with `mcp_dart.launch_app`
- `flutter_driver` works better when critical controls have `ValueKey`
- screenshots are useful to confirm whether the app is on the home page, detail page, or player page
- player flow often benefits from using `ByType` for custom composed widgets when text finders are not stable enough

### Known caution points

- this project is a desktop client, so web verification is not an acceptable substitute
- some `mcp_dart.flutter_driver` commands may behave inconsistently with certain parameter combinations; avoid assuming the tool is wrong until you verify with widget tree and screenshots
- a successful desktop launch may still fail if the Windows build artifacts are locked by a stale process; clear stale native processes before retrying

## Implementation Guidance For New Code

When adding or updating desktop UI features:

- add `ValueKey` as part of the initial implementation, not as a late testing patch
- add keys only to meaningful interaction points, not every widget
- keep key names stable and intention-revealing

Suggested naming style:

- `nav-home`
- `settings-logout`
- `login-submit`
- `player-play-pause`
- `player-speed-control`
- `player-volume-control`

Avoid:

- random key names
- unstable index-based names when a semantic name is possible
- renaming keys casually without updating tests

## Decision Rules For Automation vs Manual Testing

Automate when:

- the interaction can be controlled without changing product behavior
- a stable `ValueKey` or reliable runtime finder exists
- the result can be verified with visible evidence

Escalate to manual testing when:

- the interaction depends on real hover behavior or complex OS-level input that MCP cannot reproduce reliably
- automating it would require changing the intended UX
- the interaction is blocked by tool limitations rather than code quality

When escalating, report clearly:

- what was automated successfully
- what could not be automated
- why it should remain manual
- what manual verification steps the user should perform

## Output Expectations

When using this skill, provide:

- the native target used
- the entrypoint used
- what flows were automated
- what evidence confirmed success
- what required manual verification, if any
- whether new `ValueKey` were added and why
- whether any proposed change was rejected because it would alter real product behavior
- whether temporary test screenshots were cleaned up

## Short Checklist

- [ ] Native desktop target selected
- [ ] Web target avoided
- [ ] Driver-enabled entrypoint used when needed
- [ ] Widget tree inspected before interaction
- [ ] `ByValueKey` preferred for key actions
- [ ] Critical UI already has `ValueKey`, or a minimal product-safe key was added
- [ ] No UX behavior was changed just for test convenience
- [ ] Manual verification requested when MCP could not reproduce the real interaction
- [ ] Runtime errors checked
- [ ] Evidence captured with screenshots or visible state changes
- [ ] Temporary test screenshots deleted immediately after verification
