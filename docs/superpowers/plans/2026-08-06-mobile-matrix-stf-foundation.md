# Mobile Matrix STF Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. The OpenSpec change `mobile-matrix-stf-foundation` remains the progress source of truth; synchronize its `tasks.md` checkboxes after each completed task.

**Goal:** Build the first Mobile Matrix control plane that manages real Android devices through DeviceFarmer STF, with Mac-native ADB/STF validation and independently reported multi-device operations.

**Architecture:** Mobile Matrix is a small TypeScript HTTP control plane around a typed STF adapter. STF remains the only source of device presence, readiness, ownership, and remote-connect state; Mobile Matrix normalizes those fields, exposes versioned endpoints, aggregates serial-targeted batch operations, and reports dependency-layer health. The first runtime profile uses host ADB on the current arm64 Mac; Docker is not used for USB passthrough.

**Tech Stack:** Node.js 20 LTS runtime profile, TypeScript, Fastify, Node `fetch`, Node `node:test` with `tsx`, DeviceFarmer STF `3.7.9`, ADB, and RethinkDB.

## Global Constraints

- All requirements, decisions, tasks, and evidence stay synchronized in `openspec/changes/mobile-matrix-stf-foundation/`.
- STF `3.7.9` is pinned; do not use `latest` for the first validation profile.
- Prefer an isolated Node.js 20 LTS environment; do not replace the system Node.js 22.
- STF is the source of truth for device state and leases; do not create a duplicate bottom-layer device state database.
- STF Token, ADB keys, internal addresses, remote connection addresses, and credentials never enter source control, ordinary logs, or error bodies.
- The first deployment is local or trusted-network only; do not expose STF or Mobile Matrix to the public internet.
- Mac validation uses host ADB; Docker Desktop direct USB passthrough is not a prerequisite.
- Every “complete” checkbox requires static/API evidence or real-device evidence appropriate to its scope; simulated devices and timer-based success are invalid evidence.
- Airtest, Douyin workflows, AI Agent, iOS/WDA, custom web UI, and full task orchestration are out of scope for this change.

---

### Task 1: Scaffold the control plane and safe configuration

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `.gitignore`
- Create: `.env.example`
- Create: `src/config.ts`
- Create: `test/config.test.ts`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**
- Produces `AppConfig`, `loadConfig(env: NodeJS.ProcessEnv): AppConfig`, and scripts `check`, `build`, `test` used by every later task.

- [ ] **Step 1: Write configuration tests first**

```ts
import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { loadConfig } from '../src/config.js'

describe('loadConfig', () => {
  it('requires a pinned STF base URL and token', () => {
    const config = loadConfig({
      STF_BASE_URL: 'http://127.0.0.1:7100',
      STF_TOKEN: 'test-token',
    })
    assert.equal(config.stfBaseUrl, 'http://127.0.0.1:7100')
    assert.equal(config.stfToken, 'test-token')
  })

  it('uses bounded defaults for timeout and concurrency', () => {
    const config = loadConfig({
      STF_BASE_URL: 'http://127.0.0.1:7100',
      STF_TOKEN: 'test-token',
    })
    assert.equal(config.operationTimeoutMs, 10_000)
    assert.equal(config.batchConcurrency, 4)
  })
})
```

- [ ] **Step 2: Run the focused test and confirm the expected missing-module failure**

Run: `npm test -- test/config.test.ts`

Expected: FAIL because the TypeScript project and `loadConfig` do not exist yet.

- [ ] **Step 3: Create the minimal Node/TypeScript project**

Use `fastify`, `typescript`, `tsx`, and `@types/node`. Set the runtime floor to Node `>=20 <23`; do not encode secrets in `package.json` or checked-in files.

```json
{
  "name": "mobile-matrix",
  "private": true,
  "type": "module",
  "engines": { "node": ">=20 <23" },
  "scripts": {
    "check": "tsc --noEmit",
    "build": "tsc -p tsconfig.json",
    "test": "tsx --test \"test/**/*.test.ts\""
  }
}
```

`AppConfig` must contain `stfBaseUrl`, `stfToken`, `operationTimeoutMs`, `batchConcurrency`, and `environment`. `loadConfig` must reject missing `STF_BASE_URL`/`STF_TOKEN`, normalize a trailing slash, reject non-HTTP(S) URLs, and clamp timeout/concurrency to positive bounded integers.

- [ ] **Step 4: Add the checked-in secret boundary**

`.env.example` may contain placeholder names only:

