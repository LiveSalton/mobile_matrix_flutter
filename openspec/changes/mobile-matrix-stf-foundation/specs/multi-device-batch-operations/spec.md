## ADDED Requirements

### Requirement: Batch targets SHALL be explicit current-page selections
The device matrix SHALL accept a deduplicated, non-empty selection of currently tracked STF serials for batch occupy and release operations. Selection SHALL remain in page memory and SHALL be cleared on refresh, route exit or leaving multi-select mode.

#### Scenario: User selects valid devices
- **WHEN** the user explicitly selects one or more visible device cards
- **THEN** the console shows the selected count and enables only batch actions valid for the current operation state

#### Scenario: No device is selected
- **WHEN** the selection is empty
- **THEN** batch action buttons remain disabled and no STF mutation occurs

#### Scenario: User leaves multi-select mode
- **WHEN** the user exits multi-select mode
- **THEN** the console clears the selection and does not persist serials in browser storage

### Requirement: Batch occupy SHALL return per-device outcomes
The console SHALL reuse `GroupService.invite` for every selected device and SHALL report a safe result for every requested serial.

#### Scenario: All selected devices are ready
- **WHEN** every selected device is present, ready and leasable
- **THEN** the result reports every serial as succeeded and contains no hidden per-device failure

#### Scenario: One selected device is busy
- **WHEN** one target is already owned while other targets are leasable
- **THEN** available targets can succeed, the busy target is reported as failed, and the aggregate is a partial failure

#### Scenario: One selected device goes offline
- **WHEN** one target disconnects before its operation completes
- **THEN** that target is reported as failed while results for other targets remain visible

### Requirement: Batch release SHALL preserve independent results
The console SHALL reuse `GroupService.kick` for selected devices and SHALL retain an independent outcome for each target.

#### Scenario: Mixed releasable and unreleasable targets
- **WHEN** the selection contains both a lease controlled by the fixed local identity and an unreleasable device
- **THEN** the releasable target can succeed and the other target returns a deterministic failure

#### Scenario: One release request times out
- **WHEN** a single STF group operation times out or rejects
- **THEN** only that target is marked failed and sibling results are not erased

### Requirement: Batch operations SHALL prevent duplicate submission
The console SHALL disable batch action controls while an accepted batch is running and SHALL NOT blindly submit the same page action twice.

#### Scenario: User clicks during an active batch
- **WHEN** a batch occupy or release is in progress
- **THEN** both batch action controls are disabled and the second activation causes no STF mutation

#### Scenario: Batch completes
- **WHEN** all accepted target promises settle
- **THEN** the console restores controls and displays total, succeeded, failed and per-device outcomes

### Requirement: Batch operations SHALL enforce bounded concurrency
The console SHALL schedule per-device STF group operations with a fixed positive concurrency limit so a large selection cannot emit an unbounded burst.

#### Scenario: Selection exceeds the concurrency limit
- **WHEN** the selected device count is larger than the in-flight limit
- **THEN** the scheduler starts no more than the configured limit simultaneously and eventually returns one result per target
