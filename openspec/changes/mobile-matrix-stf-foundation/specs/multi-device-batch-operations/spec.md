## ADDED Requirements

### Requirement: Batch targets SHALL be explicit serial collections
Mobile Matrix SHALL accept a deduplicated, non-empty list of STF serials for batch lease and release operations, and SHALL reject malformed selectors before contacting STF.

#### Scenario: Client submits valid serials
- **WHEN** a client submits a non-empty list of unique serials
- **THEN** the service accepts the selector and evaluates each target independently

#### Scenario: Client submits an empty or duplicate selector
- **WHEN** a client submits no serials or repeats a serial
- **THEN** the service returns a validation error and does not perform partial STF mutations

### Requirement: Batch lease SHALL return per-device outcomes
The service SHALL expose `POST /api/v1/batch/lease` and SHALL return aggregate `accepted`, `succeeded`, `failed` collections plus a result and error classification for every requested serial.

#### Scenario: All selected devices are ready
- **WHEN** every selected serial is present, ready and leasable
- **THEN** the response reports every serial as succeeded and contains no hidden per-device failure

#### Scenario: One selected device is busy
- **WHEN** one target is already owned while other targets are leasable
- **THEN** the response reports the available targets as succeeded, the busy target as `device_busy`, and the aggregate as partial failure

#### Scenario: One selected device is offline
- **WHEN** one target is absent or disconnected
- **THEN** the response reports that target as `device_offline` while preserving the results of other targets

### Requirement: Batch release SHALL preserve ownership and independent results
The service SHALL expose `POST /api/v1/batch/release`, release only leases owned by the current client, and return an independent outcome for each target.

#### Scenario: Mixed owned and unowned targets
- **WHEN** the request includes both current-client leases and leases owned by another client
- **THEN** only current-client leases are released and unowned targets return deterministic failures

#### Scenario: One release request times out
- **WHEN** a single STF release call times out
- **THEN** the service marks only that target `operation_timeout` or a recheck-derived result and does not erase other target outcomes

### Requirement: Batch operations SHALL be safe under retry
The service SHALL avoid blind duplicate mutations: after an uncertain lease, release or remote operation, it SHALL re-read STF state before retrying and SHALL not create a second lease for one target.

#### Scenario: Lease call times out after STF accepted it
- **WHEN** the control plane times out after sending a lease request
- **THEN** it re-queries STF ownership before any retry and returns the observed ownership result

#### Scenario: Batch contains an already-owned target
- **WHEN** a retry includes a target already owned by the current client
- **THEN** the service reports it as already satisfied or a deterministic conflict and does not issue a second lease mutation

### Requirement: Batch API SHALL enforce bounded concurrency
The service SHALL apply a configured concurrency and timeout bound to batch calls so that one large request cannot exhaust the control plane or STF connection pool.

#### Scenario: Batch exceeds the concurrency limit
- **WHEN** a request includes more targets than the configured in-flight limit
- **THEN** the service schedules targets within the limit and returns per-device results after all accepted work completes or times out
