import type { FastifyInstance } from 'fastify'
import type { AppConfig } from '../config.js'

export async function startServer(app: FastifyInstance, config: AppConfig): Promise<string> {
  return app.listen({ host: '127.0.0.1', port: config.port })
}
