## ADDED Requirements

### Requirement: STF is the device state source of truth
Mobile Matrix SHALL obtain device presence, readiness, lease ownership and remote connection information from the configured STF instance, and SHALL NOT claim a device is ready from a stale local cache.

#### Scenario: STF returns an available device
- **WHEN** STF reports a device as present, ready and not in use
- **THEN** `GET /api/v1/devices` exposes that device with Mobile Matrix status `ready` and retains the relevant STF lease fields

#### Scenario: STF is unreachable during a device query
- **WHEN** the adapter cannot reach STF while serving a device query
- **THEN** the response marks the device state as `unknown` or returns a dependency error classified as `stf_unreachable`, and does not reuse an old `ready` assertion

### Requirement: Mobile Matrix SHALL expose a normalized device API
The service SHALL expose `GET /api/v1/devices` and `GET /api/v1/devices/:serial`, including stable identity fields, Android platform, provider information when available, normalized status, and diagnostic STF fields needed to explain that status.

#### Scenario: Client lists devices
- **WHEN** an authenticated client requests `GET /api/v1/devices`
- **THEN** the service returns the current STF device set using the versioned Mobile Matrix model

#### Scenario: A device is absent
- **WHEN** STF reports `present=false` for a known device
- **THEN** the service returns status `offline` and does not present the device as ready for a new lease

#### Scenario: A device is present but not ready
- **WHEN** STF reports a present device whose provider is not ready
- **THEN** the service returns status `unavailable` and preserves the raw readiness information

### Requirement: Clients SHALL be able to lease and release one device
The service SHALL expose `POST /api/v1/devices/:serial/lease` and `DELETE /api/v1/devices/:serial/lease` as guarded operations backed by the corresponding STF user-device operations.

#### Scenario: Lease an available device
- **WHEN** the target is present, ready, available and the STF request succeeds
- **THEN** the service returns a successful lease result tied to that device and does not create a second local lease record

#### Scenario: Lease a busy device
- **WHEN** the target is already in use by another owner
- **THEN** the service returns `device_busy` without attempting an unsafe second lease

#### Scenario: Release the current lease
- **WHEN** the current client releases a device it owns
- **THEN** the service requests release from STF and returns a successful release result

#### Scenario: Release a device owned by someone else
- **WHEN** a client attempts to release a device it does not own
- **THEN** the service returns a deterministic ownership or `device_busy` error and leaves the STF lease unchanged

### Requirement: Remote connection SHALL be explicit and temporary
The service SHALL expose `POST /api/v1/devices/:serial/remote-connect`, return the STF-provided temporary ADB connection address only after verifying that the client owns or can use the device, and SHALL NOT persist that address in ordinary application storage or logs.

#### Scenario: Remote-connect an owned device
- **WHEN** the client owns an available STF device and requests remote connection
- **THEN** the service returns the STF remote connection address for the current session

#### Scenario: Remote-connect an unavailable device
- **WHEN** the device is absent, not ready or not owned by the client
- **THEN** the service returns a classified failure and does not expose a remote connection address

### Requirement: STF credentials SHALL remain server-side
Mobile Matrix SHALL inject STF authentication through server configuration and SHALL NOT send the STF Bearer Token to browser clients, device scripts or ordinary operation logs.

#### Scenario: Client calls a device API
- **WHEN** a client invokes any Mobile Matrix device endpoint
- **THEN** the control plane adds the server-side STF credential internally and the response contains no token

#### Scenario: STF rejects the credential
- **WHEN** STF returns an authentication failure
- **THEN** Mobile Matrix returns `auth_failed` without including the token or authorization header in the error body
