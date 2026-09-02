# Design: device overview page

The approved design is documented in [the device overview design document](../../../docs/superpowers/specs/2026-09-01-device-overview-design.md).

## Key decisions

1. Use `设备总览` / `Device Overview` as the default entry.
2. Use a shared `DeviceSessionManager` with one STF Lite runtime and one isolated session per device serial.
3. Start all ADB-available device preview streams by default.
4. Use four columns from a 1024px logical window width and responsive reduction to three, two, or one column.
5. Make preview cards directly interactive for pointer gestures and device navigation keys.
6. Keep computer keyboard input scoped to the device whose preview screen was
   pressed; use a local invisible keyboard bridge per preview card and never
   broadcast keyboard events from the overview.
7. Reuse the same session when entering the detailed control workspace.
8. Bound preview projection quality to a 720-pixel longest edge to limit multi-device load.
9. Build the overview as compact row-level equal-height preview slots: each card
   keeps the same width and height in a row, the live screen uses a shared compact
   width target without changing aspect ratio, and the screen plus reduced-height
   bottom navigation is bottom-aligned.
