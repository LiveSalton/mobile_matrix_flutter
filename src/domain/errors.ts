export type MobileMatrixErrorCode =
  | 'stf_unreachable'
  | 'provider_unavailable'
  | 'device_offline'
  | 'device_not_ready'
  | 'device_busy'
  | 'auth_failed'
  | 'operation_timeout'
  | 'partial_failure'
  | 'invalid_stf_response'
  | 'validation_error'
  | 'internal_error'

export class MobileMatrixError extends Error {
  readonly code: MobileMatrixErrorCode
  readonly statusCode: number
  readonly details?: Record<string, unknown>

  constructor(
    code: MobileMatrixErrorCode,
    message: string,
    options: {
      statusCode?: number
      details?: Record<string, unknown>
      cause?: unknown
    } = {},
  ) {
    super(redactSensitiveText(message), { cause: options.cause })
    this.name = 'MobileMatrixError'
    this.code = code
    this.statusCode = options.statusCode ?? defaultStatusCode(code)
    this.details = options.details
      ? redactSensitiveValue(options.details) as Record<string, unknown>
      : undefined
  }
}

function defaultStatusCode(code: MobileMatrixErrorCode): number {
  switch (code) {
    case 'auth_failed':
      return 401
    case 'validation_error':
      return 400
    case 'device_busy':
      return 409
    case 'device_offline':
    case 'device_not_ready':
      return 422
    case 'operation_timeout':
      return 504
    case 'stf_unreachable':
    case 'provider_unavailable':
      return 503
    case 'invalid_stf_response':
    case 'internal_error':
    case 'partial_failure':
      return 500
  }
}

export function asMobileMatrixError(error: unknown): MobileMatrixError {
  if (error instanceof MobileMatrixError) {
    return error
  }
  if (error instanceof Error && error.name === 'AbortError') {
    return new MobileMatrixError('operation_timeout', 'The STF operation timed out', {
      cause: error,
    })
  }
  return new MobileMatrixError('stf_unreachable', 'The STF service could not be reached', {
    cause: error,
  })
}
import { redactSensitiveText, redactSensitiveValue } from '../observability/redaction.js'
