import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { redactSensitiveText, redactSensitiveValue } from '../../src/observability/redaction.js'

describe('redaction', () => {
  it('redacts bearer tokens, URLs, and secret assignments', () => {
    const value = redactSensitiveText(
      'Bearer abc token=secret https://127.0.0.1:1234/path',
    )
    assert.equal(value, 'Bearer [REDACTED] token=[REDACTED] [REDACTED_URL]')
  })

  it('redacts nested diagnostic values', () => {
    assert.deepEqual(
      redactSensitiveValue({ token: 'abc', nested: ['https://stf.local/x'] }),
      { token: '[REDACTED]', nested: ['[REDACTED_URL]'] },
    )
  })
})
