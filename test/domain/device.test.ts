import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { normalizeDevice } from '../../src/domain/device.js'
import { MobileMatrixError } from '../../src/domain/errors.js'

describe('normalizeDevice', () => {
  it('maps an available STF device to ready', () => {
    const device = normalizeDevice({ serial: 'ready-1', present: true, ready: true })
    assert.equal(device.status, 'ready')
    assert.equal(device.platform, 'android')
  })

  it('maps absent and not-ready devices', () => {
    assert.equal(
      normalizeDevice({ serial: 'offline-1', present: false, ready: false }).status,
      'offline',
    )
    assert.equal(
      normalizeDevice({ serial: 'unready-1', present: true, ready: false }).status,
      'unavailable',
    )
  })

  it('maps an owner or using flag to busy', () => {
    assert.equal(
      normalizeDevice({ serial: 'owned-1', present: true, ready: true, owner: { email: 'owner@example.com' } }).status,
      'busy',
    )
    assert.equal(
      normalizeDevice({ serial: 'owned-2', present: true, ready: true, using: true }).status,
      'busy',
    )
  })

  it('rejects malformed STF payloads', () => {
    assert.throws(
      () => normalizeDevice({ serial: '', present: true, ready: true }),
      (error: unknown) => error instanceof MobileMatrixError && error.code === 'invalid_stf_response',
    )
  })
})
