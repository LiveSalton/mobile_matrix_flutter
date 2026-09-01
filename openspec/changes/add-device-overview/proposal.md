# Add device overview page

## Why

The current application opens directly into a single-device control workspace. The device list already discovers multiple ADB devices, but only one device owns a screen stream and control service at a time. Users need a default overview that shows all available phone screens and allows direct per-device operation.

## What Changes

- Add `Device Overview` / `设备总览` as the default application page.
- Show ADB-available devices in a responsive `4 → 3 → 2 → 1` grid.
- Start independent preview streams and input sessions for all devices.
- Reuse the existing phone screen stage and bottom navigation bar in each card.
- Add a per-card action to open the existing single-device control workspace.
- Extract shared device session ownership so overview and detail views reuse the same runtime and device channels.
- Add preview stream quality, stable error states, and localized strings.

## Scope Boundary

- This is a desktop overview and per-device operation feature; it is not batch control.
- The overview does not broadcast keyboard input.
- It does not create a separate Android client or add Windows/Linux release support.
- It does not replace the existing device tools inside the single-device workspace.

## Impact

- New overview views and multi-device session services.
- Refactoring of single-device service ownership.
- Screen stream projection gains a preview quality profile.
- New Chinese and English localization keys.
- Page route documentation and targeted tests.
