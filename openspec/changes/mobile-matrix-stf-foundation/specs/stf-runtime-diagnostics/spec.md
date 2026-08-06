## ADDED Requirements

### Requirement: Health checks SHALL distinguish dependency layers
Mobile Matrix SHALL expose `GET /health` with separate health details for the control-plane process, STF API, Provider/ADB path and configuration/authentication state.

#### Scenario: All dependencies are healthy
- **WHEN** the process is running and STF, Provider and ADB checks succeed
- **THEN** `/health` reports the control plane healthy and identifies each checked dependency as healthy

#### Scenario: STF API is unavailable
- **WHEN** the control plane cannot reach the configured STF API
- **THEN** `/health` reports `stf_unreachable` without claiming the device layer is healthy

#### Scenario: Provider or ADB is unavailable
- **WHEN** STF is reachable but the provider/ADB path has no usable device connection
- **THEN** `/health` identifies `provider_unavailable` or the more specific dependency state instead of reporting a generic server failure

### Requirement: Device and operation failures SHALL use stable classifications
The control plane SHALL map dependency and device failures to stable codes including `stf_unreachable`, `provider_unavailable`, `device_offline`, `device_not_ready`, `device_busy`, `auth_failed`, `operation_timeout` and `partial_failure`.

#### Scenario: STF rejects the token
- **WHEN** an STF request returns an authentication failure
- **THEN** the API returns `auth_failed` and redacts the token from the response and logs

#### Scenario: Device operation cannot reach STF
- **WHEN** a lease, release or remote-connect operation cannot reach STF
- **THEN** the API returns `stf_unreachable` or `operation_timeout` according to the observed failure, not `device_offline` without evidence

#### Scenario: Batch has mixed results
- **WHEN** at least one target succeeds and at least one target fails
- **THEN** the aggregate result is `partial_failure` and retains each target's stable code

### Requirement: Mac validation SHALL use host ADB rather than USB container passthrough
The development validation profile SHALL run ADB on the Mac host and allow STF to consume that ADB path; it SHALL NOT require Docker Desktop direct USB passthrough.

#### Scenario: One Mac-connected device is available
- **WHEN** `adb devices` reports an authorized Android device and the Mac STF profile starts
- **THEN** the device can be observed through STF without a USB device mounted into a container

#### Scenario: Docker Desktop cannot access USB directly
- **WHEN** the Docker runtime has no direct USB device passthrough
- **THEN** the validation profile continues to use host ADB or reports an explicit setup blocker, and does not report a false device-ready state

### Requirement: Sensitive connection data SHALL be redacted
The diagnostics and operation logs SHALL omit STF tokens, ADB keys, complete remote connection addresses when not needed for the current response, and any user credentials.

#### Scenario: An operation fails with a remote-connect response
- **WHEN** logging the operation or returning an error after remote connection handling
- **THEN** the log and error omit secrets and retain only a redacted endpoint or stable diagnostic identifier

#### Scenario: A diagnostic snapshot is requested
- **WHEN** a client requests a health or device diagnostic snapshot
- **THEN** the snapshot includes dependency and device status but no STF token, ADB key or credential

### Requirement: The first profile SHALL remain a trusted single-identity service
The first Mobile Matrix profile SHALL rely on local or trusted-network access and the configured STF Token as its single service identity; it SHALL NOT claim per-user authorization or multi-tenant isolation.

#### Scenario: A request arrives in the trusted-local profile
- **WHEN** a caller uses a Mobile Matrix endpoint
- **THEN** the service applies the configured STF identity and does not present a separate per-user lease boundary

#### Scenario: The service is placed on an untrusted network
- **WHEN** deployment configuration would expose the first profile beyond the trusted boundary
- **THEN** the runbook and health diagnostics report that the deployment is unsupported rather than implying secure multi-user access
