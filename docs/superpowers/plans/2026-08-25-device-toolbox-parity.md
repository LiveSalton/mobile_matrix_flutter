# Device Toolbox Web Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter desktop device toolbox to parity with the seven device-tool groups already present in the Web project.

**Architecture:** Keep `IDeviceControlService` focused on screen input and existing clipboard/text control. Add a separate `DeviceToolsService` plus pure models/parsers for ADB-backed tools, then make `DeviceWorkspace` a responsive navigation shell with one scrollable tool surface at a time. Web-only JavaScript/VNC remain explicit desktop deviations, while screenshots continue to use the existing clipboard-only service.

**Tech Stack:** Flutter desktop, Dart `dart:io`, existing ADB/STF transport, Flutter Material widgets, `flutter_test` for pure parsing/validation behavior.

**Spec:** `openspec/changes/device-toolbox-parity/specs/device-toolbox/spec.md`

## Global Constraints

- Keep the existing `1120×760` minimum desktop window and do not add a group-control tab.
- Screenshots are PNG-to-system-clipboard only; never save screenshot files or start video recording.
- Preserve the existing STF screen stream, raw keyboard bridge, clipboard paste ordering, and touch transport.
- Use ADB as the desktop transport for the new Web tool mappings; report single-command failures in the UI.
- Preserve unrelated worktree changes and do not modify `AGENTS.md`.

### Task 1: Add pure device-tool models and parsers

**Files:**
- Create: `lib/models/device_tool_models.dart`
- Create: `lib/services/device_tool_parsers.dart`
- Test: `test/device_tool_parsers_test.dart`

**Interfaces:**
- `DeviceToolKind`, `DeviceToolResult`, `DeviceFileEntry`, `DeviceInfoSnapshot`, `DevicePortForward`, `DeviceRingerMode` are consumed by the service and UI.
- `DeviceToolParsers.parseDirectoryListing(String, String)` returns `List<DeviceFileEntry>`.
- `DeviceToolParsers.parseProperties(String)` returns `Map<String, String>`.
- `DeviceToolParsers.validatePort(String)` returns a validated integer or `null`.

- [x] Write tests for directory parsing, property parsing, and invalid/valid port input.
- [x] Run `flutter test test/device_tool_parsers_test.dart` and observe failure because the parser does not exist.
- [x] Implement the smallest immutable model and parser API needed by later tasks.
- [x] Run the focused test again and confirm it passes.

### Task 2: Add the ADB device-tools service

**Files:**
- Modify: `lib/services/adb_service.dart`
- Create: `lib/services/device_tools_service.dart`
- Test: `test/device_tools_service_test.dart`

**Interfaces:**
- `DeviceToolsService({required String serial})` exposes `runShell`, `loadInfo`, `listDirectory`, `pullFile`, `installApk`, `uninstallPackage`, `listPackages`, `setRingerMode`, `setWifiEnabled`, `setBluetoothEnabled`, `clearBluetoothBonds`, `openAppStore`, `enableRemoteDebug`, `createPortForward`, `removePortForward`, `testPortForward`, `reboot`, `startLogcat`, and `stopLogcat`.
- `DeviceToolsService.logLines` is a broadcast stream of logcat lines.
- `AdbService.executeHostCommand`, `installApk`, `pullFile`, `startLogcat` are the host-side primitives used by the service.

- [x] Write tests for port validation and shell-result failure mapping before service implementation.
- [x] Run the focused tests and confirm the missing service/API failure.
- [x] Implement ADB host commands, logcat ownership, and info aggregation with safe result objects.
- [x] Run focused tests and confirm command validation and cleanup behavior pass.

### Task 3: Extend advanced key mappings

**Files:**
- Modify: `lib/services/device_control_service.dart`
- Test: `test/device_key_mapping_test.dart`

**Interfaces:**
- Add Web advanced key actions to `DeviceKeyAction` and map them through `AdbDeviceControlService.keyPress`.
- Keep existing actions and `MockDeviceControlService` behavior source-compatible.

- [x] Write a mapping test for media, mute, camera, search, charset, and D-pad actions.
- [x] Run it and observe failure for the missing enum cases.
- [x] Add the enum values and Android keycode mapping.
- [x] Run the mapping test and confirm it passes.

### Task 4: Rebuild the toolbox surface

**Files:**
- Modify: `lib/views/control/device_control_page.dart`
- Modify: `lib/views/control/widgets/device_workspace.dart`
- Modify: `lib/services/screen_capture_service.dart`

**Interfaces:**
- `DeviceControlPage` owns one `DeviceToolsService` per current serial and disposes it on device change/page dispose.
- `DeviceWorkspace` receives `DeviceToolsService` and renders the seven `DeviceToolKind` surfaces.

- [x] Add the service to page lifecycle and pass it into the workspace.
- [x] Replace the single dashboard list with navigation + one scrollable content pane.
- [x] Implement Dashboard, Logs, Screenshots, Automation, File Explorer, Advanced, and Info cards with loading/error feedback.
- [x] Keep screenshot action icon-only in the fixed left device information bar and reuse clipboard-only capture.
- [x] Use `Expanded`, `Wrap`, `ConstrainedBox`, and scroll views so the minimum window cannot produce overflow.

### Task 5: Verify and synchronize specifications

**Files:**
- Modify: `openspec/changes/device-toolbox-parity/reference-packet.json`
- Modify: `openspec/changes/device-toolbox-parity/tasks.md`
- Test: `test/device_tool_parsers_test.dart`, `test/device_tools_service_test.dart`, `test/device_key_mapping_test.dart`

- [x] Run focused tests, then `flutter analyze` on changed Dart files.
- [x] Run format and `git diff --check`.
- [x] Run Reference Packet and traceability validators.
- [x] Re-read the spec and mark only evidence-backed tasks complete; leave connected-device and visual acceptance explicitly for the user.
