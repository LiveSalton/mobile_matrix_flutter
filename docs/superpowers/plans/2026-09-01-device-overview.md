# Device Overview implementation plan

## Goal

Make `设备总览` the default page, render all ADB-available devices in an independently interactive responsive grid, and reuse the same per-serial sessions when entering the existing single-device control workspace.

## Bounded work sequence

1. Move FPS state into the model layer and add preview-quality projection support.
2. Introduce `DeviceSession` and `DeviceSessionManager` with one shared STF Lite runtime, serial-keyed reuse, five-second scanning, and two-miss removal.
3. Refactor the single-device control page and screen stage to consume shared sessions while preserving keyboard, touch mapping, navigation, and full-quality detail behavior.
4. Add the overview page and preview card grid with stable geometry, responsive breakpoints, per-card interaction, and serial-keyed navigation.
5. Complete localization, route documentation, tests, formatting, analysis, and targeted runtime verification.

## Acceptance boundaries

- No card may stretch a phone image or create horizontal overflow at the approved width breakpoints.
- A preview card can only send touch/navigation events to its own serial.
- Opening and closing a detail console must not create another STF Lite runtime or duplicate a session.
- Preview streams use a longest-edge cap of 720 pixels; the detail console restores the full profile.
- New visible text is present in both ARB files and generated localization code.