```text
STF_BASE_URL=http://127.0.0.1:7100
STF_TOKEN=replace-with-local-token
MOBILE_MATRIX_OPERATION_TIMEOUT_MS=10000
MOBILE_MATRIX_BATCH_CONCURRENCY=4
MOBILE_MATRIX_ENVIRONMENT=mac-local
```

`.gitignore` must exclude `.env`, `.env.*.local`, `node_modules/`, `dist/`, and local evidence output while keeping `.env.example` tracked.

- [ ] **Step 5: Run the project checks**

Run: `npm run check && npm test`

Expected: PASS with configuration tests green.

- [ ] **Step 6: Synchronize OpenSpec and commit**

Mark OpenSpec tasks `1.1` and `1.2` complete only after the checks pass; update `1.3` when the Mac runbook exists in Task 6. Commit:

```bash
git add package.json tsconfig.json .gitignore .env.example src/config.ts test/config.test.ts openspec/changes/mobile-matrix-stf-foundation/tasks.md
git commit -m "chore: scaffold Mobile Matrix control plane"
```

### Task 2: Define the device domain and STF adapter contract

**Files:**
- Create: `src/domain/device.ts`
- Create: `src/domain/errors.ts`
- Create: `src/application/stf-port.ts`
- Create: `src/adapters/stf-http-client.ts`
- Create: `test/domain/device.test.ts`
- Create: `test/adapters/stf-http-client.test.ts`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**
- Produces `StfDevice`, `MobileDevice`, `DeviceStatus`, `StfPort`, `StfHttpClient`, `normalizeDevice`, and stable `MobileMatrixError` codes used by all routes.

- [ ] **Step 1: Write normalization and error tests**

Cover `present=false → offline`, `present=true/ready=false → unavailable`, ready and unused → `ready`, using/owner → `busy`, malformed device payload → `invalid_stf_response`, and HTTP 401 → `auth_failed`.

```ts
const device = normalizeDevice({
  serial: 'abc', present: true, ready: true, using: false, owner: null,
})
assert.equal(device.status, 'ready')
```

- [ ] **Step 2: Define the domain types and port**

```ts
export type DeviceStatus = 'ready' | 'busy' | 'offline' | 'unavailable' | 'unknown'

export interface MobileDevice {
  id: string
  serial: string
  platform: 'android'
  name: string | null
  provider: string | null
  present: boolean
  ready: boolean
  using: boolean
  owner: string | null
  status: DeviceStatus
}

export interface StfPort {
  listDevices(): Promise<StfDevice[]>
  getDevice(serial: string): Promise<StfDevice>
  leaseDevice(serial: string): Promise<void>
  releaseDevice(serial: string): Promise<void>
  remoteConnect(serial: string): Promise<{ remoteConnectUrl: string }>
}
```

The raw `StfDevice` type may preserve unknown fields under a diagnostic object, but the public model must not leak authorization headers or tokens.

- [ ] **Step 3: Implement `StfHttpClient` with Node `fetch`**

Use `AbortSignal.timeout(config.operationTimeoutMs)`, send `Authorization: Bearer ${stfToken}` internally, parse JSON only after checking the response status, and convert non-2xx responses to stable errors. `remoteConnect` may return the endpoint to its caller but must never log it.

- [ ] **Step 4: Run focused adapter tests with a fake fetch**

Run: `npm test -- test/domain/device.test.ts test/adapters/stf-http-client.test.ts`

Expected: PASS for successful list/get/lease/release/remote-connect and all listed error mappings; no test output may contain `test-token`.

- [ ] **Step 5: Run type checks and commit**

Run: `npm run check`

Mark OpenSpec tasks `2.1`–`2.3` complete and commit:

```bash
git add src/domain src/application/stf-port.ts src/adapters test/domain test/adapters openspec/changes/mobile-matrix-stf-foundation/tasks.md
git commit -m "feat: add STF adapter and device domain"
```

### Task 3: Expose health and single-device HTTP APIs

**Files:**
- Create: `src/application/device-service.ts`
- Create: `src/application/health-service.ts`
- Create: `src/http/app.ts`
- Create: `src/http/server.ts`
- Create: `src/main.ts`
- Create: `test/http/device-routes.test.ts`
- Create: `test/http/health-route.test.ts`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**
- Consumes `StfPort`, `AppConfig`, `normalizeDevice`, and `MobileMatrixError`.
- Produces `buildApp(deps): FastifyInstance`, the routes in the spec, and `GET /health` dependency details.

- [ ] **Step 1: Write route tests against an in-memory `StfPort` fake**

Use `app.inject()` to test:

