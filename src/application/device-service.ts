import type { StfPort } from './stf-port.js'
import { normalizeDevice, type MobileDevice } from '../domain/device.js'
import { MobileMatrixError } from '../domain/errors.js'

export class DeviceService {
  constructor(private readonly stf: StfPort) {}

  async list(): Promise<MobileDevice[]> {
    const devices = await this.stf.listDevices()
    return devices.map(normalizeDevice)
  }

  async get(serial: string): Promise<MobileDevice> {
    return normalizeDevice(await this.stf.getDevice(serial))
  }

  async lease(serial: string): Promise<{ serial: string; success: true }> {
    const device = await this.get(serial)
    assertLeasable(device)
    await this.stf.leaseDevice(serial)
    return { serial, success: true }
  }

  async release(serial: string): Promise<{ serial: string; success: true }> {
    await this.assertOwned(serial)
    await this.stf.releaseDevice(serial)
    return { serial, success: true }
  }

  async remoteConnect(serial: string): Promise<{ serial: string; remoteConnectUrl: string }> {
    const device = await this.get(serial)
    assertPresentAndReady(device)
    await this.assertOwned(serial)
    const result = await this.stf.remoteConnect(serial)
    return { serial, remoteConnectUrl: result.remoteConnectUrl }
  }

  private async assertOwned(serial: string): Promise<void> {
    const devices = await this.stf.getUserDevices()
    if (!devices.some((device) => device.serial === serial)) {
      throw new MobileMatrixError('device_busy', `The configured STF identity does not own ${serial}`)
    }
  }
}

function assertLeasable(device: MobileDevice): void {
  if (device.status === 'busy') {
    throw new MobileMatrixError('device_busy', `Device ${device.serial} is already in use`)
  }
  assertReady(device)
}

function assertReady(device: MobileDevice): void {
  assertPresentAndReady(device)
  if (device.status !== 'ready') {
    throw new MobileMatrixError('device_not_ready', `Device ${device.serial} is not ready`)
  }
}

function assertPresentAndReady(device: MobileDevice): void {
  if (device.status === 'offline') {
    throw new MobileMatrixError('device_offline', `Device ${device.serial} is offline`)
  }
  if (!device.present || !device.ready) {
    throw new MobileMatrixError('device_not_ready', `Device ${device.serial} is not ready`)
  }
}
