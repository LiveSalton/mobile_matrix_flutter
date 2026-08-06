import type { AppConfig } from '../config.js'
import type { StfDevice } from '../domain/device.js'
import { MobileMatrixError, asMobileMatrixError } from '../domain/errors.js'
import type { StfPort } from '../application/stf-port.js'

interface StfDevicesResponse {
  devices?: unknown
}

interface StfDeviceResponse {
  device?: unknown
}

interface StfMutationResponse {
  success?: unknown
  description?: unknown
}

interface StfRemoteConnectResponse extends StfMutationResponse {
  remoteConnectUrl?: unknown
}

export interface StfHttpClientOptions {
  baseUrl: string
  token: string
  operationTimeoutMs: number
  fetchImpl?: typeof fetch
}

export class StfHttpClient implements StfPort {
  private readonly baseUrl: string
  private readonly token: string
  private readonly operationTimeoutMs: number
  private readonly fetchImpl: typeof fetch

  constructor(options: StfHttpClientOptions | AppConfig) {
    this.baseUrl = 'baseUrl' in options ? options.baseUrl : options.stfBaseUrl
    this.token = 'token' in options ? options.token : options.stfToken
    this.operationTimeoutMs = options.operationTimeoutMs
    this.fetchImpl = 'fetchImpl' in options && options.fetchImpl ? options.fetchImpl : fetch
  }

  async listDevices(): Promise<StfDevice[]> {
    const body = await this.request<StfDevicesResponse>('/api/v1/devices')
    if (!Array.isArray(body.devices)) {
      throw new MobileMatrixError('invalid_stf_response', 'STF device list is malformed')
    }
    return body.devices.map((device) => this.parseDevice(device))
  }

  async getDevice(serial: string): Promise<StfDevice> {
    const body = await this.request<StfDeviceResponse>(
      `/api/v1/devices/${encodeURIComponent(serial)}`,
    )
    return this.parseDevice(body.device)
  }

  async getUserDevices(): Promise<StfDevice[]> {
    const body = await this.request<StfDevicesResponse>('/api/v1/user/devices')
    if (!Array.isArray(body.devices)) {
      throw new MobileMatrixError('invalid_stf_response', 'STF user device list is malformed')
    }
    return body.devices.map((device) => this.parseDevice(device))
  }

  async leaseDevice(serial: string): Promise<void> {
    const body = await this.request<StfMutationResponse>('/api/v1/user/devices', {
      method: 'POST',
      body: JSON.stringify({ serial, timeout: 900_000 }),
    })
    this.assertMutationSucceeded(body, 'STF could not lease the device')
  }

  async releaseDevice(serial: string): Promise<void> {
    const body = await this.request<StfMutationResponse>(
      `/api/v1/user/devices/${encodeURIComponent(serial)}`,
      { method: 'DELETE' },
    )
    this.assertMutationSucceeded(body, 'STF could not release the device')
  }

  async remoteConnect(serial: string): Promise<{ remoteConnectUrl: string }> {
    const body = await this.request<StfRemoteConnectResponse>(
      `/api/v1/user/devices/${encodeURIComponent(serial)}/remoteConnect`,
      { method: 'POST' },
    )
    this.assertMutationSucceeded(body, 'STF could not create a remote connection')
    if (typeof body.remoteConnectUrl !== 'string' || body.remoteConnectUrl.length === 0) {
      throw new MobileMatrixError('invalid_stf_response', 'STF returned no remote connection URL')
    }
    return { remoteConnectUrl: body.remoteConnectUrl }
  }

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
    let response: Response
    try {
      response = await this.fetchImpl(`${this.baseUrl}${path}`, {
        ...init,
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.token}`,
          ...init.headers,
        },
        signal: AbortSignal.timeout(this.operationTimeoutMs),
      })
    } catch (error) {
      throw asMobileMatrixError(error)
    }

    if (!response.ok) {
      throw this.httpError(response.status)
    }

    try {
      return (await response.json()) as T
    } catch (error) {
      throw new MobileMatrixError('invalid_stf_response', 'STF returned invalid JSON', {
        cause: error,
      })
    }
  }

  private httpError(status: number): MobileMatrixError {
    if (status === 401 || status === 403) {
      return new MobileMatrixError('auth_failed', 'STF rejected the configured token')
    }
    if (status === 404) {
      return new MobileMatrixError('device_offline', 'STF could not find the requested device')
    }
    if (status === 408 || status === 504) {
      return new MobileMatrixError('operation_timeout', 'STF timed out the operation')
    }
    if (status >= 500) {
      return new MobileMatrixError('stf_unreachable', 'STF returned a server failure')
    }
    return new MobileMatrixError('internal_error', `STF returned HTTP ${status}`, {
      statusCode: status,
    })
  }

  private parseDevice(value: unknown): StfDevice {
    if (!value || typeof value !== 'object') {
      throw new MobileMatrixError('invalid_stf_response', 'STF returned a malformed device')
    }
    const device = value as Record<string, unknown>
    if (
      typeof device.serial !== 'string' ||
      typeof device.present !== 'boolean' ||
      typeof device.ready !== 'boolean'
    ) {
      throw new MobileMatrixError('invalid_stf_response', 'STF returned a malformed device')
    }
    return device as StfDevice
  }

  private assertMutationSucceeded(body: StfMutationResponse, message: string): void {
    if (body.success !== true) {
      const description = typeof body.description === 'string' ? body.description : message
      throw new MobileMatrixError('internal_error', description)
    }
  }
}