```ts
const response = await app.inject({ method: 'GET', url: '/api/v1/devices' })
assert.equal(response.statusCode, 200)
assert.equal(response.json().devices[0].status, 'ready')
```

Cover list, get, lease, release, remote-connect, `device_busy`, `device_offline`, `auth_failed`, and redaction of the fake token/endpoint in error responses.

- [ ] **Step 2: Implement the application services**

`DeviceService` maps raw devices, verifies current STF state before mutations, and delegates lease/release/remote-connect. `HealthService` checks process/config plus injected STF/Provider probes and returns stable dependency fields without claiming readiness from cache.

- [ ] **Step 3: Implement Fastify routes and error serialization**

Routes must validate `serial`, return `{ device }` or `{ devices }` envelopes, preserve stable error `code`, and omit authorization headers, tokens, ADB keys, and unneeded complete remote endpoints. Keep the first profile local/trusted; do not add public auth or UI.

- [ ] **Step 4: Add the executable entrypoint and run tests**

Run: `npm test -- test/http/device-routes.test.ts test/http/health-route.test.ts`

Expected: PASS for every single-device and health scenario. Then run `npm run check && npm run build`.

- [ ] **Step 5: Synchronize and commit**

Mark OpenSpec tasks `2.4`, `3.1`–`3.4`, and `5.1`–`5.3` only when their focused tests and build pass. Commit:

```bash
git add src/application src/http src/main.ts test/http openspec/changes/mobile-matrix-stf-foundation/tasks.md
git commit -m "feat: expose device and health APIs"
```

### Task 4: Add bounded multi-device operations

**Files:**
- Create: `src/application/batch-service.ts`
- Create: `src/application/limiter.ts`
- Modify: `src/http/app.ts`
- Create: `test/application/batch-service.test.ts`
- Create: `test/http/batch-routes.test.ts`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**
- Produces `BatchResult`, `BatchItemResult`, `validateSerials(serials)`, and `BatchService.lease(serials)/release(serials)` with configured concurrency and timeout.

- [ ] **Step 1: Write batch tests first**

Cover empty list, duplicate serial, all-success, one busy, one offline, timeout, mixed release ownership, and retry-after-uncertain-lease. Assert every requested serial appears exactly once in the result.

```ts
const result = await service.lease(['a', 'b'])
assert.deepEqual(result.failed, [{ serial: 'b', code: 'device_busy' }])
assert.equal(result.outcomes.length, 2)
```

- [ ] **Step 2: Implement selector validation and bounded limiter**

Reject malformed selectors before calling STF. Use a small promise limiter capped by `config.batchConcurrency`; each item has `config.operationTimeoutMs`, and one rejected item must not cancel accepted siblings.

- [ ] **Step 3: Implement recheck-before-retry semantics**

After an uncertain mutation, call `getDevice(serial)` and return the observed ownership/status. Never blindly issue a second lease. For release, only accept the current client’s ownership as releasable.

- [ ] **Step 4: Add `/api/v1/batch/lease` and `/api/v1/batch/release`**

Return `{ accepted, succeeded, failed, outcomes }`, with aggregate `partial_failure` when at least one item succeeds and one fails. Preserve per-item codes and do not leak secrets.

- [ ] **Step 5: Run focused and full checks**

Run: `npm test -- test/application/batch-service.test.ts test/http/batch-routes.test.ts && npm run check && npm run build`

Expected: PASS; the limiter test must demonstrate no more than the configured number of in-flight STF calls.

- [ ] **Step 6: Synchronize and commit**

Mark OpenSpec tasks `4.1`–`4.5` and `5.2` complete only after tests pass. Commit:

```bash
git add src/application/batch-service.ts src/application/limiter.ts src/http/app.ts test/application test/http openspec/changes/mobile-matrix-stf-foundation/tasks.md
git commit -m "feat: add bounded multi-device operations"
```

### Task 5: Document the Mac runtime and validation evidence contract

**Files:**
- Create: `infra/stf/mac/README.md`
- Create: `infra/stf/mac/.env.example`
- Create: `docs/validation/mobile-matrix-stf-foundation.md`
- Create: `openspec/changes/mobile-matrix-stf-foundation/evidence/README.md`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**
- Produces a repeatable runbook; it does not install packages or claim that STF is already running.

- [ ] **Step 1: Write the Mac runbook**

Document checks and expected evidence in this order: `uname -m`, isolated Node 20, `adb devices -l`, STF version, RethinkDB health, STF UI/API, Mobile Matrix `/health`, and the first device list. State that Docker Desktop direct USB passthrough is not required and that any USB/IP experiment is optional.

