## ADDED Requirements

### Requirement: STF SHALL remain the device state source of truth
Mobile Matrix SHALL obtain device presence, readiness, ownership and remote-control information from the vendored STF runtime and SHALL NOT claim a device is ready from a stale browser or service cache.

#### Scenario: STF reports an available device
- **WHEN** STF reports a device as present, ready and not in use
- **THEN** the device matrix exposes that device as available and retains the STF fields needed to explain the state

#### Scenario: STF becomes unreachable
- **WHEN** the App or WebSocket cannot obtain current STF device state
- **THEN** the console shows a disconnected or unknown dependency state and does not reuse an old ready assertion

### Requirement: The device matrix SHALL expose current device details
The STF-integrated console SHALL expose stable identity, Android platform, provider information when available, current state, owner information and diagnostic fields needed to explain that state. The trusted-local profile uses one fixed STF identity and SHALL NOT imply per-browser authorization.

#### Scenario: Browser lists devices
- **WHEN** the transparent local session connects to the device tracker
- **THEN** the console renders the current STF device set using the Mobile Matrix device matrix

#### Scenario: A device is absent
- **WHEN** STF reports `present=false` for a known device
- **THEN** the console presents it as offline and does not enable a new lease action

#### Scenario: A device is present but not ready
- **WHEN** STF reports a present device whose provider is not ready
- **THEN** the console presents an unavailable state and keeps the raw readiness explanation

### Requirement: Users SHALL be able to lease and release one device
The console SHALL retain STF's existing single-device occupy and release operations. In the trusted-local profile, the current user is the fixed local STF administrator identity.

#### Scenario: Lease an available device
- **WHEN** the target is present, ready and available and STF accepts the group invite
- **THEN** the console enters the existing single-device control flow without creating a second local lease record

#### Scenario: Lease a busy device
- **WHEN** the target is already in use
- **THEN** the console shows a deterministic busy state and does not attempt an unsafe second lease

#### Scenario: Release the current lease
- **WHEN** the fixed local identity releases a device it owns
- **THEN** the console invokes STF group kick and reflects the resulting current state

### Requirement: Remote control SHALL remain explicit and single-device
The console SHALL enter the existing STF `/control/:serial` route only after the user explicitly chooses one usable device. Batch remote connection is outside this change.

#### Scenario: Open an available device
- **WHEN** the user activates an available device card outside multi-select interaction
- **THEN** the console navigates to the existing single-device control route

#### Scenario: Open an unavailable device
- **WHEN** a device is absent, not ready or owned incompatibly
- **THEN** the card does not present a false usable control target

### Requirement: Credentials SHALL remain server-side
The integrated console SHALL NOT send an STF Bearer Token, ADB key, cookie secret or complete remote connection address into ordinary browser storage or logs.

#### Scenario: Browser performs a device operation
- **WHEN** the console invokes an STF WebSocket group operation
- **THEN** it uses the server-established cookie session and the response contains no server credential

#### Scenario: An operation fails
- **WHEN** STF rejects or times out an operation
- **THEN** the console shows a stable safe error without including a Token, authorization header, ADB key or cookie secret
