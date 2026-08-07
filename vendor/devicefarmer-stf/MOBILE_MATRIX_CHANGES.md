# Mobile Matrix STF Vendor Record

## Upstream source

- Project: DeviceFarmer STF
- Repository: `https://github.com/DeviceFarmer/stf.git`
- Tag: `v3.7.9`
- Commit: `36d1a3e4336f2ecdf7885e3644fe34d0a4282c87`
- Copied: 2026-08-07
- License: Apache-2.0, retained in `LICENSE`

The upstream Git metadata and dependency cache are intentionally excluded. Source files and upstream copyright headers are retained directly in this directory so Mobile Matrix can maintain a fixed, reviewable fork without a submodule or runtime dependency on a globally installed `stf` command.

## Mobile Matrix changes

- Add an explicit trusted-local `no-auth` profile that creates the fixed STF administrator session without showing the Mock login page.
- Make the STF device list the Mobile Matrix home console.
- Add `default` liquid-glass blue and `roseGlow` theme tokens from the project theme specification.
- Replace the upstream STF wordmark icon with the Mobile Matrix modular pixel-M brand icon at the existing 128px and 512px resource paths, and reuse it across the device-page title bar, global navigation, sign-in pages and browser icon entry points.
- Remove the title-bar wrapper border and map the brand icon color to the active `default` or `roseGlow` theme through a semantic CSS token.
- Rename runtime brand assets to `mobile-matrix-128.png` and `mobile-matrix-512.png`, explicitly declare the web favicon, and remove the old STF favicon entry points.
- Add a theme-token-based `mm-socket-modal` style for the socket disconnect dialog while preserving STF reconnect and dismiss behavior.
- Blend the title-bar icon into the active page background and switch between blue and rose favicon assets when the theme changes.
- Add visible device selection and bounded batch occupy/release operations using STF's existing group ownership semantics.
- Keep the legacy stats listener tolerant of the removed "using" counter so the compact summary does not interrupt device-card insertion.
- Use STF `screen.capture` for one static current-screen cover per device, refreshed only by the Mobile Matrix title-bar action; avoid a live screen stream on the device grid.
- Route local provider, WebSocket and storage-plugin URLs through the configured loopback `--public-ip` instead of hard-coded `localhost`, so Mac screenshot resources do not stall on IPv6 resolution.
- Point the image and APK processors directly at the local 7102 storage service, and pass through untransformed JPEG screenshots to avoid a hanging ImageMagick stream on macOS.
- Keep single-device control, Provider, ADB, STFService, minicap and minitouch behavior upstream-compatible.

## Security boundary

The no-login profile is intended only for a loopback-bound local development console. It is not anonymous multi-user authentication and must not be exposed to an untrusted network. A non-local deployment must re-enable real authentication in a separate reviewed change.
