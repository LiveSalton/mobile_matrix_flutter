import { describe, it } from 'node:test'
import assert from 'node:assert/strict'
import { StfHttpClient } from '../../src/adapters/stf-http-client.js'
import { MobileMatrixError } from '../../src/domain/errors.js'

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  })
}

function clientFor(
  handler: (url: string, init?: RequestInit) => Promise<Response>,
): StfHttpClient {
  return new StfHttpClient({
    baseUrl: 'http://stf.local',
    token: 'test-token',
    operationTimeoutMs: 100,
    fetchImpl: handler as typeof fetch,
  })
}

describe('StfHttpClient', () => {
  it('lists devices and sends the bearer token internally', async () => {
    let request: { url: string; init?: RequestInit } | undefined
    const client = clientFor(async (url, init) => {
      request = { url, init }
      return jsonResponse({
        devices: [{ serial: 'abc', present: true, ready: true, using: false }],
      })
    })

    const devices = await client.listDevices()
    assert.equal(devices[0]?.serial, 'abc')
    assert.equal(request?.url, 'http://stf.local/api/v1/devices')
    assert.equal((request?.init?.headers as Record<string, string>).Authorization, 'Bearer test-token')
  })

  it('maps lease, release, and remote-connect endpoints', async () => {
    const requests: string[] = []
    const client = clientFor(async (url, init) => {
      requests.push(`${init?.method ?? 'GET'} ${url}`)
      if (url.endsWith('/remoteConnect')) {
        return jsonResponse({ success: true, remoteConnectUrl: '127.0.0.1:1234' })
      }
      return jsonResponse({ success: true, description: 'ok' })
    })

    await client.leaseDevice('abc')
    await client.releaseDevice('abc')
    const remote = await client.remoteConnect('abc')
    assert.equal(remote.remoteConnectUrl, '127.0.0.1:1234')
    assert.deepEqual(requests, [
      'POST http://stf.local/api/v1/user/devices',
      'DELETE http://stf.local/api/v1/user/devices/abc',
      'POST http://stf.local/api/v1/user/devices/abc/remoteConnect',
    ])
  })

  it('maps authentication, invalid JSON, and network errors', async () => {
    await assert.rejects(
      clientFor(async () => jsonResponse({ success: false }, 401)).leaseDevice('abc'),
      (error: unknown) => error instanceof MobileMatrixError && error.code === 'auth_failed',
    )
    await assert.rejects(
      clientFor(async () => new Response('{', { status: 200 })).listDevices(),
      (error: unknown) => error instanceof MobileMatrixError && error.code === 'invalid_stf_response',
    )
    await assert.rejects(
      clientFor(async () => { throw new Error('connection refused') }).listDevices(),
      (error: unknown) => error instanceof MobileMatrixError && error.code === 'stf_unreachable',
    )
  })
})
