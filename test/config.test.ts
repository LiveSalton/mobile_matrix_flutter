import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { loadConfig } from '../src/config.js'

describe('loadConfig', () => {
  it('requires a pinned STF base URL and token', () => {
    const config = loadConfig({
      STF_BASE_URL: 'http://127.0.0.1:7100/',
      STF_TOKEN: 'test-token',
    })

    assert.equal(config.stfBaseUrl, 'http://127.0.0.1:7100')
    assert.equal(config.stfToken, 'test-token')
  })

  it('uses bounded defaults for timeout and concurrency', () => {
    const config = loadConfig({
      STF_BASE_URL: 'http://127.0.0.1:7100',
      STF_TOKEN: 'test-token',
    })

    assert.equal(config.operationTimeoutMs, 10_000)
    assert.equal(config.batchConcurrency, 4)
    assert.equal(config.environment, 'local')
  })

  it('rejects invalid URLs and unbounded values', () => {
    assert.throws(
      () => loadConfig({ STF_BASE_URL: 'file:///tmp/stf', STF_TOKEN: 'test-token' }),
      /HTTP or HTTPS/,
    )
    assert.throws(
      () => loadConfig({
        STF_BASE_URL: 'http://127.0.0.1:7100',
        STF_TOKEN: 'test-token',
        MOBILE_MATRIX_BATCH_CONCURRENCY: '0',
      }),
      /between 1 and 32/,
    )
  })
})
