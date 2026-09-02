# Device Overview design

Status: approved in conversation on 2026-09-01. This document records the design before implementation.

## Summary

Add a multi-device preview page named **设备总览** (`Device Overview`) and make it the default application entry. The page shows every ADB-available Android device in a responsive grid, starts a live preview stream for each device, and lets the user operate each phone directly with pointer gestures and the existing bottom navigation bar. A button above each device opens the existing single-device control workspace for that same device session.

## Goals

- Give the user an immediate overview of all available Android devices.
- Keep every preview independently interactive and bound to the correct device serial.
- Reuse the existing screen renderer, touch coordinate mapping, and virtual navigation bar.
- Preserve the existing single-device control workspace as the detailed control surface.
- Keep the layout stable during window resizing and device connection changes.
- Make the multi-device view safe to run by default through a lower-cost preview stream profile.

## Non-goals

- No batch/broadcast operation across multiple devices.
- No global keyboard broadcasting from the overview page.
- No replacement of the existing single-device tools, dashboard, logs, automation, file, or information views.
- No new Android client application.
- No claim that Windows or Linux releases are supported by this feature.

## Product naming and navigation

Use the following visible name:

- Chinese: `设备总览`
- English: `Device Overview`

The application starts at `DeviceOverviewPage`. The existing `DeviceControlPage` remains the single-device control workspace and is opened from a device card's `进入控制台` action. The overview and control workspace share one session manager, so navigation does not recreate ADB control channels or screen streams.

## User experience

```text
┌────────────────────────────────────────────────────────────────────┐
│ Mobile Matrix     设备选择 / 刷新 / 主题                          │
├────────────────────────────────────────────────────────────────────┤
│ 设备总览                                             已连接 4 台   │
│                                                                    │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐ │
│ │ BVL_AN16 ●   │ │ 2206123SC ●  │ │ 24117RK2CG ● │ │ Pixel ●    │ │
│ │ 进入控制台   │ │ 进入控制台   │ │ 进入控制台   │ │ 进入控制台 │ │
│ │              │ │              │ │              │ │            │ │
│ │  实时手机画面│ │  实时手机画面│ │  实时手机画面│ │ 实时画面   │ │
│ │              │ │              │ │              │ │            │ │
│ │ 菜单 首页 任务 返回 │ 菜单 首页 任务 返回 │ 菜单 首页 任务 返回 │ ...        │
│ └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘ │
│                              ↓ 纵向滚动                          │
└────────────────────────────────────────────────────────────────────┘
```

### Device preview card

Each card has four fixed responsibilities:

1. **Header**: device name, connection indicator, resolution, and `进入控制台` button.
2. **Preview**: a live screen rendered with the device's real aspect ratio and current rotation.
3. **Interaction**: pointer down/move/up events map to that card's device session only.
4. **Navigation**: the existing menu, home, app switch, and back buttons remain at the bottom of the card.

The console button is outside the pointer listener for the screen area. A failed stream leaves the header and card geometry in place and replaces only the preview content with its status state.

### Responsive grid

Use a layout builder or sliver grid with a minimum card width and fixed gaps. The target column counts are:

- `>= 1024px`: 4 columns.
- `960px – 1023px`: 3 columns.
- `640px – 959px`: 2 columns.
- `< 640px`: 1 column.

The grid scrolls vertically. It never forces a card below its minimum width, never creates a horizontal overflow, and never gives a card a negative or zero render size during window resizing. The application header remains fixed while the device grid scrolls.

## Architecture

The current page owns one current device and one set of services. That ownership must move into a shared session layer:

```text
MobileMatrixApp
└── DeviceSessionManager
    ├── one StfLiteRuntimeService
    ├── DeviceSession(serial A)
    │   ├── DeviceModel
    │   ├── SmartScreenStreamService
    │   ├── StfLiteDeviceControlService
    │   ├── DeviceToolsService
    │   └── ScreenFpsStats
    ├── DeviceSession(serial B)
    └── ...
```

### DeviceSession

`DeviceSession` is the lifecycle boundary for one serial number. It owns the stream service, control service, device tools service, FPS notifier/metrics, and connection state. It exposes no UI widgets and does not depend on `views`.

`ScreenFpsStats` currently lives beside the renderer in the view layer. Move this pure data type to `lib/models/screen_fps_stats.dart` so the session layer can expose per-device FPS without violating `Views -> Services -> Models` dependency direction.

### DeviceSessionManager

`DeviceSessionManager` is a `ChangeNotifier`-style coordinator in `lib/services/`:

- starts and owns one shared STF Lite runtime;
- scans ADB devices on startup and approximately every five seconds;
- creates a session for each ADB-available device;
- updates device metadata without rebuilding unchanged sessions;
- disposes sessions for devices that have been absent long enough to be considered removed;
- exposes the session list to both `DeviceOverviewPage` and `DeviceControlPage`;
- disposes all sessions, timers, and the shared runtime when the app exits.

