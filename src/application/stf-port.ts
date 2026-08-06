import type { StfDevice } from '../domain/device.js'

export interface StfPort {
  listDevices(): Promise<StfDevice[]>
  getDevice(serial: string): Promise<StfDevice>
  getUserDevices(): Promise<StfDevice[]>
  leaseDevice(serial: string): Promise<void>
  releaseDevice(serial: string): Promise<void>
  remoteConnect(serial: string): Promise<{ remoteConnectUrl: string }>
}
