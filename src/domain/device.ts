import { MobileMatrixError } from './errors.js'

export type DeviceStatus = 'ready' | 'busy' | 'offline' | 'unavailable' | 'unknown'

export interface StfDevice {
  serial: string
  present: boolean
  ready: boolean
  using?: boolean
  owner?: unknown
  provider?: string | null
  name?: string | null
  model?: string | null
  [key: string]: unknown
}

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
  stf: StfDevice
}

export function normalizeDevice(raw: StfDevice): MobileDevice {
  if (!raw || typeof raw !== 'object' || typeof raw.serial !== 'string' || raw.serial.length === 0) {
    throw new MobileMatrixError('invalid_stf_response', 'STF returned a device without a serial')
  }
  if (typeof raw.present !== 'boolean' || typeof raw.ready !== 'boolean') {
    throw new MobileMatrixError('invalid_stf_response', `STF returned malformed device ${raw.serial}`)
  }

  const using = raw.using === true
  const owner = ownerLabel(raw.owner)
  const status: DeviceStatus = !raw.present
    ? 'offline'
    : !raw.ready
      ? 'unavailable'
      : using || owner !== null
        ? 'busy'
        : 'ready'

  return {
    id: raw.serial,
    serial: raw.serial,
    platform: 'android',
    name: stringOrNull(raw.name ?? raw.model),
    provider: stringOrNull(raw.provider),
    present: raw.present,
    ready: raw.ready,
    using,
    owner,
    status,
    stf: raw,
  }
}

function ownerLabel(value: unknown): string | null {
  if (typeof value === 'string' && value.length > 0) {
    return value
  }
  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>
    for (const key of ['email', 'name', 'id']) {
      if (typeof record[key] === 'string' && record[key].length > 0) {
        return record[key]
      }
    }
    return 'owned'
  }
  return null
}

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null
}