The manager must key all session maps and callbacks by the device serial, never by grid index.

### Existing single-device workspace

`DeviceControlPage` receives a manager/session identity instead of creating a private runtime and private services. Existing tools continue to operate on the selected session. Entering and leaving the page does not duplicate the sidecar, control socket, or screen stream.

## Screen streaming and performance

All ADB-available devices start a preview stream when the overview becomes active. To keep this usable with several devices:

- Add a `preview` stream quality/profile to the screen stream service.
- The preview profile derives its projection from the card viewport and caps the longest requested edge at 720 pixels.
- The single-device control workspace uses the existing/full profile for the active device.
- When a device is opened in the control workspace, its session is promoted to full quality; other sessions remain at preview quality.
- Returning to the overview restores the active session to preview quality.
- Each stream reconnects independently with bounded retry delays.
- A stream error must not stop another device's stream or the shared runtime.

FPS state is per session. The overview may show FPS in the card header only if the existing renderer has a valid measurement; an unavailable value uses a stable placeholder and must not change card width.

## Input behavior

- Pointer gestures on a preview card are routed to that card's control service.
- The existing `ScalingCoordinator` remains responsible for mapping the displayed rectangle to device coordinates.
- The device's rotation is passed into both projection and coordinate mapping.
- The four bottom navigation buttons call the same device-specific key actions as the current single-device stage.
- Overview cards do not install a global raw keyboard bridge. Each card may focus its own invisible raw keyboard bridge after the user presses that card's phone screen, so computer keyboard input is routed only to the selected device.
- `进入控制台` is a normal page action and cannot be interpreted as a screen gesture.

## State and error handling

Every card keeps a stable shell while its content changes between these states:

- `connecting`: loading placeholder with device identity.
- `streaming`: live image and enabled navigation bar.
- `paused`: stable paused placeholder with disabled screen interaction.
- `unauthorized` or unavailable session: authorization guidance and disabled controls.
- `disconnected`: offline status, retry indication, and disabled controls.
- `error`: localized error message and per-card retry indication.

The overview itself has separate states for scanning, no ADB-available devices, runtime unavailable, and ready. A runtime failure can prevent all streams, but the page must still show an actionable empty/error state and refresh action rather than a blank body.

## Internationalization and visual rules

- Add all new visible strings to both `intl_zh.arb` and `intl_en.arb`, including descriptions and matching placeholders.
- Use Chinese for visible UI in the current locale; use English Tooltip text for icon-only controls where the existing product convention requires it.
- Use existing `context.tokens`, card radius, outlines, and spacing. No new hard-coded colors.
- Keep header, preview, and navigation heights stable so FPS changes, stream errors, and status text do not make cards jump.
- Keep the existing phone screen ratio behavior; never use a fill fit that distorts the image.

## Implementation file plan

### New files

- `lib/models/screen_fps_stats.dart`
- `lib/services/device_session.dart`
- `lib/services/device_session_manager.dart`
- `lib/views/overview/device_overview_page.dart`
- `lib/views/overview/widgets/device_preview_card.dart`

### Modified files

- `lib/main.dart`
- `lib/services/screen_stream_service.dart`
- `lib/views/control/device_control_page.dart`
- `lib/views/control/widgets/device_screen_stage.dart`
- `lib/views/control/widgets/fast_screen_renderer.dart`
- `lib/l10n/intl_zh.arb`
- `lib/l10n/intl_en.arb`
- generated L10n files under `lib/l10n/intl/`
- `doc/page-route-book.md`

## Verification and acceptance

### Automated checks

- Unit-test session creation, reuse, removal, and disposal by serial.
- Widget-test column selection at the four responsive width bands.
- Widget-test that every card receives its own session and navigation callback.
- Widget-test preview rendering with portrait and landscape display metadata.
- Run `flutter analyze` and targeted tests after implementation.

### Manual acceptance

1. Launch the app with four ADB-available devices and confirm the default page is 4 columns.
2. Resize through wide, medium, narrow, and very narrow widths; confirm no overflow or assertion appears.
3. Touch and swipe each card and verify only that phone responds.
4. Use each card's bottom navigation buttons and verify the correct phone responds.
5. Open one card's single-device console, use its existing tools, then return without a duplicated stream or sidecar.
6. Disconnect one phone and confirm the other cards keep streaming and operating.
7. Rotate a device and confirm its preview keeps the correct aspect ratio without stretching.
8. Confirm preview FPS/status changes do not alter card width or grid alignment.
9. Confirm all new visible strings exist in both locales and no new Widget-level hard-coded user text was introduced.

## Rollout sequence

1. Extract the screen FPS model and shared session manager.
2. Move single-device ownership from `DeviceControlPage` into the manager.
3. Add the overview page and preview card using the existing stage behavior.
4. Add preview quality and route/session promotion.
5. Add localization, page-route documentation, widget/unit coverage, and manual runtime verification.
