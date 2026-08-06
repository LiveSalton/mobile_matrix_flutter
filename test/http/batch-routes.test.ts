import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { buildApp } from '../../src/http/app.js'
import type { StfPort } from '../../src/application/stf-port.js'
import type { StfDevice } from '../../src/domain/device.js'
import type { AppConfig } from '../../src/config.js'

const config: AppConfig = {
  stfBaseUrl: 'http://stf.local', stfToken: 'test-token', operationTimeoutMs: 100,
  batchConcurrency: 2, environment: 'test', port: 7120,
}

function fakeStf(): StfPort {
  const devices: Record<string, StfDevice> = {
    a: { serial: 'a', present: true, ready: true },
    b: { serial: 'b', present: true, ready: true },
  }
  const owned = new Set<string>()
  return {
    async listDevices() { return Object.values(devices) },
    async getDevice(serial) { return { ...devices[serial] as StfDevice, using: owned.has(serial), owner: owned.has(serial) ? 'service' : null } },
    async getUserDevices() { return [...owned].map((serial) => ({ ...devices[serial] as StfDevice, using: true, owner: 'service' })) },
    async leaseDevice(serial) { owned.add(serial) },
    async releaseDevice(serial) { owned.delete(serial) },
    async remoteConnect() { return { remoteConnectUrl: '127.0.0.1:1234' } },
  }
}

describe('batch routes', () => {
  it('rejects invalid selectors before STF mutation', async () => {
    const app = buildApp({ stf: fakeStf(), config })
    const response = await app.inject({
      method: 'POST', url: '/api/v1/batch/lease', payload: { serials: ['a', 'a'] },
    })
    assert.equal(response.statusCode, 400)
    assert.equal(response.json().error.code, 'validation_error')
    await app.close()
  })

  it('returns aggregate and per-device results', async () => {
    const app = buildApp({ stf: fakeStf(), config })
    const lease = await app.inject({
      method: 'POST', url: '/api/v1/batch/lease', payload: { serials: ['a', 'b'] },
    })
    const release = await app.inject({
      method: 'POST', url: '/api/v1/batch/release', payload: { serials: ['a', 'b'] },
    })
    assert.equal(lease.statusCode, 200)
    assert.deepEqual(lease.json().succeeded, ['a', 'b'])
    assert.equal(release.statusCode, 200)
    assert.deepEqual(release.json().succeeded, ['a', 'b'])
    await app.close()
  })
})
