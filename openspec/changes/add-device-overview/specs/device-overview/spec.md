# Device overview

## ADDED Requirements

### Requirement: The application must open on a multi-device overview

The application MUST open on a `Device Overview` page that lists all ADB-available Android devices and MUST retain the existing single-device control workspace as a detail destination.

#### Scenario: The application starts with multiple devices

- **WHEN** the app starts and multiple ADB-available devices are discovered
- **THEN** the default page shows a preview card for every device
- **AND** each card provides an action to open that device in the existing single-device control workspace

### Requirement: The overview grid must be responsive and overflow-safe

The overview MUST use four columns from a 1024px logical window width and reduce to three, two, and one column as the available width decreases. The grid MUST preserve a minimum card width and MUST NOT produce horizontal overflow, zero-size render rectangles, or negative layout constraints.

#### Scenario: The user resizes the application

- **WHEN** the application width crosses the overview breakpoints
- **THEN** the grid changes its column count without stretching a device image
- **AND** cards in the same row share the same compact outer height and width
- **AND** each live preview uses a shared compact width target within the card
  without changing its native aspect ratio, with the preview and reduced-height
  bottom navigation aligned to the bottom
- **AND** the page remains vertically scrollable and free of layout overflow errors

### Requirement: Each device preview must have isolated live control

Every preview card MUST own or reference a session identified by the device serial, and pointer gestures and bottom navigation actions MUST be sent only to that session. All ADB-available devices MUST start a preview stream by default when the overview is active.

#### Scenario: The user operates one card among several

- **WHEN** the user taps, swipes, or presses a bottom navigation action on device A's card
- **THEN** only device A receives the corresponding control event
- **AND** devices B and C continue their own streams without receiving the event

#### Scenario: The user types into one preview card

- **WHEN** the user presses the screen of device A's card and then types on the computer keyboard
- **THEN** only device A receives the raw keyboard events
- **AND** the keyboard bridge remains local to the focused card without creating a global input surface

### Requirement: Overview and detail views must reuse device sessions

Opening the single-device control workspace from a preview card MUST reuse the existing device session and shared STF Lite runtime. Navigation MUST NOT start duplicate sidecars, control sockets, or screen streams for the same serial.

#### Scenario: The user enters and leaves the detailed workspace

- **WHEN** the user selects `进入控制台` for a preview card and later returns to the overview
- **THEN** the selected device remains associated with the same session identity
- **AND** the other device sessions remain isolated and recoverable

### Requirement: Preview rendering must preserve device geometry

The preview MUST use the device display dimensions and rotation to preserve aspect ratio. Preview quality MAY be reduced for performance, but the image MUST NOT be stretched or filled into an incompatible rectangle.

#### Scenario: A device rotates to landscape

- **WHEN** a device reports a landscape rotation
- **THEN** its preview and touch coordinate mapping use the rotated viewport
- **AND** the displayed screen remains proportional

### Requirement: Per-device failures must not collapse the overview

A device stream or control failure MUST be represented inside that device's card and MUST NOT remove or break other healthy cards. The overview MUST retain actionable states for scanning, no devices, runtime failure, disconnected devices, and stream errors.

#### Scenario: One device disconnects

- **WHEN** one device disconnects while other devices remain available
- **THEN** that card shows a localized disconnected state with disabled controls or retry guidance
- **AND** the remaining cards continue rendering and accepting input

### Requirement: Overview strings must follow the localization contract

All new user-visible overview strings MUST be present in both Simplified Chinese and English ARB resources with matching keys, placeholders, and descriptions. The overview MUST NOT add user-visible hard-coded strings inside Widgets.

#### Scenario: The locale changes or localization is audited

- **WHEN** the overview is rendered in either supported locale
- **THEN** all visible overview labels and statuses resolve through `L10n`
- **AND** the two locale files have matching overview keys and placeholders
