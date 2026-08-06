export interface AppConfig {
  stfBaseUrl: string
  stfToken: string
  operationTimeoutMs: number
  batchConcurrency: number
  environment: string
}

const DEFAULT_OPERATION_TIMEOUT_MS = 10_000
const DEFAULT_BATCH_CONCURRENCY = 4
const MAX_OPERATION_TIMEOUT_MS = 60_000
const MAX_BATCH_CONCURRENCY = 32

function requiredString(env: NodeJS.ProcessEnv, name: string): string {
  const value = env[name]?.trim()
  if (!value) {
    throw new Error(`${name} is required`)
  }
  return value
}

function parseBoundedInteger(
  env: NodeJS.ProcessEnv,
  name: string,
  fallback: number,
  maximum: number,
): number {
  const raw = env[name]?.trim()
  if (!raw) {
    return fallback
  }

  const value = Number(raw)
  if (!Number.isInteger(value) || value < 1 || value > maximum) {
    throw new Error(`${name} must be an integer between 1 and ${maximum}`)
  }
  return value
}

function normalizeBaseUrl(value: string): string {
  let url: URL
  try {
    url = new URL(value)
  } catch {
    throw new Error('STF_BASE_URL must be a valid HTTP(S) URL')
  }

  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error('STF_BASE_URL must use HTTP or HTTPS')
  }

  return url.toString().replace(/\/$/, '')
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    stfBaseUrl: normalizeBaseUrl(requiredString(env, 'STF_BASE_URL')),
    stfToken: requiredString(env, 'STF_TOKEN'),
    operationTimeoutMs: parseBoundedInteger(
      env,
      'MOBILE_MATRIX_OPERATION_TIMEOUT_MS',
      DEFAULT_OPERATION_TIMEOUT_MS,
      MAX_OPERATION_TIMEOUT_MS,
    ),
    batchConcurrency: parseBoundedInteger(
      env,
      'MOBILE_MATRIX_BATCH_CONCURRENCY',
      DEFAULT_BATCH_CONCURRENCY,
      MAX_BATCH_CONCURRENCY,
    ),
    environment: env.MOBILE_MATRIX_ENVIRONMENT?.trim() || 'local',
  }
}
