import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { buildApp } from '../../src/http/app.js'
import type { StfPort } from '../../src/application/stf-port.js'
import type { StfDevice } from '../../src/domain/device.js'
import type { AppConfig } from '../../src/config.js'

const config: AppConfig = {
  stfBaseUrl: 'http://stf.local',
  stfToken: 'test-token',
  operationTimeoutMs: 100,
  batchConcurrency: 2,
  environment: 'test',
  port: 7120,
}

function fakeStf(): StfPort {
  const device: StfDevice = {
    serial: 'abc', present: true, ready: true, using: false, owner: null,
  }
  return {
    async listDevices() { return [device] },
    async getDevice() { return device },
    async getUserDevices() { return [device] },
    async leaseDevice() { device.using = true; device.owner = 'service' },
    async releaseDevice() { device.using = false; device.owner = null },
    async remoteConnect() { return { remoteConnectUrl: '127.0.0.1:1234' } },
  }
}

describe('device routes', () => {
  it('lists and gets normalized devices', async () => {
    const app = buildApp({ stf: fakeStf(), config })
    const list = await app.inject({ method: 'GET', url: '/api/v1/devices' })
    const get = await app.inject({ method: 'GET', url: '/api/v1/devices/abc' })
    assert.equal(list.statusCode, 200)
    assert.equal(list.json().devices[0].status, 'ready')
    assert.equal(get.statusCode, 200)
    assert.equal(get.json().device.serial, 'abc')
    await app.close()
  })

  it('leases, releases, and remote-connects through the service identity', async () => {
    const app = buildApp({ stf: fakeStf(), config })
    const lease = await app.inject({ method: 'POST', url: '/api/v1/devices/abc/lease' })
    const remote = await app.inject({ method: 'POST', url: '/api/v1/devices/abc/remote-connect' })
    const release = await app.inject({ method: 'DELETE', url: '/api/v1/devices/abc/lease' })
    assert.equal(lease.statusCode, 200)
    assert.equal(remote.json().remoteConnectUrl, '127.0.0.1:1234')
    assert.equal(release.statusCode, 200)
    await app.close()
  })

  it('redacts internal failures', async () => {
    const stf = fakeStf()
    stf.listDevices = async () => { throw new Error('Bearer test-token at 127.0.0.1:1234') }
    const app = buildApp({ stf, config })
    const response = await app.inject({ method: 'GET', url: '/api/v1/devices' })
    assert.equal(response.statusCode, 500)
    assert.equal(response.json().error.message, 'Mobile Matrix request failed')
    assert.doesNotMatch(response.body, /test-token|127\.0\.0\.1:1234/)
    await app.close()
  })

  it('returns stable device failure codes', async () => {
    const statuses: Array<[boolean, boolean, string]> = [
      [false, false, 'device_offline'],
      [true, false, 'device_not_ready'],
      [true, true, 'device_busy'],
    ]
    for (const [present, ready, code] of statuses) {
      const stf = fakeStf()
      stf.getDevice = async () => ({
        serial: 'abc', present, ready, using: code === 'device_busy', owner: code === 'device_busy' ? 'other' : null,
      })
      const app = buildApp({ stf, config })
      const response = await app.inject({ method: 'POST', url: '/api/v1/devices/abc/lease' })
      assert.equal(response.statusCode, code === 'device_busy' ? 409 : 422)
      assert.equal(response.json().error.code, code)
      await app.close()
    }
  })
})
