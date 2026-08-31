# Rename macOS application display name

## Why

macOS currently exposes the internal Flutter package name `mobile_matrix` as the
application name in Finder, Dock, and the window title. The user-facing name
should be `Mobile Matrix`.

## What Changes

- Set the macOS product and display name to `Mobile Matrix`.
- Keep the Dart package name `mobile_matrix` unchanged for source and dependency
  compatibility.
- Update macOS build, scheme, test-host, and release packaging references to
  follow the renamed `.app` bundle.

## Capabilities

### Modified Capabilities

- `macos-app-identity`: defines the user-facing macOS application name and the
  separation from the internal Dart package name.

## Impact

- macOS Xcode configuration, bundle metadata, and release packaging scripts.
- No Android, iOS, Flutter business logic, or runtime protocol behavior changes.
