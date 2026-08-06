import { loadConfig } from './config.js'
import { StfHttpClient } from './adapters/stf-http-client.js'
import { buildApp } from './http/app.js'
import { startServer } from './http/server.js'

const config = loadConfig()
const stf = new StfHttpClient(config)
const app = buildApp({ stf, config })

await startServer(app, config)
