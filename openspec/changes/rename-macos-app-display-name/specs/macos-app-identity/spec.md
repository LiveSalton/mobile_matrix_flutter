# macOS application identity

## ADDED Requirements

### Requirement: Use the user-facing macOS product name

The macOS application SHALL use `Mobile Matrix` as its product and display
name, and the built bundle SHALL be named `Mobile Matrix.app`.

#### Scenario: Build the macOS application

- **WHEN** a Debug, Profile, or Release macOS build is produced
- **THEN** the application bundle name SHALL be `Mobile Matrix.app`
- **AND** the bundle `CFBundleName` and `CFBundleDisplayName` SHALL resolve to
  `Mobile Matrix`

### Requirement: Preserve the internal Dart package name

The project SHALL keep `mobile_matrix` as the Dart package name and SHALL NOT
rename source imports or package identifiers as part of this display-name
change.

#### Scenario: Resolve the Dart package

- **WHEN** Flutter resolves the project package
- **THEN** the package name SHALL remain `mobile_matrix`

### Requirement: Keep release tooling aligned

Release build and packaging scripts SHALL resolve the renamed macOS bundle
without requiring manual path edits.

#### Scenario: Package a release app

- **WHEN** the macOS release packaging script is run with its default output
- **THEN** it SHALL locate `Mobile Matrix.app`
