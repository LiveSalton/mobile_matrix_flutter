import { DeviceService } from './device-service.js'
import { mapWithConcurrency } from './limiter.js'
import { asMobileMatrixError, MobileMatrixError, type MobileMatrixErrorCode } from '../domain/errors.js'

export type BatchOperation = 'lease' | 'release'

export interface BatchItemResult {
  serial: string
  status: 'succeeded' | 'failed'
  code?: MobileMatrixErrorCode
  message?: string
}

export interface BatchResult {
  result: 'success' | 'partial_failure'
  accepted: string[]
  succeeded: string[]
  failed: Array<BatchItemResult & { code: MobileMatrixErrorCode }>
  outcomes: BatchItemResult[]
}

export function validateSerials(value: unknown): string[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new MobileMatrixError('validation_error', 'serials must be a non-empty array')
  }
  if (
    value.some((serial) => typeof serial !== 'string' || serial.trim().length === 0) ||
    new Set(value).size !== value.length
  ) {
    throw new MobileMatrixError('validation_error', 'serials must contain unique non-empty strings')
  }
  return value.map((serial) => serial.trim())
}

export class BatchService {
  constructor(
    private readonly devices: DeviceService,
    private readonly concurrency: number,
    private readonly timeoutMs: number,
  ) {}

  async lease(serials: unknown): Promise<BatchResult> {
    return this.run('lease', validateSerials(serials))
  }

  async release(serials: unknown): Promise<BatchResult> {
    return this.run('release', validateSerials(serials))
  }

  private async run(operation: BatchOperation, serials: string[]): Promise<BatchResult> {
    const outcomes = await mapWithConcurrency(serials, this.concurrency, async (serial) => {
      try {
        await this.withTimeout(
          operation === 'lease'
            ? this.devices.lease(serial)
            : this.devices.release(serial),
        )
        return { serial, status: 'succeeded' as const }
      } catch (error) {
        const rechecked = await this.recheckAfterUncertainMutation(operation, serial, error)
        if (rechecked === 'succeeded') {
          return { serial, status: 'succeeded' as const }
        }
        return { serial, status: 'failed' as const, code: rechecked.code, message: rechecked.message }
      }
    })
    const succeeded = outcomes
      .filter((outcome) => outcome.status === 'succeeded')
      .map((outcome) => outcome.serial)
    const failed: Array<BatchItemResult & { code: MobileMatrixErrorCode }> = outcomes
      .filter((outcome) => outcome.status === 'failed')
      .map((outcome) => ({
        ...outcome,
        code: outcome.code ?? 'internal_error',
      }))
    return {
      result: failed.length > 0 ? 'partial_failure' : 'success',
      accepted: serials,
      succeeded,
      failed,
      outcomes,
    }
  }

  private async withTimeout<T>(promise: Promise<T>): Promise<T> {
    let timer: ReturnType<typeof setTimeout> | undefined
    try {
      return await Promise.race([
        promise,
        new Promise<T>((_, reject) => {
          timer = setTimeout(() => {
            reject(new MobileMatrixError('operation_timeout', 'Batch operation timed out'))
          }, this.timeoutMs)
        }),
      ])
    } finally {
      if (timer) {
        clearTimeout(timer)
      }
    }
  }

  private async recheckAfterUncertainMutation(
    operation: BatchOperation,
    serial: string,
    error: unknown,
  ): Promise<MobileMatrixError | 'succeeded'> {
    const failure = asMobileMatrixError(error)
    if (failure.code !== 'operation_timeout') {
      return failure
    }

    try {
      const owned = await this.devices.isOwned(serial)
      if ((operation === 'lease' && owned) || (operation === 'release' && !owned)) {
        return 'succeeded'
      }
    } catch {
      // Preserve the original timeout when the state recheck is also unavailable.
    }
    return failure
  }
}
