import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { buildApp } from '../../src/http/app.js'
import type { StfPort } from '../../src/application/stf-port.js'
import type { StfDevice } from '../../src/domain/device.js'
import type { AppConfig } from '../../src/config.js'
import { MobileMatrixError } from '../../src/domain/errors.js'

const config: AppConfig = {
  stfBaseUrl: 'http://stf.local', stfToken: 'test-token', operationTimeoutMs: 100,
  batchConcurrency: 2, environment: 'test', port: 7120,
}

function portWith(devices: StfDevice[], error?: MobileMatrixError): StfPort {
  return {
    async listDevices() { if (error) throw error; return devices },
    async getDevice() { return devices[0] as StfDevice },
    async getUserDevices() { return devices },
    async leaseDevice() {},
    async releaseDevice() {},
    async remoteConnect() { return { remoteConnectUrl: '127.0.0.1:1234' } },
  }
}

describe('health route', () => {
  it('reports healthy STF and provider checks when a ready device exists', async () => {
    const app = buildApp({
      stf: portWith([{ serial: 'abc', present: true, ready: true }]), config,
    })
    const response = await app.inject({ method: 'GET', url: '/health' })
    assert.equal(response.statusCode, 200)
    assert.equal(response.json().checks.stfApi.status, 'healthy')
    assert.equal(response.json().checks.providerAdb.status, 'healthy')
    await app.close()
  })

  it('distinguishes STF unreachable from an empty provider', async () => {
    const app = buildApp({
      stf: portWith([], new MobileMatrixError('stf_unreachable', 'offline')),
      config,
    })
    const response = await app.inject({ method: 'GET', url: '/health' })
    assert.equal(response.statusCode, 503)
    assert.equal(response.json().checks.stfApi.code, 'stf_unreachable')
    assert.equal(response.json().checks.providerAdb.code, 'provider_unavailable')
    await app.close()
  })
})
