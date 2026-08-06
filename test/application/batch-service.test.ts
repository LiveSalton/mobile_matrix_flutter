import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { BatchService, validateSerials } from '../../src/application/batch-service.js'
import { DeviceService } from '../../src/application/device-service.js'
import type { StfPort } from '../../src/application/stf-port.js'
import type { StfDevice } from '../../src/domain/device.js'
import { MobileMatrixError } from '../../src/domain/errors.js'

const ready = (serial: string): StfDevice => ({ serial, present: true, ready: true })

function portFor(
  devices: Record<string, StfDevice>,
  options: { busy?: Set<string>; fail?: Set<string>; delayMs?: number } = {},
): StfPort {
  const owned = new Set(options.busy ?? [])
  return {
    async listDevices() { return Object.values(devices) },
    async getDevice(serial) {
      const device = devices[serial]
      if (!device) throw new MobileMatrixError('device_offline', serial)
      return { ...device, using: owned.has(serial), owner: owned.has(serial) ? 'service' : null }
    },
    async getUserDevices() {
      return [...owned].map((serial) => ({ ...devices[serial] as StfDevice, using: true, owner: 'service' }))
    },
    async leaseDevice(serial) {
      if (options.delayMs) await new Promise((resolve) => setTimeout(resolve, options.delayMs))
      if (options.fail?.has(serial)) throw new MobileMatrixError('device_busy', serial)
      owned.add(serial)
    },
    async releaseDevice(serial) {
      if (options.fail?.has(serial)) throw new MobileMatrixError('device_busy', serial)
      owned.delete(serial)
    },
    async remoteConnect() { return { remoteConnectUrl: '127.0.0.1:1234' } },
  }
}

describe('validateSerials', () => {
  it('rejects empty, duplicate, and malformed selectors', () => {
    assert.throws(() => validateSerials([]), /non-empty/)
    assert.throws(() => validateSerials(['a', 'a']), /unique/)
    assert.throws(() => validateSerials(['']), /unique non-empty/)
  })
})

describe('BatchService', () => {
  it('returns independent successes and failures', async () => {
    const stf = portFor({ a: ready('a'), b: ready('b') }, { fail: new Set(['b']) })
    const result = await new BatchService(new DeviceService(stf), 2, 100).lease(['a', 'b'])
    assert.equal(result.result, 'partial_failure')
    assert.deepEqual(result.succeeded, ['a'])
    assert.equal(result.failed[0]?.serial, 'b')
    assert.equal(result.failed[0]?.code, 'device_busy')
    assert.equal(result.outcomes.length, 2)
  })

  it('does not exceed configured concurrency', async () => {
    let active = 0
    let peak = 0
    const stf = portFor({ a: ready('a'), b: ready('b'), c: ready('c') }, { delayMs: 10 })
    const original = stf.leaseDevice
    stf.leaseDevice = async (serial) => {
      active += 1
      peak = Math.max(peak, active)
      await original(serial)
      active -= 1
    }
    await new BatchService(new DeviceService(stf), 2, 100).lease(['a', 'b', 'c'])
    assert.equal(peak, 2)
  })

  it('rechecks ownership after an uncertain timeout', async () => {
    const stf = portFor({ a: ready('a') })
    stf.leaseDevice = async () => {
      throw new MobileMatrixError('operation_timeout', 'uncertain')
    }
    stf.getUserDevices = async () => [
      { serial: 'a', present: true, ready: true, using: true, owner: 'service' },
    ]
    const result = await new BatchService(new DeviceService(stf), 1, 100).lease(['a'])
    assert.equal(result.result, 'success')
    assert.deepEqual(result.succeeded, ['a'])
  })

  it('keeps an unresolved timeout classified when the recheck cannot prove success', async () => {
    const stf = portFor({ a: ready('a') })
    stf.leaseDevice = async () => {
      throw new MobileMatrixError('operation_timeout', 'uncertain')
    }
    const result = await new BatchService(new DeviceService(stf), 1, 100).lease(['a'])
    assert.equal(result.result, 'partial_failure')
    assert.equal(result.failed[0]?.code, 'operation_timeout')
  })
})
