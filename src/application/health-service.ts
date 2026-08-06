import type { StfPort } from './stf-port.js'
import { MobileMatrixError } from '../domain/errors.js'

export interface HealthCheck {
  status: 'healthy' | 'degraded' | 'unavailable'
  code?: string
}

export interface HealthReport {
  status: 'healthy' | 'degraded' | 'unavailable'
  checks: {
    controlPlane: HealthCheck
    stfApi: HealthCheck
    providerAdb: HealthCheck
    authentication: HealthCheck
  }
}

export class HealthService {
  constructor(private readonly stf: StfPort, private readonly tokenConfigured: boolean) {}

  async check(): Promise<HealthReport> {
    const controlPlane: HealthCheck = { status: 'healthy' }
    if (!this.tokenConfigured) {
      return {
        status: 'unavailable',
        checks: {
          controlPlane,
          stfApi: { status: 'unavailable', code: 'auth_failed' },
          providerAdb: { status: 'unavailable', code: 'provider_unavailable' },
          authentication: { status: 'unavailable', code: 'auth_failed' },
        },
      }
    }

    try {
      const devices = await this.stf.listDevices()
      const hasPresentDevice = devices.some((device) => device.present)
      const hasReadyDevice = devices.some((device) => device.present && device.ready)
      const providerAdb: HealthCheck = hasReadyDevice
        ? { status: 'healthy' }
        : hasPresentDevice
          ? { status: 'degraded', code: 'provider_unavailable' }
          : { status: 'degraded', code: 'provider_unavailable' }
      const status = providerAdb.status === 'healthy' ? 'healthy' : 'degraded'
      return {
        status,
        checks: {
          controlPlane,
          stfApi: { status: 'healthy' },
          providerAdb,
          authentication: { status: 'healthy' },
        },
      }
    } catch (error) {
      const failure = error instanceof MobileMatrixError
        ? error
        : new MobileMatrixError('stf_unreachable', 'STF health check failed', { cause: error })
      const authFailed = failure.code === 'auth_failed'
      return {
        status: 'unavailable',
        checks: {
          controlPlane,
          stfApi: { status: 'unavailable', code: failure.code },
          providerAdb: { status: 'unavailable', code: 'provider_unavailable' },
          authentication: {
            status: authFailed ? 'unavailable' : 'healthy',
            ...(authFailed ? { code: 'auth_failed' } : {}),
          },
        },
      }
    }
  }
}
