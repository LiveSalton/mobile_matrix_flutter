## ADDED Requirements

### Requirement: Runtime checks SHALL distinguish STF dependency layers
The default runtime SHALL expose enough evidence to distinguish the STF process, App state endpoint, WebSocket, Provider/ADB path and transparent identity configuration without relying on a separate Mobile Matrix health service.

#### Scenario: All dependencies are healthy
- **WHEN** `7100` serves the App shell and state script, WebSocket connects and STF reports at least the observed Provider state
- **THEN** the console and runbook identify the checked layers as available

#### Scenario: STF is unavailable
- **WHEN** `7100` cannot be reached
- **THEN** the startup or validation command reports STF unavailable and does not claim the device layer is healthy

#### Scenario: Provider or ADB is unavailable
- **WHEN** the App loads but no usable Provider/ADB path exists
- **THEN** the console or startup log reports the dependency state rather than showing a fabricated ready device

### Requirement: Device and batch failures SHALL remain distinguishable
The integrated console SHALL distinguish offline, not ready, busy, authentication/session, timeout and partial-batch outcomes using safe UI messages and per-device results.

#### Scenario: Session establishment fails
- **WHEN** transparent local identity cannot be saved or loaded
- **THEN** the App request fails visibly and does not render a false authenticated device page

#### Scenario: Device operation cannot reach STF
- **WHEN** an occupy, release or remote-control action loses the STF dependency
- **THEN** the console reports dependency or timeout failure rather than claiming the device itself is offline without evidence

#### Scenario: Batch has mixed results
- **WHEN** at least one target succeeds and at least one target fails
- **THEN** the aggregate reports partial failure and retains every target result

### Requirement: Mac validation SHALL use host ADB rather than USB container passthrough
The development profile SHALL run ADB on the Mac host and allow the vendored STF Provider to consume that path; it SHALL NOT require Docker or Colima direct USB passthrough.

#### Scenario: One Mac-connected device is available
- **WHEN** `adb devices` reports an authorized Android device and the Mac STF profile starts
- **THEN** the device can be observed through the `7100` console without a USB device mounted into a container

#### Scenario: Container runtime cannot access USB directly
- **WHEN** the container runtime has no direct USB device passthrough
- **THEN** validation continues to use host ADB or reports an explicit setup blocker and never reports a false ready state

### Requirement: Sensitive connection data SHALL be redacted
Startup logs, page state and operation feedback SHALL omit STF Tokens, ADB private keys, cookie secrets, complete remote addresses when not needed, and any previous login credentials.

#### Scenario: An operation fails
- **WHEN** the console records a failed operation
- **THEN** the error retains a stable diagnostic message but contains no secret or complete remote endpoint

#### Scenario: Runtime state is requested
- **WHEN** the browser requests `/app/api/v1/state.js`
- **THEN** the state includes safe configuration and the fixed user view but no cookie secret, Token or ADB key

### Requirement: The default profile SHALL remain trusted and loopback-only
The no-login Mobile Matrix profile SHALL bind its public control entry to `127.0.0.1` and SHALL NOT claim secure anonymous access on an untrusted network.

#### Scenario: Root script starts the console
- **WHEN** `mobile-matrix.sh` starts STF
- **THEN** the console URL uses `127.0.0.1:7100` and documentation labels the profile local/trusted

#### Scenario: A deployment needs non-local access
- **WHEN** the operator wants to expose the console beyond the trusted host
- **THEN** the runbook requires a separate authentication/security change rather than recommending the no-login profile
