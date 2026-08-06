import Fastify, { type FastifyInstance } from 'fastify'
import { DeviceService } from '../application/device-service.js'
import { HealthService } from '../application/health-service.js'
import type { StfPort } from '../application/stf-port.js'
import type { AppConfig } from '../config.js'
import { MobileMatrixError } from '../domain/errors.js'

export interface AppDependencies {
  stf: StfPort
  config: AppConfig
}

export function buildApp(dependencies: AppDependencies): FastifyInstance {
  const app = Fastify({ logger: false })
  const devices = new DeviceService(dependencies.stf)
  const health = new HealthService(dependencies.stf, dependencies.config.stfToken.length > 0)

  app.get('/health', async (_request, reply) => {
    const report = await health.check()
    return reply.code(report.status === 'healthy' ? 200 : 503).send(report)
  })

  app.get('/api/v1/devices', async (_request, reply) => {
    return reply.send({ devices: await devices.list() })
  })

  app.get<{ Params: { serial: string } }>('/api/v1/devices/:serial', async (request, reply) => {
    return reply.send({ device: await devices.get(request.params.serial) })
  })

  app.post<{ Params: { serial: string } }>('/api/v1/devices/:serial/lease', async (request, reply) => {
    return reply.send(await devices.lease(request.params.serial))
  })

  app.delete<{ Params: { serial: string } }>('/api/v1/devices/:serial/lease', async (request, reply) => {
    return reply.send(await devices.release(request.params.serial))
  })

  app.post<{ Params: { serial: string } }>(
    '/api/v1/devices/:serial/remote-connect',
    async (request, reply) => reply.send(await devices.remoteConnect(request.params.serial)),
  )

  app.setErrorHandler((error, _request, reply) => {
    const failure = error instanceof MobileMatrixError
      ? error
      : new MobileMatrixError('internal_error', 'Mobile Matrix request failed', { cause: error })
    return reply.code(failure.statusCode).send({
      error: {
        code: failure.code,
        message: failure.message,
      },
    })
  })

  return app
}