- [ ] **Step 2: Write safe environment examples**

List only variable names and non-secret placeholders; explain where the local STF token comes from and that it must never be committed. Pin STF image/package references to `3.7.9`.

- [ ] **Step 3: Define evidence files and redaction**

The evidence README must require timestamp, host architecture, device serial redaction policy, command, result, and whether the evidence is static/API/runtime. It must prohibit tokens, ADB keys, complete remote-connect endpoints, account credentials, and private screenshots.

- [ ] **Step 4: Run documentation/spec checks and synchronize**

Run: `openspec validate mobile-matrix-stf-foundation --strict`

Mark OpenSpec tasks `1.3` and `7.1` complete only after the runbook and evidence contract are present. Commit:

```bash
git add infra/stf/mac docs/validation openspec/changes/mobile-matrix-stf-foundation/evidence openspec/changes/mobile-matrix-stf-foundation/tasks.md
git commit -m "docs: add Mac STF validation runbook"
```

### Task 6: Execute Mac single-device and multi-device verification

**Files:**
- Modify: `openspec/changes/mobile-matrix-stf-foundation/evidence/README.md`
- Create: `openspec/changes/mobile-matrix-stf-foundation/evidence/m0-mac-adb-stf.md`
- Create: `openspec/changes/mobile-matrix-stf-foundation/evidence/m1-single-device-api.md`
- Create: `openspec/changes/mobile-matrix-stf-foundation/evidence/m2-two-device-batch.md`
- Create: `openspec/changes/mobile-matrix-stf-foundation/evidence/m3-failure-and-unplug.md`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`

**Interfaces:**
- Consumes the runbook and running STF/Mobile Matrix services; produces redacted runtime evidence only.

- [ ] **Step 1: Capture the current Mac and first-device baseline**

Run the documented host checks and record the authorized device count. Do not mark multi-device tasks complete while only one device is connected.

- [ ] **Step 2: Verify STF and Mobile Matrix single-device behavior**

Record list, get, lease, release, and remote-connect responses. Redact token and temporary endpoint. Mark OpenSpec tasks `6.1`–`6.2` only when the responses and STF UI/API agree.

- [ ] **Step 3: Add the second Android device and verify independent state**

Record both serials in redacted form, list both through STF and Mobile Matrix, lease/release each independently, and verify one busy device does not change the other’s state. Mark `6.3`–`6.4` only with this evidence.

- [ ] **Step 4: Verify unplug and dependency failures**

Disconnect one phone, query status, operate the other, then test STF unreachable, invalid token, busy device, and Docker-without-USB setup. Mark `6.5`–`6.6` only with explicit outcomes; never substitute mocked responses.

- [ ] **Step 5: Run the completion audit**

Run:

```bash
npm run check
npm test
npm run build
openspec validate mobile-matrix-stf-foundation --strict
openspec status --change mobile-matrix-stf-foundation
```

Review every requirement against its evidence. Keep any hardware-blocked item unchecked and record the blocker in the evidence file.

- [ ] **Step 6: Commit the evidence and task state**

```bash
git add openspec/changes/mobile-matrix-stf-foundation/evidence openspec/changes/mobile-matrix-stf-foundation/tasks.md
git commit -m "test: record STF device management verification"
```

### Task 7: Final synchronization and handoff

**Files:**
- Modify: `openspec/changes/mobile-matrix-stf-foundation/proposal.md`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/design.md`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/tasks.md`
- Modify: `openspec/changes/mobile-matrix-stf-foundation/specs/**/*.md`

**Interfaces:**
- Produces the final OpenSpec progress snapshot; it does not silently archive incomplete work.

- [ ] **Step 1: Reconcile artifacts with implementation**

Update only requirements, design decisions, task checkboxes, and evidence references proven by current files or runtime output. If behavior changed, update proposal/design/specs before changing code claims.

- [ ] **Step 2: Run the final validation set**

Run `openspec validate mobile-matrix-stf-foundation --strict`, `git diff --check`, `npm run check`, `npm test`, and `npm run build` where the runtime is available. Record skipped commands and reasons.

- [ ] **Step 3: Produce the handoff summary**

Report the OpenSpec change name, task progress, exact evidence files, verified device count, unverified requirements, and the next independent change (labels/groups or Airtest adapter). Do not archive the change until all required tasks and evidence are complete.

- [ ] **Step 4: Commit the synchronized artifacts**

```bash
git add openspec/changes/mobile-matrix-stf-foundation
git commit -m "docs: synchronize STF foundation progress"
```
