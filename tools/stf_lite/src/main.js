'use strict'

const crypto = require('crypto')
const fs = require('fs')
const http = require('http')
const net = require('net')
const os = require('os')
const path = require('path')
const {execFile, spawn} = require('child_process')
const {URL} = require('url')

const VERSION = '0.1.0'
const DEFAULT_HOST = '127.0.0.1'
const MAX_BODY_BYTES = 1024 * 1024
const RETRY_BASE_MS = 1000
const RETRY_MAX_MS = 30000

function parseArgs(argv) {
  const options = {
    adbPath: process.env.MOBILE_MATRIX_ADB || 'adb',
    host: DEFAULT_HOST,
    port: 0,
    pollMs: 1000,
    resourceDir: '',
    serial: '',
  }

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index]
    if (!argument.startsWith('--')) continue
    const equals = argument.indexOf('=')
    const key = equals === -1 ? argument.slice(2) : argument.slice(2, equals)
    const inlineValue = equals === -1 ? null : argument.slice(equals + 1)
    const value = inlineValue === null ? argv[++index] : inlineValue
    if (value === undefined) throw new Error(`Missing value for --${key}`)

    switch (key) {
      case 'adb-path':
        options.adbPath = value
        break
      case 'host':
        options.host = value
        break
      case 'port':
        options.port = Number(value)
        break
      case 'poll-ms':
        options.pollMs = Math.max(250, Number(value))
        break
      case 'resource-dir':
        options.resourceDir = path.resolve(value)
        break
      case 'serial':
        options.serial = value
        break
      default:
        throw new Error(`Unknown option --${key}`)
    }
  }

  if (!Number.isInteger(options.port) || options.port < 0 || options.port > 65535) {
    throw new Error('Port must be an integer between 0 and 65535')
  }
  if (!Number.isFinite(options.pollMs)) throw new Error('Invalid poll interval')
  return options
}

function log(level, message, details = {}) {
  const record = {
    at: new Date().toISOString(),
    level,
    component: 'stf-lite',
    message,
    ...details,
  }
  process.stderr.write(`${JSON.stringify(record)}\n`)
}

function serialForLog(serial) {
  return String(serial || '').replace(/[^a-zA-Z0-9._:-]/g, '?')
}

function execFileAsync(file, args, options = {}) {
  return new Promise((resolve, reject) => {
    execFile(file, args, {
      ...options,
      maxBuffer: options.maxBuffer || 8 * 1024 * 1024,
    }, (error, stdout, stderr) => {
      if (error) {
        error.stdout = stdout
        error.stderr = stderr
        reject(error)
        return
      }
      resolve({stdout: String(stdout || ''), stderr: String(stderr || '')})
    })
  })
}

async function listen(server, host, port) {
  await new Promise((resolve, reject) => {
    const onError = error => {
      server.removeListener('listening', onListening)
      reject(error)
    }
    const onListening = () => {
      server.removeListener('error', onError)
      resolve()
    }
    server.once('error', onError)
    server.once('listening', onListening)
    server.listen(port, host)
  })
}

function sendJson(response, status, payload) {
  const body = JSON.stringify(payload)
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'cache-control': 'no-store',
  })
  response.end(body)
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let size = 0
    const chunks = []
    request.on('data', chunk => {
      size += chunk.length
      if (size > MAX_BODY_BYTES) {
        reject(new Error('Request body is too large'))
        request.destroy()
        return
      }
      chunks.push(chunk)
    })
    request.on('end', () => {
      if (chunks.length === 0) {
        resolve({})
        return
      }
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')))
      } catch (error) {
        reject(new Error(`Invalid JSON request: ${error.message}`))
      }
    })
    request.on('error', reject)
  })
}

function parseAdbDevices(output, filter) {
  const devices = new Map()
  for (const rawLine of output.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (!line || line.startsWith('List of devices attached')) continue
    const parts = line.split(/\s+/)
    if (parts.length < 2) continue
    const serial = parts[0]
    const status = parts[1]
    if (filter && serial !== filter) continue
    const metadata = {serial, status, model: serial}
    for (const token of parts.slice(2)) {
      if (token.startsWith('model:')) metadata.model = token.slice(6)
      if (token.startsWith('device:') && metadata.model === serial) {
        metadata.model = token.slice(7)
      }
    }
    devices.set(serial, metadata)
  }
  return devices
}

function safePathCandidate(candidates) {
  return candidates.find(candidate => candidate && fs.existsSync(candidate)) || null
}

function findAndroidBinary(root, packageName, abi, fileName) {
  return safePathCandidate([
    path.join(root, `${packageName}-prebuilt`, 'prebuilt', abi, 'bin', fileName),
    path.join(root, '@devicefarmer', `${packageName}-prebuilt`, 'prebuilt', abi, 'bin', fileName),
    path.join(root, 'node_modules', '@devicefarmer', `${packageName}-prebuilt`, 'prebuilt', abi, 'bin', fileName),
  ])
}

function findMinicapLibrary(root, abi, sdk) {
  const roots = [
    path.join(root, 'minicap-prebuilt', 'prebuilt', abi, 'lib'),
    path.join(root, '@devicefarmer', 'minicap-prebuilt', 'prebuilt', abi, 'lib'),
    path.join(root, 'node_modules', '@devicefarmer', 'minicap-prebuilt', 'prebuilt', abi, 'lib'),
  ]
  const candidates = []
  for (const libRoot of roots) {
    if (!fs.existsSync(libRoot)) continue
    for (const entry of fs.readdirSync(libRoot)) {
      const match = /^android-(\d+)$/.exec(entry)
      if (match && Number(match[1]) <= sdk) {
        candidates.push({sdk: Number(match[1]), file: path.join(libRoot, entry, 'minicap.so')})
      }
    }
  }
  candidates.sort((left, right) => right.sdk - left.sdk)
  return safePathCandidate(candidates.map(candidate => candidate.file))
}

function findMinicapApk(root) {
  return safePathCandidate([
    path.join(root, 'minicap-prebuilt', 'prebuilt', 'noarch', 'minicap.apk'),
    path.join(root, '@devicefarmer', 'minicap-prebuilt', 'prebuilt', 'noarch', 'minicap.apk'),
    path.join(root, 'node_modules', '@devicefarmer', 'minicap-prebuilt', 'prebuilt', 'noarch', 'minicap.apk'),
    path.join(root, 'minicap.apk'),
  ])
}

function findStfServiceApk(root) {
  return safePathCandidate([
    path.join(root, 'STFService', 'STFService.apk'),
    path.join(root, 'vendor', 'STFService', 'STFService.apk'),
    path.join(root, 'STFService.apk'),
  ])
}

function findInputBridge(root) {
  return safePathCandidate([
    path.join(root, 'stf-input-bridge.dex.jar'),
    path.join(root, 'input_bridge', 'stf-input-bridge.dex.jar'),
    path.join(__dirname, '..', 'input_bridge', 'stf-input-bridge.dex.jar'),
  ])
}

const CANONICAL_KEY_CODES = Object.freeze({
  '0': 7,
  '1': 8,
  '2': 9,
  '3': 10,
  '4': 11,
  '5': 12,
  '6': 13,
  '7': 14,
  '8': 15,
  '9': 16,
  a: 29,
  b: 30,
  c: 31,
  d: 32,
  e: 33,
  f: 34,
  g: 35,
  h: 36,
  i: 37,
  j: 38,
  k: 39,
  l: 40,
  m: 41,
  n: 42,
  o: 43,
  p: 44,
  q: 45,
  r: 46,
  s: 47,
  t: 48,
  u: 49,
  v: 50,
  w: 51,
  x: 52,
  y: 53,
  z: 54,
  soft_left: 1,
  soft_right: 2,
  home: 3,
  back: 4,
  call: 5,
  endcall: 6,
  clear: 28,
  camera: 27,
  power: 26,
  volume_up: 24,
  volume_down: 25,
  enter: 66,
  del: 67,
  tab: 61,
  space: 62,
  sym: 63,
  escape: 111,
  forward_del: 112,
  dpad_up: 19,
  dpad_down: 20,
  dpad_left: 21,
  dpad_right: 22,
  dpad_center: 23,
  menu: 82,
  app_switch: 187,
  search: 84,
  mute: 91,
  volume_mute: 164,
  page_up: 92,
  page_down: 93,
  move_home: 122,
  move_end: 123,
  insert: 124,
  switch_charset: 95,
  minus: 69,
  equals: 70,
  comma: 55,
  period: 56,
  semicolon: 74,
  slash: 76,
  backslash: 73,
  grave: 68,
  left_bracket: 71,
  right_bracket: 72,
  apostrophe: 75,
  at: 77,
  plus: 81,
  pound: 18,
  shift_left: 59,
  shift_right: 60,
  ctrl_left: 113,
  ctrl_right: 114,
  alt_left: 57,
  alt_right: 58,
  meta_left: 117,
  meta_right: 118,
  function: 119,
  sysrq: 120,
  caps_lock: 115,
  scroll_lock: 116,
  num_lock: 143,
  f1: 131,
  f2: 132,
  f3: 133,
  f4: 134,
  f5: 135,
  f6: 136,
  f7: 137,
  f8: 138,
  f9: 139,
  f10: 140,
  f11: 141,
  f12: 142,
  media_rewind: 89,
  media_previous: 88,
  media_play: 126,
  media_play_pause: 85,
  media_pause: 127,
  media_stop: 86,
  media_next: 87,
  media_fast_forward: 90,
  media_record: 130,
  numpad_0: 144,
  numpad_1: 145,
  numpad_2: 146,
  numpad_3: 147,
  numpad_4: 148,
  numpad_5: 149,
  numpad_6: 150,
  numpad_7: 151,
  numpad_8: 152,
  numpad_9: 153,
  numpad_divide: 154,
  numpad_multiply: 155,
  numpad_subtract: 156,
  numpad_add: 157,
  numpad_dot: 158,
  numpad_comma: 159,
  numpad_enter: 160,
  numpad_equals: 161,
})

const KEY_ALIASES = Object.freeze({
  delete: 'del',
  backspace: 'del',
  forward_delete: 'forward_del',
  esc: 'escape',
  up: 'dpad_up',
  down: 'dpad_down',
  left: 'dpad_left',
  right: 'dpad_right',
  arrow_up: 'dpad_up',
  arrow_down: 'dpad_down',
  arrow_left: 'dpad_left',
  arrow_right: 'dpad_right',
  pageup: 'page_up',
  pagedown: 'page_down',
  home_key: 'move_home',
  end_key: 'move_end',
  dash: 'minus',
  subtract: 'minus',
  equal_sign: 'equals',
  open_bracket: 'left_bracket',
  close_bracket: 'right_bracket',
  single_quote: 'apostrophe',
  grave_accent: 'grave',
  volume_mute_key: 'volume_mute',
  ctrl: 'ctrl_left',
  control: 'ctrl_left',
  shift: 'shift_left',
  alt: 'alt_left',
  meta: 'meta_left',
  app_switcher: 'app_switch',
  numpad_decimal: 'numpad_dot',
  decimal_point: 'numpad_dot',
  multiply: 'numpad_multiply',
  add: 'numpad_add',
  divide: 'numpad_divide',
  numpad_subtract: 'numpad_subtract',
})

function normalizeKeyName(key) {
  if (typeof key !== 'string') return null
  const name = key.trim().toLowerCase().replace(/[\s-]+/g, '_')
  if (!name) return null
  const canonical = KEY_ALIASES[name] || name
  return Object.prototype.hasOwnProperty.call(CANONICAL_KEY_CODES, canonical) ? canonical : null
}

function resolveKey(key) {
  if (typeof key === 'number' && Number.isInteger(key) && key > 0 && key <= 300) {
    return {canonicalKey: String(key), keyCode: key}
  }
  const canonicalKey = normalizeKeyName(key)
  if (canonicalKey) return {canonicalKey, keyCode: CANONICAL_KEY_CODES[canonicalKey]}
  if (typeof key === 'string' && /^\d+$/.test(key.trim())) {
    const numeric = Number(key.trim())
    if (numeric > 0 && numeric <= 300) return {canonicalKey: String(numeric), keyCode: numeric}
  }
  return null
}

function normalizeKeyAction(action) {
  const normalized = String(action || '').trim().toLowerCase()
  return ['down', 'up', 'press'].includes(normalized) ? normalized : null
}

function normalizeModifiers(modifiers) {
  const input = modifiers && typeof modifiers === 'object' ? modifiers : {}
  return {
    shift: input.shift === true,
    ctrl: input.ctrl === true,
    alt: input.alt === true,
    meta: input.meta === true,
    sym: input.sym === true,
    function: input.function === true,
    capsLock: input.capsLock === true,
    scrollLock: input.scrollLock === true,
    numLock: input.numLock === true,
  }
}

function androidMetaState(modifiers) {
  const metaBits = {
    shift: 0x1,
    alt: 0x2,
    sym: 0x4,
    function: 0x8,
    ctrl: 0x1000,
    meta: 0x10000,
    capsLock: 0x100000,
    numLock: 0x200000,
    scrollLock: 0x400000,
  }
  return Object.entries(metaBits).reduce(
    (state, [name, bit]) => state | (modifiers[name] ? bit : 0),
    0,
  )
}

function encodeVarint(value) {
  const bytes = []
  let remaining = value >>> 0
  do {
    let byte = remaining & 0x7f
    remaining >>>= 7
    if (remaining) byte |= 0x80
    bytes.push(byte)
  } while (remaining)
  return Buffer.from(bytes)
}

function protoVarintField(field, value) {
  return Buffer.concat([encodeVarint(field << 3), encodeVarint(value)])
}

function protoBytesField(field, value) {
  const bytes = Buffer.isBuffer(value) ? value : Buffer.from(value)
  return Buffer.concat([encodeVarint((field << 3) | 2), encodeVarint(bytes.length), bytes])
}

function encodeSetClipboardFrame(requestId, text) {
  const request = Buffer.concat([
    protoVarintField(1, 1),
    protoBytesField(2, Buffer.from(text, 'utf8')),
  ])
  const envelope = Buffer.concat([
    protoVarintField(1, requestId),
    protoVarintField(2, 9),
    protoBytesField(3, request),
  ])
  return Buffer.concat([encodeVarint(envelope.length), envelope])
}

function encodeKeyEventFrame(action, keyCode, modifiers) {
  const event = action === 'down' ? 0 : action === 'up' ? 1 : 2
  const fields = [
    protoVarintField(1, event),
    protoVarintField(2, keyCode),
  ]
  const modifierFields = [
    ['shift', 3],
    ['ctrl', 4],
    ['alt', 5],
    ['meta', 6],
    ['sym', 7],
    ['function', 8],
    ['capsLock', 9],
    ['scrollLock', 10],
    ['numLock', 11],
  ]
  for (const [name, field] of modifierFields) {
    if (modifiers[name]) fields.push(protoVarintField(field, 1))
  }
  const envelope = Buffer.concat([
    protoVarintField(2, 2),
    protoBytesField(3, Buffer.concat(fields)),
  ])
  return Buffer.concat([encodeVarint(envelope.length), envelope])
}

function takeLengthFrame(buffer) {
  let value = 0
  let shift = 0
  for (let index = 0; index < buffer.length && index < 5; index += 1) {
    const byte = buffer[index]
    value |= (byte & 0x7f) << shift
    if ((byte & 0x80) === 0) {
      const start = index + 1
      if (buffer.length - start < value) return null
      return {frame: buffer.subarray(start, start + value), rest: buffer.subarray(start + value)}
    }
    shift += 7
  }
  return null
}

function decodeSuccess(message) {
  let offset = 0
  while (offset < message.length) {
    const tag = message[offset++]
    const field = tag >> 3
    const wireType = tag & 0x07
    if (field === 1 && wireType === 0) return message[offset++] !== 0
    if (wireType === 0) {
      while (offset < message.length && (message[offset++] & 0x80)) {}
    } else if (wireType === 2) {
      const length = message[offset++]
      offset += length
    } else if (wireType === 1) {
      offset += 8
    } else if (wireType === 5) {
      offset += 4
    } else {
      break
    }
  }
  return false
}

function websocketAccept(key) {
  return crypto.createHash('sha1')
    .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest('base64')
}

function websocketFrame(opcode, payload) {
  const data = Buffer.isBuffer(payload) ? payload : Buffer.from(payload)
  let header
  if (data.length < 126) {
    header = Buffer.from([0x80 | opcode, data.length])
  } else if (data.length <= 0xffff) {
    header = Buffer.alloc(4)
    header[0] = 0x80 | opcode
    header[1] = 126
    header.writeUInt16BE(data.length, 2)
  } else {
    header = Buffer.alloc(10)
    header[0] = 0x80 | opcode
    header[1] = 127
    header.writeBigUInt64BE(BigInt(data.length), 2)
  }
  return Buffer.concat([header, data])
}

class WebSocketPeer {
  constructor(socket, onMessage, onClose) {
    this.socket = socket
    this.onMessage = onMessage
    this.onClose = onClose
    this.buffer = Buffer.alloc(0)
    this.closed = false
    this.active = false
    socket.on('data', chunk => this._read(chunk))
    socket.on('error', () => this.close())
    socket.on('close', () => this.close())
  }

  sendBinary(data) {
    if (!this.closed && !this.socket.destroyed) this.socket.write(websocketFrame(2, data))
  }

  sendText(data) {
    if (!this.closed && !this.socket.destroyed) this.socket.write(websocketFrame(1, data))
  }

  _read(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk])
    try {
      while (true) {
        const frame = this._takeFrame()
        if (!frame) return
        if (frame.opcode === 0x8) {
          this.close()
          return
        }
        if (frame.opcode === 0x9) {
          this.socket.write(websocketFrame(0xa, frame.payload))
        } else if (frame.opcode === 0x1) {
          this.onMessage(frame.payload.toString('utf8'), this)
        }
      }
    } catch (_) {
      this.close()
    }
  }

  _takeFrame() {
    if (this.buffer.length < 2) return null
    const first = this.buffer[0]
    const second = this.buffer[1]
    const opcode = first & 0x0f
    const masked = (second & 0x80) !== 0
    let length = second & 0x7f
    let offset = 2
    if (length === 126) {
      if (this.buffer.length < 4) return null
      length = this.buffer.readUInt16BE(2)
      offset = 4
    } else if (length === 127) {
      if (this.buffer.length < 10) return null
      const longLength = this.buffer.readBigUInt64BE(2)
      if (longLength > BigInt(MAX_BODY_BYTES)) throw new Error('WebSocket frame is too large')
      length = Number(longLength)
      offset = 10
    }
    if (!masked) throw new Error('Client WebSocket frames must be masked')
    if (this.buffer.length < offset + 4 + length) return null
    const mask = this.buffer.subarray(offset, offset + 4)
    offset += 4
    const payload = Buffer.alloc(length)
    for (let index = 0; index < length; index += 1) {
      payload[index] = this.buffer[offset + index] ^ mask[index % 4]
    }
    this.buffer = this.buffer.subarray(offset + length)
    return {opcode, payload}
  }

  close() {
    if (this.closed) return
    this.closed = true
    this.onClose(this)
    if (!this.socket.destroyed) this.socket.end()
  }
}

class DeviceSession {
  constructor(runtime, metadata) {
    this.runtime = runtime
    this.serial = metadata.serial
    this.metadata = metadata
    this.state = 'starting'
    this.lastError = null
    this.retryCount = 0
    this.retryTimer = null
    this.startPromise = null
    this.processes = new Set()
    this.forwards = new Set()
    this.screenClients = new Set()
    this.controlClients = new Set()
    this.screenSocket = null
    this.screenBuffer = Buffer.alloc(0)
    this.screenHeaderLength = null
    this.touchSocket = null
    this.touchBuffer = Buffer.alloc(0)
    this.touchReady = false
    this.touchMode = 'adb-input'
    this.touchWarning = null
    this.touchProcess = null
    this.touchLimits = {maxX: 1, maxY: 1, maxPressure: 1}
    this.touchQueue = Promise.resolve()
    this.gestures = new Map()
    this.screenPort = null
    this.touchPort = null
    this.servicePort = null
    this.agentPort = null
    this.agentSocket = null
    this.agentProcess = null
    this.agentStartPromise = null
    this.stfServiceReady = false
    this.stfServicePath = null
    this.stfServiceStartPromise = null
    this.serviceRequestId = 0
    this.width = 0
    this.height = 0
    this.inputWidth = 0
    this.inputHeight = 0
    this.rotation = 0
    this.sdk = 0
    this.abi = ''
    this.minicapMode = ''
    this.minicapBin = null
    this.minicapLib = null
    this.minicapApk = null
    this.minitouchBin = null
    this.stfServiceApk = null
    this.inputBridgeJar = null
    this.inputBridgeProcess = null
    this.inputBridgeStartPromise = null
    this.inputBridgeBuffer = ''
    this.inputKeyRequests = new Map()
    this.inputKeySequence = 0
    this.remoteRoot = `/data/local/tmp/mobile-matrix-stf-lite-${crypto.createHash('sha1').update(this.serial).digest('hex').slice(0, 12)}`
    this.present = true
  }

  toJSON() {
    return {
      serial: this.serial,
      model: this.metadata.model,
      status: this.state,
      present: this.present,
      width: this.width,
      height: this.height,
      inputWidth: this.inputWidth,
      inputHeight: this.inputHeight,
      rotation: this.rotation,
      screenUrl: this.present ? `ws://${this.runtime.host}:${this.runtime.port}/v1/sessions/${encodeURIComponent(this.serial)}/screen` : null,
      controlUrl: `http://${this.runtime.host}:${this.runtime.port}/v1/sessions/${encodeURIComponent(this.serial)}/control`,
      controlStreamUrl: `ws://${this.runtime.host}:${this.runtime.port}/v1/sessions/${encodeURIComponent(this.serial)}/control-stream`,
      clipboard: Boolean(this.stfServiceApk),
      touchMode: this.touchMode,
      touchWarning: this.touchWarning,
      lastError: this.lastError,
    }
  }

  async reconcile(metadata) {
    this.metadata = metadata
    this.present = metadata.status === 'device'
    if (!this.present) {
      await this.disconnect('ADB device is no longer available')
      return
    }
    if (this.state === 'disconnected' || this.state === 'error') this.start()
  }

  start() {
    if (this.startPromise || this.state === 'ready' || this.state === 'stopping') return
    this.state = 'starting'
    this.startPromise = this._start().finally(() => {
      this.startPromise = null
    })
  }

  async _start() {
    try {
      await this._readDeviceInfo()
      this._resolveResources()
      await this._prepareDeviceResources()
      await this._startMinicap()
      try {
        await this._startMinitouch()
        this.touchMode = 'minitouch'
        this.touchWarning = null
      } catch (error) {
        // Android 15 commonly blocks minitouch from opening /dev/input. Use a
        // persistent framework-level injector when available so the whole
        // gesture keeps one downTime, rather than issuing isolated commands.
        this.touchMode = 'adb-input'
        this.touchWarning = this._publicError(error)
        await this._closeTouchChannel()
        const bridgeStarted = this.sdk >= 30 && this.inputBridgeJar
          ? await this._startInputBridge()
          : false
        if (bridgeStarted) this.touchMode = 'adb-input-bridge'
        log('warn', bridgeStarted
          ? 'minitouch unavailable; using persistent ADB input bridge'
          : 'minitouch unavailable; using ADB input fallback', {
          serial: serialForLog(this.serial),
          error: this.touchWarning,
          touchMode: this.touchMode,
        })
      }
      if (this.state === 'error') {
        throw this._stageError('screen', this.lastError || 'minicap screen service is unavailable')
      }
      this.retryCount = 0
      this.lastError = null
      this.state = 'ready'
      log('info', 'device session ready', {serial: serialForLog(this.serial), abi: this.abi})
    } catch (error) {
      this.state = 'error'
      this.lastError = this._publicError(error)
      log('error', 'device session failed', {
        serial: serialForLog(this.serial),
        stage: error.stage || 'startup',
        error: this.lastError,
      })
      await this._closeDeviceChannels()
      this._scheduleRetry()
    }
  }

  _publicError(error) {
    if (error && error.publicMessage) return error.publicMessage
    return String(error && error.message || error).replace(/\/[^\s]+/g, '<path>')
  }

  async _readDeviceInfo() {
    const properties = await Promise.all([
      this._shell('getprop ro.product.cpu.abilist'),
      this._shell('getprop ro.product.cpu.abi'),
      this._shell('getprop ro.build.version.sdk'),
      this._shell('wm size'),
      this._shell('settings get system user_rotation'),
    ])
    const abiList = properties[0].trim() || properties[1].trim()
    this.abi = (abiList.split(',').map(value => value.trim()).find(Boolean) || 'arm64-v8a')
    this.sdk = Number(properties[2].trim()) || 0
    const sizeMatches = Array.from(properties[3].matchAll(/(\d+)x(\d+)/g))
    const physicalSize = sizeMatches[0]
    const logicalSize = sizeMatches[sizeMatches.length - 1]
    this.width = physicalSize ? Number(physicalSize[1]) : 0
    this.height = physicalSize ? Number(physicalSize[2]) : 0
    this.inputWidth = logicalSize ? Number(logicalSize[1]) : this.width
    this.inputHeight = logicalSize ? Number(logicalSize[2]) : this.height
    this.rotation = ((Number(properties[4].trim()) || 0) * 90) % 360
    if (!this.width || !this.height) throw this._stageError('device-info', 'Device display size is unavailable')
  }

  _resolveResources() {
    const root = this.runtime.resourceDir
    if (!root) throw this._stageError('resources', 'STF Lite resource directory is not configured')
    const abiCandidates = [this.abi, 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86']
    for (const abi of abiCandidates) {
      const bin = findAndroidBinary(root, 'minicap', abi, 'minicap')
      const touch = findAndroidBinary(root, 'minitouch', abi, 'minitouch')
      if (bin && touch) {
        this.minicapBin = bin
        this.minitouchBin = touch
        this.abi = abi
        break
      }
    }
    this.minicapLib = this.minicapBin ? findMinicapLibrary(root, this.abi, this.sdk) : null
    this.minicapApk = findMinicapApk(root)
    this.stfServiceApk = findStfServiceApk(root)
    this.inputBridgeJar = findInputBridge(root)
    if (!this.minicapBin && !this.minicapApk) {
      throw this._stageError('resources', 'minicap resource is missing')
    }
    if (!this.minitouchBin) throw this._stageError('resources', 'minitouch resource is missing')
    // The APK launcher is more compatible with newer Android framework
    // symbols. Use the native binary only when the universal APK is absent.
    this.minicapMode = this.minicapApk ? 'apk' : 'native'
    if (this.minicapMode === 'native' && !this.minicapLib) {
      throw this._stageError('resources', 'minicap native library is missing')
    }
  }

  _stageError(stage, message) {
    const error = new Error(message)
    error.stage = stage
    error.publicMessage = message
    return error
  }

  async _prepareDeviceResources() {
    await this._shell(`mkdir -p ${this.remoteRoot}`)
    if (this.minicapMode === 'native') {
      await this._push(this.minicapBin, `${this.remoteRoot}/minicap`, 0o755)
      // The native executable has a DT_NEEDED entry for the literal name
      // `minicap.so`, so keep that name inside this session-owned directory.
      await this._push(this.minicapLib, `${this.remoteRoot}/minicap.so`, 0o755)
    } else {
      await this._push(this.minicapApk, `${this.remoteRoot}/minicap.apk`, 0o644)
    }
    await this._push(this.minitouchBin, `${this.remoteRoot}/minitouch`, 0o755)
    if (this.inputBridgeJar) {
      await this._push(this.inputBridgeJar, `${this.remoteRoot}/stf-input-bridge.dex.jar`, 0o644)
    }
  }

  async _push(localPath, remotePath, mode) {
    try {
      await execFileAsync(this.runtime.adbPath, ['-s', this.serial, 'push', localPath, remotePath], {timeout: 20000})
      if (mode) await this._shell(`chmod ${mode.toString(8)} ${remotePath}`)
    } catch (error) {
      throw this._stageError('resources', `Unable to install ${path.basename(localPath)}`)
    }
  }

  async _shell(command) {
    try {
      const result = await execFileAsync(this.runtime.adbPath, ['-s', this.serial, 'shell', command], {timeout: 15000})
      if (result.stderr.trim() && /^error/i.test(result.stderr.trim())) {
        throw new Error(result.stderr.trim())
      }
      return result.stdout
    } catch (error) {
      const wrapped = new Error(error.stderr || error.message || `ADB shell failed: ${command}`)
      wrapped.stage = 'adb'
      throw wrapped
    }
  }

  async _forward(socketName) {
    const result = await execFileAsync(this.runtime.adbPath, [
      '-s', this.serial, 'forward', 'tcp:0', socketName,
    ], {timeout: 5000})
    const port = Number(result.stdout.trim())
    if (!port) throw this._stageError('forward', `ADB forward failed for ${socketName}`)
    this.forwards.add(port)
    return port
  }

  async _removeForward(port) {
    if (!port) return
    this.forwards.delete(port)
    try {
      await execFileAsync(this.runtime.adbPath, [
        '-s', this.serial, 'forward', '--remove', `tcp:${port}`,
      ], {timeout: 3000})
    } catch (_) {
      // The ADB server may already have removed a forward after disconnect.
    }
  }

  async _startMinicap() {
    const virtualWidth = Math.max(1, Math.round(this.width * 0.6))
    const virtualHeight = Math.max(1, Math.round(this.height * 0.6))
    const projection = `${this.width}x${this.height}@${virtualWidth}x${virtualHeight}/0`
    const command = this.minicapMode === 'native'
      ? `LD_LIBRARY_PATH=${this.remoteRoot} exec ${this.remoteRoot}/minicap -S -r 60 -Q 80 -P ${projection}`
      : `CLASSPATH=${this.remoteRoot}/minicap.apk app_process /system/bin io.devicefarmer.minicap.Main -S -r 60 -Q 80 -P ${projection}`
    const process = spawn(this.runtime.adbPath, ['-s', this.serial, 'shell', command], {
      stdio: ['ignore', 'pipe', 'pipe'],
    })
    this.processes.add(process)
    const processReady = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(this._stageError('minicap', 'minicap startup timeout')), 5000)
      const onOutput = data => {
        this._logChild('minicap', data)
        if (data.toString('utf8').includes('Listening on socket')) {
          clearTimeout(timeout)
          process.stdout.removeListener('data', onOutput)
          process.stderr.removeListener('data', onOutput)
          resolve()
        }
      }
      process.stdout.on('data', onOutput)
      process.stderr.on('data', onOutput)
      process.once('exit', (code, signal) => {
        if (code !== 0 || signal !== null) {
          clearTimeout(timeout)
          reject(this._stageError('minicap', `minicap exited before startup (${code || signal})`))
        }
      })
    })
    process.once('exit', (code, signal) => {
      this.processes.delete(process)
      log('debug', 'device component exited', {
        serial: serialForLog(this.serial),
        component: 'minicap',
        code,
        signal,
      })
      if (this.state !== 'stopping' && this.state !== 'disconnected') {
        this._componentLost('minicap', 'minicap process exited')
      }
    })

    await processReady
    this.screenPort = await this._forward('localabstract:minicap')
    this.screenSocket = await this._connectLocal(this.screenPort)
    this.screenSocket.on('data', chunk => this._readScreen(chunk))
    this.screenSocket.on('error', () => this._componentLost('minicap', 'minicap socket failed'))
    this.screenSocket.on('close', () => this._componentLost('minicap', 'minicap socket closed'))
  }

  _logChild(component, data) {
    const text = data.toString('utf8').trim()
    if (text) log('debug', `${component} output`, {serial: serialForLog(this.serial), output: text.slice(0, 300)})
  }

  async _startMinitouch() {
    this.touchPort = await this._forward('localabstract:minitouch')
    const process = spawn(this.runtime.adbPath, [
      '-s', this.serial, 'shell', `exec ${this.remoteRoot}/minitouch`,
    ], {stdio: ['ignore', 'pipe', 'pipe']})
    this.touchProcess = process
    this.processes.add(process)
    process.stdout.on('data', data => this._readTouchBanner(data))
    process.stderr.on('data', data => this._logChild('minitouch', data))
    process.once('exit', (code, signal) => {
      this.processes.delete(process)
      if (this.touchProcess === process) this.touchProcess = null
      log('debug', 'device component exited', {
        serial: serialForLog(this.serial),
        component: 'minitouch',
        code,
        signal,
      })
      if (this.state !== 'stopping' && this.state !== 'disconnected') {
        this._componentLost('minitouch', 'minitouch process exited')
      }
    })
    this.touchSocket = await this._connectLocal(this.touchPort)
    this.touchSocket.on('data', data => this._readTouchBanner(data))
    this.touchSocket.on('error', () => this._componentLost('minitouch', 'minitouch socket failed'))
    this.touchSocket.on('close', () => this._componentLost('minitouch', 'minitouch socket closed'))
    await new Promise((resolve, reject) => {
      const deadline = setTimeout(() => reject(this._stageError('minitouch', 'minitouch banner timeout')), 3000)
      const check = () => {
        if (this.touchReady) {
          clearTimeout(deadline)
          resolve()
        } else setTimeout(check, 20)
      }
      check()
    })
  }

  _startInputBridge() {
    if (!this.inputBridgeJar) return Promise.resolve(false)
    if (this.inputBridgeProcess && this.inputBridgeProcess.exitCode === null) {
      return Promise.resolve(true)
    }
    if (this.inputBridgeStartPromise) return this.inputBridgeStartPromise
    this.inputBridgeStartPromise = this._launchInputBridge().finally(() => {
      this.inputBridgeStartPromise = null
    })
    return this.inputBridgeStartPromise
  }

  async _launchInputBridge() {
    const command = `CLASSPATH=${this.remoteRoot}/stf-input-bridge.dex.jar app_process /system/bin StfInputBridge`
    const child = spawn(this.runtime.adbPath, ['-s', this.serial, 'shell', command], {
      stdio: ['pipe', 'pipe', 'pipe'],
    })
    this.inputBridgeProcess = child
    this.inputBridgeBuffer = ''
    this.processes.add(child)
    child.stdout.on('data', data => this._readInputBridge(data))
    child.stderr.on('data', data => this._logChild('input-bridge', data))
    child.once('exit', (code, signal) => {
      this.processes.delete(child)
      this._failPendingInputKeys(this._stageError('control', 'ADB input bridge exited'))
      if (this.inputBridgeProcess === child) {
        this.inputBridgeProcess = null
        if (this.touchMode === 'adb-input-bridge') {
          this.touchMode = 'adb-input'
          this.touchWarning = 'ADB input bridge exited'
        }
      }
      log('debug', 'device component exited', {
        serial: serialForLog(this.serial),
        component: 'input-bridge',
        code,
        signal,
      })
    })
    await new Promise(resolve => setTimeout(resolve, 150))
    if (child.exitCode !== null || child.stdin.destroyed || child.stdin.writableEnded) {
      if (this.inputBridgeProcess === child) this.inputBridgeProcess = null
      this.processes.delete(child)
      child.kill('SIGTERM')
      return false
    }
    return true
  }

  _readInputBridge(chunk) {
    this.inputBridgeBuffer += chunk.toString('utf8')
    const lines = this.inputBridgeBuffer.split(/\r?\n/)
    this.inputBridgeBuffer = lines.pop() || ''
    for (const line of lines) {
      const trimmed = line.trim()
      if (!trimmed) continue
      const parts = trimmed.split(/\s+/)
      if (parts[0] !== 'KEY_RESULT' || parts.length < 3) {
        this._logChild('input-bridge', trimmed)
        continue
      }
      const requestId = parts[1]
      const pending = this.inputKeyRequests.get(requestId)
      if (!pending) {
        log('debug', 'input bridge returned an unknown key request', {
          serial: serialForLog(this.serial),
          requestId,
        })
        continue
      }
      clearTimeout(pending.timeout)
      this.inputKeyRequests.delete(requestId)
      const success = parts[2].toLowerCase() === 'true'
      log('debug', 'ADB input bridge key result', {
        serial: serialForLog(this.serial),
        requestId,
        success,
        error: success ? null : parts.slice(3).join(' ') || 'inject_rejected',
      })
      pending.resolve(success)
    }
  }

  _failPendingInputKeys(error) {
    for (const [requestId, pending] of this.inputKeyRequests) {
      clearTimeout(pending.timeout)
      pending.reject(error)
      this.inputKeyRequests.delete(requestId)
    }
  }

  _readTouchBanner(chunk) {
    this.touchBuffer = Buffer.concat([this.touchBuffer, chunk])
    const text = this.touchBuffer.toString('utf8')
    const lines = text.split(/\r?\n/)
    this.touchBuffer = Buffer.from(lines.pop() || '', 'utf8')
    for (const line of lines) {
      const parts = line.trim().split(/\s+/)
      if (parts[0] === '^' && parts.length >= 5) {
        this.touchLimits = {
          maxX: Number(parts[2]) || 1,
          maxY: Number(parts[3]) || 1,
          maxPressure: Number(parts[4]) || 1,
        }
      }
      if (parts[0] === '$') this.touchReady = true
    }
  }

  _connectLocal(port, attempt = 0) {
    return new Promise((resolve, reject) => {
      const socket = net.createConnection({host: '127.0.0.1', port})
      let settled = false
      const retry = error => {
        if (settled) return
        settled = true
        socket.destroy()
        if (attempt < 20) {
          setTimeout(() => {
            this._connectLocal(port, attempt + 1).then(resolve, reject)
          }, 100)
          return
        }
        reject(this._stageError('connect', `Local device service unavailable on port ${port}`))
        log('debug', 'local device service connection failed', {serial: serialForLog(this.serial), error: error.message})
      }
      const timeout = setTimeout(() => {
        retry(new Error('connection timeout'))
      }, 5000)
      socket.once('connect', () => {
        if (settled) return
        settled = true
        clearTimeout(timeout)
        socket.setNoDelay(true)
        resolve(socket)
      })
      socket.once('error', retry)
    })
  }

  _readScreen(chunk) {
    this.screenBuffer = Buffer.concat([this.screenBuffer, chunk])
    while (true) {
      if (this.screenHeaderLength === null) {
        if (this.screenBuffer.length < 2) return
        this.screenHeaderLength = this.screenBuffer[1]
        if (this.screenBuffer.length < this.screenHeaderLength) return
        this.screenBuffer = this.screenBuffer.subarray(this.screenHeaderLength)
      }
      if (this.screenBuffer.length < 4) return
      const frameLength = this.screenBuffer.readUInt32LE(0)
      if (this.screenBuffer.length < frameLength + 4) return
      const frame = this.screenBuffer.subarray(4, frameLength + 4)
      this.screenBuffer = this.screenBuffer.subarray(frameLength + 4)
      for (const client of this.screenClients) {
        if (client.active) client.sendBinary(frame)
      }
    }
  }

  addScreenClient(socket, head) {
    const peer = new WebSocketPeer(socket, (message, client) => this._handleScreenCommand(message, client), client => {
      this.screenClients.delete(client)
    })
    this.screenClients.add(peer)
    if (head && head.length) peer._read(head)
    return peer
  }

  _handleScreenCommand(message, client) {
    const command = String(message || '').trim()
    if (command === 'on') {
      client.active = true
    } else if (command === 'off') {
      client.active = false
    } else if (
      /^size \d+x\d+$/.test(command) &&
      this.screenSocket &&
      !this.screenSocket.destroyed
    ) {
      // Projection changes are the only control command forwarded to the
      // minicap socket. `on`/`off` are sidecar client state, not minicap
      // commands; sending them to minicap would close the socket.
      this.screenSocket.write(command)
    }
  }

  addControlClient(socket, head) {
    const peer = new WebSocketPeer(socket, (message, client) => {
      this._handleControlMessage(message, client)
    }, client => {
      this.controlClients.delete(client)
      log('debug', 'control channel closed', {serial: serialForLog(this.serial)})
    })
    this.controlClients.add(peer)
    log('debug', 'control channel connected', {
      serial: serialForLog(this.serial),
      clients: this.controlClients.size,
    })
    if (head && head.length) peer._read(head)
    return peer
  }

  _handleControlMessage(message, client) {
    let payload
    try {
      payload = JSON.parse(String(message || ''))
    } catch (error) {
      client.sendText(JSON.stringify({success: false, error: 'Invalid control JSON'}))
      return
    }
    this.control(payload).then(result => {
      if (payload.type === 'key') {
        client.sendText(JSON.stringify(result))
      }
    }).catch(error => {
      log('warn', 'persistent control failed', {
        serial: serialForLog(this.serial),
        type: payload.type,
        requestId: payload.id || null,
        error: this._publicError(error),
      })
      if (payload.type === 'key') {
        client.sendText(JSON.stringify({
          success: false,
          serial: this.serial,
          id: payload.id || null,
          type: 'key',
          action: payload.action || null,
          key: payload.key ?? null,
          error: this._publicError(error),
        }))
      }
    })
  }

  control(payload) {
    if (this.state !== 'ready') return Promise.reject(this._stageError('control', 'Device session is not ready'))
    const operation = async () => {
      switch (payload.type) {
        case 'touchDown':
          if (this.touchMode === 'adb-input-bridge') return this._writeInputBridge('DOWN', payload)
          if (this.touchMode === 'adb-motionevent') return this._adbMotionEvent('DOWN', payload)
          if (this.touchMode === 'adb-input') return this._adbTouchDown(payload)
          return this._writeTouch(`d ${Number(payload.contact) || 0} ${this._touchX(payload.x)} ${this._touchY(payload.y)} ${this._touchPressure(payload.pressure)}\n`)
        case 'touchMove':
          if (this.touchMode === 'adb-input-bridge') return this._writeInputBridge('MOVE', payload)
          if (this.touchMode === 'adb-motionevent') return this._adbMotionEvent('MOVE', payload)
          if (this.touchMode === 'adb-input') return this._adbTouchMove(payload)
          return this._writeTouch(`m ${Number(payload.contact) || 0} ${this._touchX(payload.x)} ${this._touchY(payload.y)} ${this._touchPressure(payload.pressure)}\n`)
        case 'touchUp':
          if (this.touchMode === 'adb-input-bridge') return this._writeInputBridge('UP', payload)
          if (this.touchMode === 'adb-motionevent') return this._adbMotionEvent('UP', payload)
          if (this.touchMode === 'adb-input') return this._adbTouchUp(payload)
          return this._writeTouch(`u ${Number(payload.contact) || 0}\n`)
        case 'touchCommit':
          if (this.touchMode === 'adb-input' || this.touchMode === 'adb-motionevent' || this.touchMode === 'adb-input-bridge') return true
          return this._writeTouch('c\n')
        case 'gestureStart':
          return true
        case 'gestureStop':
          this.gestures.clear()
          return true
        case 'key':
          return this._handleKeyControl(payload)
        case 'rotation': {
          const rotation = Math.max(0, Math.min(3, Number(payload.rotation) || 0))
          this.rotation = rotation * 90
          await this._shell(`settings put system accelerometer_rotation 0 && settings put system user_rotation ${rotation}`)
          return true
        }
        default:
          throw this._stageError('control', `Unsupported control type: ${payload.type}`)
      }
    }
    const next = this.touchQueue.then(operation)
    this.touchQueue = next.catch(() => {})
    return next
  }

  _nextInputKeyId() {
    this.inputKeySequence += 1
    return `key-${serialForLog(this.serial)}-${this.inputKeySequence}`
  }

  async _handleKeyControl(payload) {
    const startedAt = Date.now()
    const requestId = String(payload.id || this._nextInputKeyId())
    const action = normalizeKeyAction(payload.action)
    const resolved = resolveKey(payload.key)
    const modifiers = normalizeModifiers(payload.modifiers)
    if (!action) {
      return this._keyResult({
        success: false,
        id: requestId,
        action: payload.action || null,
        canonicalKey: null,
        transport: 'none',
        error: 'Unsupported key action',
      }, startedAt)
    }
    if (!resolved) {
      return this._keyResult({
        success: false,
        id: requestId,
        action,
        canonicalKey: null,
        transport: 'none',
        error: `Unsupported key: ${payload.key}`,
      }, startedAt)
    }

    const base = {
      id: requestId,
      action,
      canonicalKey: resolved.canonicalKey,
      keyCode: resolved.keyCode,
    }
    try {
      if (this.inputBridgeJar) {
        try {
          if (await this._startInputBridge()) {
            const injected = await this._writeInputBridgeKey(
              requestId,
              action,
              resolved.keyCode,
              androidMetaState(modifiers),
            )
            return this._keyResult({
              ...base,
              success: injected,
              transport: 'input-bridge',
              acknowledged: injected,
              error: injected ? null : 'Device rejected key event',
            }, startedAt)
          }
        } catch (error) {
          log('warn', 'input bridge key event unavailable', {
            serial: serialForLog(this.serial),
            id: requestId,
            canonicalKey: resolved.canonicalKey,
            action,
            error: this._publicError(error),
          })
          if (error && error.code === 'input_bridge_timeout') {
            return this._keyResult({
              ...base,
              success: false,
              transport: 'input-bridge',
              acknowledged: false,
              error: this._publicError(error),
            }, startedAt)
          }
        }
      }

      if (this.stfServiceApk) {
        await this._sendStfServiceKeyEvent(
          requestId,
          action,
          resolved.keyCode,
          modifiers,
        )
        return this._keyResult({
          ...base,
          success: true,
          transport: 'stfservice',
          acknowledged: false,
        }, startedAt)
      }

      if (action === 'press') {
        await this._shell(`input keyevent ${resolved.keyCode}`)
        return this._keyResult({
          ...base,
          success: true,
          transport: 'adb-shell',
          acknowledged: false,
        }, startedAt)
      }
      return this._keyResult({
        ...base,
        success: false,
        transport: 'none',
        error: 'No continuous key event transport is available',
      }, startedAt)
    } catch (error) {
      return this._keyResult({
        ...base,
        success: false,
        transport: 'none',
        error: this._publicError(error),
      }, startedAt)
    }
  }

  _keyResult(result, startedAt) {
    const response = {
      success: result.success === true,
      serial: this.serial,
      id: result.id,
      type: 'key',
      action: result.action,
      key: result.canonicalKey,
      keyCode: result.keyCode ?? null,
      transport: result.transport,
      acknowledged: result.acknowledged === true,
      elapsedMs: Math.max(0, Date.now() - startedAt),
    }
    if (result.error) response.error = result.error
    log(response.success ? 'debug' : 'warn', 'keyboard event result', {
      serial: serialForLog(this.serial),
      requestId: response.id,
      canonicalKey: response.key,
      action: response.action,
      transport: response.transport,
      success: response.success,
      elapsedMs: response.elapsedMs,
      error: response.error || null,
    })
    return response
  }

  _writeInputBridgeKey(requestId, action, keyCode, metaState) {
    const child = this.inputBridgeProcess
    if (!child || child.exitCode !== null || child.stdin.destroyed || child.stdin.writableEnded) {
      return Promise.reject(this._stageError('control', 'ADB input bridge is unavailable'))
    }
    const safeId = requestId.replace(/\s+/g, '_')
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.inputKeyRequests.delete(safeId)
        const error = this._stageError('control', 'ADB input bridge key event timeout')
        error.code = 'input_bridge_timeout'
        reject(error)
      }, 3000)
      this.inputKeyRequests.set(safeId, {resolve, reject, timeout})
      const command = `KEY ${safeId} ${action.toUpperCase()} ${keyCode} ${metaState} 0\n`
      try {
        child.stdin.write(command, error => {
          if (!error) return
          const pending = this.inputKeyRequests.get(safeId)
          if (!pending) return
          clearTimeout(pending.timeout)
          this.inputKeyRequests.delete(safeId)
          pending.reject(this._stageError('control', `ADB input bridge write failed: ${error.message}`))
        })
        log('debug', 'ADB input bridge key request', {
          serial: serialForLog(this.serial),
          requestId: safeId,
          action,
          keyCode,
          metaState,
        })
      } catch (error) {
        clearTimeout(timeout)
        this.inputKeyRequests.delete(safeId)
        reject(this._stageError('control', `ADB input bridge write failed: ${error.message}`))
      }
    })
  }

  _touchX(value) {
    return Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * this.touchLimits.maxX)
  }

  _touchY(value) {
    return Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * this.touchLimits.maxY)
  }

  _touchPressure(value) {
    return Math.round(Math.max(0, Math.min(1, Number(value) || 0.5)) * this.touchLimits.maxPressure)
  }

  _writeTouch(command) {
    if (!this.touchSocket || this.touchSocket.destroyed || !this.touchReady) {
      return Promise.reject(this._stageError('control', 'Touch service is unavailable'))
    }
    this.touchSocket.write(command)
    return Promise.resolve(true)
  }

  _adbPoint(payload) {
    const normalizedX = Math.max(0, Math.min(1, Number(payload.x) || 0))
    const normalizedY = Math.max(0, Math.min(1, Number(payload.y) || 0))
    const naturalX = normalizedX * this.inputWidth
    const naturalY = normalizedY * this.inputHeight
    switch (this.rotation) {
      case 90:
        return {
          x: Math.round(naturalY),
          y: Math.round(this.inputWidth - naturalX),
        }
      case 180:
        return {
          x: Math.round(this.inputWidth - naturalX),
          y: Math.round(this.inputHeight - naturalY),
        }
      case 270:
        return {
          x: Math.round(this.inputHeight - naturalY),
          y: Math.round(naturalX),
        }
      case 0:
      default:
        return {
          x: Math.round(naturalX),
          y: Math.round(naturalY),
        }
    }
  }

  _adbTouchDown(payload) {
    const contact = Number(payload.contact) || 0
    const point = this._adbPoint(payload)
    this.gestures.set(contact, {
      startX: point.x,
      startY: point.y,
      x: point.x,
      y: point.y,
      startedAt: Date.now(),
    })
    return true
  }

  _writeInputBridge(action, payload) {
    const process = this.inputBridgeProcess
    if (!process || process.exitCode !== null || process.stdin.destroyed || process.stdin.writableEnded) {
      return Promise.reject(this._stageError('control', 'ADB input bridge is unavailable'))
    }
    const contact = Number(payload.contact) || 0
    if (contact !== 0) throw this._stageError('control', 'ADB input bridge supports one pointer')

    let point
    if (action === 'DOWN' || action === 'MOVE') {
      point = this._adbPoint(payload)
      const gesture = this.gestures.get(contact)
      if (action === 'DOWN') {
        this.gestures.set(contact, {
          startX: point.x,
          startY: point.y,
          x: point.x,
          y: point.y,
        })
      } else if (gesture) {
        gesture.x = point.x
        gesture.y = point.y
      }
    } else {
      const gesture = this.gestures.get(contact)
      if (!gesture) return Promise.reject(this._stageError('control', 'Touch gesture was not started'))
      point = gesture
      this.gestures.delete(contact)
    }

    try {
      process.stdin.write(`${action} ${point.x} ${point.y}\n`)
      if (action === 'DOWN' || action === 'UP') {
        log('debug', 'ADB input bridge event', {
          serial: serialForLog(this.serial),
          action,
          x: point.x,
          y: point.y,
        })
      }
      return Promise.resolve(true)
    } catch (error) {
      return Promise.reject(this._stageError('control', `ADB input bridge write failed: ${error.message}`))
    }
  }

  async _adbMotionEvent(action, payload) {
    const contact = Number(payload.contact) || 0
    if (contact !== 0) throw this._stageError('control', 'ADB motion-event fallback supports one pointer')
    let point
    if (action === 'DOWN') {
      point = this._adbPoint(payload)
      this.gestures.set(contact, {x: point.x, y: point.y})
    } else if (action === 'MOVE') {
      point = this._adbPoint(payload)
      const gesture = this.gestures.get(contact)
      if (gesture) {
        gesture.x = point.x
        gesture.y = point.y
      }
    } else {
      const gesture = this.gestures.get(contact)
      point = gesture || this._adbPoint(payload)
      this.gestures.delete(contact)
    }
    const command = `input motionevent ${action} ${point.x} ${point.y}`
    await this._shell(command)
    return true
  }

  _adbTouchMove(payload) {
    const contact = Number(payload.contact) || 0
    const gesture = this.gestures.get(contact)
    if (gesture) {
      const point = this._adbPoint(payload)
      gesture.x = point.x
      gesture.y = point.y
    }
    return true
  }

  async _adbTouchUp(payload) {
    const contact = Number(payload.contact) || 0
    const gesture = this.gestures.get(contact)
    this.gestures.delete(contact)
    if (!gesture) throw this._stageError('control', 'Touch gesture was not started')
    const distance = Math.hypot(gesture.x - gesture.startX, gesture.y - gesture.startY)
    const duration = Math.max(100, Math.min(5000, Date.now() - gesture.startedAt))
    const action = distance < 12 ? 'tap' : 'swipe'
    const command = action === 'tap'
      ? `input tap ${gesture.x} ${gesture.y}`
      : `input swipe ${gesture.startX} ${gesture.startY} ${gesture.x} ${gesture.y} ${duration}`
    log('debug', 'adb input gesture', {
      serial: serialForLog(this.serial),
      action,
      command,
      inputWidth: this.inputWidth,
      inputHeight: this.inputHeight,
    })
    await this._shell(command)
    return true
  }

  async clipboard(text) {
    if (typeof text !== 'string' || text.length === 0) throw this._stageError('clipboard', 'Clipboard text is empty')
    await this._ensureStfService()
    const port = await this._forward('localabstract:stfservice')
    this.servicePort = port
    try {
      const socket = await this._connectLocal(port)
      const response = await this._requestClipboard(socket, text)
      socket.destroy()
      return response
    } finally {
      await this._removeForward(port)
      this.servicePort = null
    }
  }

  _ensureStfService() {
    if (!this.stfServiceApk) {
      return Promise.reject(this._stageError('clipboard', 'STFService.apk resource is missing'))
    }
    if (this.stfServiceReady && this.stfServicePath) return Promise.resolve(this.stfServicePath)
    if (this.stfServiceStartPromise) return this.stfServiceStartPromise
    this.stfServiceStartPromise = (async () => {
      let installed = await this._shell('pm path jp.co.cyberagent.stf')
      if (!installed.includes('package:')) {
        try {
          await execFileAsync(this.runtime.adbPath, ['-s', this.serial, 'install', '-r', this.stfServiceApk], {timeout: 65000})
        } catch (_) {
          throw this._stageError('clipboard', 'Unable to install STFService on the device')
        }
        installed = await this._shell('pm path jp.co.cyberagent.stf')
      }
      const pathMatch = /package:(\S+)/.exec(installed)
      if (!pathMatch) throw this._stageError('clipboard', 'STFService package path is unavailable')
      const start = await execFileAsync(this.runtime.adbPath, [
        '-s', this.serial, 'shell', 'am', 'start-foreground-service',
        '--user', '0', '-a', 'jp.co.cyberagent.stf.ACTION_START',
        '-n', 'jp.co.cyberagent.stf/.Service',
      ], {timeout: 10000}).catch(() => null)
      if (!start || /^error/i.test(`${start.stdout}${start.stderr}`.trim())) {
        await execFileAsync(this.runtime.adbPath, [
          '-s', this.serial, 'shell', 'am', 'startservice',
          '--user', '0', '-a', 'jp.co.cyberagent.stf.ACTION_START',
          '-n', 'jp.co.cyberagent.stf/.Service',
        ], {timeout: 10000})
      }
      this.stfServicePath = pathMatch[1]
      this.stfServiceReady = true
      return this.stfServicePath
    })().finally(() => {
      this.stfServiceStartPromise = null
    })
    return this.stfServiceStartPromise
  }

  async _ensureStfAgent() {
    await this._ensureStfService()
    if (this.agentSocket && !this.agentSocket.destroyed) return this.agentSocket
    if (this.agentStartPromise) return this.agentStartPromise
    this.agentStartPromise = (async () => {
      const command = `export CLASSPATH='${this.stfServicePath}'; exec app_process /system/bin 'jp.co.cyberagent.stf.Agent'`
      const child = spawn(this.runtime.adbPath, ['-s', this.serial, 'shell', command], {
        stdio: ['ignore', 'pipe', 'pipe'],
      })
      this.agentProcess = child
      this.processes.add(child)
      child.stdout.on('data', data => this._logChild('stf-agent', data))
      child.stderr.on('data', data => this._logChild('stf-agent', data))
      child.once('exit', (code, signal) => {
        this.processes.delete(child)
        if (this.agentProcess === child) this.agentProcess = null
        if (this.agentSocket) this.agentSocket.destroy()
        this.agentSocket = null
        log('debug', 'device component exited', {
          serial: serialForLog(this.serial),
          component: 'stf-agent',
          code,
          signal,
        })
      })
      const port = await this._forward('localabstract:stfagent')
      this.agentPort = port
      const socket = await this._connectLocal(port)
      this.agentSocket = socket
      socket.on('data', data => this._logChild('stf-agent', data))
      socket.on('error', () => {
        if (this.agentSocket === socket) this.agentSocket = null
      })
      socket.on('close', () => {
        if (this.agentSocket === socket) this.agentSocket = null
      })
      log('debug', 'STF agent control channel ready', {
        serial: serialForLog(this.serial),
        transport: 'stfservice',
      })
      return socket
    })().finally(() => {
      this.agentStartPromise = null
    })
    return this.agentStartPromise
  }

  async _sendStfServiceKeyEvent(requestId, action, keyCode, modifiers) {
    const socket = await this._ensureStfAgent()
    const wireId = (this.serviceRequestId++ % 0xFFFFFF) + 1
    await new Promise((resolve, reject) => {
      try {
        socket.write(encodeKeyEventFrame(action, keyCode, modifiers), error => {
          if (error) reject(this._stageError('control', `STFService key event write failed: ${error.message}`))
          else resolve()
        })
      } catch (error) {
        reject(this._stageError('control', `STFService key event write failed: ${error.message}`))
      }
    })
    log('debug', 'STFService key event sent', {
      serial: serialForLog(this.serial),
      requestId,
      wireId,
      action,
      keyCode,
    })
  }

  _requestClipboard(socket, text) {
    return new Promise((resolve, reject) => {
      let buffer = Buffer.alloc(0)
      const timeout = setTimeout(() => {
        socket.destroy()
        reject(this._stageError('clipboard', 'STFService response timeout'))
      }, 5000)
      socket.on('data', chunk => {
        buffer = Buffer.concat([buffer, chunk])
        const parsed = takeLengthFrame(buffer)
        if (!parsed) return
        clearTimeout(timeout)
        resolve(decodeSuccess(parsed.frame))
      })
      socket.once('error', error => {
        clearTimeout(timeout)
        reject(this._stageError('clipboard', `STFService connection failed: ${error.message}`))
      })
      socket.write(encodeSetClipboardFrame(1, text))
    })
  }

  async _componentLost(component, message) {
    if (this.state === 'stopping' || this.state === 'disconnected' || this.state === 'error') return
    if (component === 'minitouch' && this.touchMode !== 'minitouch') return
    if (this.state === 'starting') {
      this.state = 'error'
      this.lastError = message
      log('warn', 'device component lost during startup', {
        serial: serialForLog(this.serial),
        component,
        error: message,
      })
      return
    }
    this.state = 'error'
    this.lastError = message
    log('warn', 'device component lost', {serial: serialForLog(this.serial), component, error: message})
    await this._closeDeviceChannels()
    this._scheduleRetry()
  }

  _scheduleRetry() {
    if (this.retryTimer || this.state === 'stopping' || this.state === 'disconnected' || !this.present) return
    const delay = Math.min(RETRY_MAX_MS, RETRY_BASE_MS * (2 ** this.retryCount))
    this.retryCount += 1
    this.retryTimer = setTimeout(() => {
      this.retryTimer = null
      this.start()
    }, delay)
  }

  async disconnect(reason) {
    this.present = false
    this.state = 'disconnected'
    this.lastError = reason
    if (this.retryTimer) clearTimeout(this.retryTimer)
    this.retryTimer = null
    await this._closeDeviceChannels()
  }

  async _closeDeviceChannels() {
    this._failPendingInputKeys(this._stageError('control', 'Device session closed'))
    if (this.agentSocket) this.agentSocket.destroy()
    if (this.agentProcess) this.agentProcess.kill('SIGTERM')
    if (this.screenSocket) this.screenSocket.destroy()
    if (this.touchSocket) this.touchSocket.destroy()
    this.screenSocket = null
    this.touchSocket = null
    this.touchReady = false
    this.touchProcess = null
    this.inputBridgeProcess = null
    this.agentSocket = null
    this.agentProcess = null
    this.screenBuffer = Buffer.alloc(0)
    this.screenHeaderLength = null
    this.touchBuffer = Buffer.alloc(0)
    this.inputBridgeBuffer = ''
    for (const process of this.processes) process.kill('SIGTERM')
    this.processes.clear()
    const forwards = Array.from(this.forwards)
    for (const port of forwards) await this._removeForward(port)
    this.screenPort = null
    this.touchPort = null
    this.servicePort = null
    this.agentPort = null
    this.stfServiceReady = false
    this.stfServicePath = null
    try {
      await this._shell(`rm -rf ${this.remoteRoot}`)
    } catch (_) {}
  }

  async _closeTouchChannel() {
    if (this.touchSocket) this.touchSocket.destroy()
    this.touchSocket = null
    this.touchReady = false
    if (this.touchProcess) {
      this.touchProcess.kill('SIGTERM')
      this.processes.delete(this.touchProcess)
      this.touchProcess = null
    }
    if (this.touchPort) await this._removeForward(this.touchPort)
    this.touchPort = null
  }

  async stop() {
    this.state = 'stopping'
    this.present = false
    if (this.retryTimer) clearTimeout(this.retryTimer)
    this.retryTimer = null
    for (const client of this.screenClients) client.close()
    this.screenClients.clear()
    for (const client of this.controlClients) client.close()
    this.controlClients.clear()
    await this._closeDeviceChannels()
    this.state = 'stopped'
  }
}

class Runtime {
  constructor(options) {
    this.adbPath = options.adbPath
    this.host = options.host
    this.port = options.port
    this.pollMs = options.pollMs
    this.resourceDir = options.resourceDir
    this.serialFilter = options.serial
    this.state = 'starting'
    this.lastError = null
    this.sessions = new Map()
    this.server = http.createServer((request, response) => this._handle(request, response))
    this.server.on('upgrade', (request, socket, head) => this._upgrade(request, socket, head))
    this.pollTimer = null
    this.pollPromise = null
    this.stopped = false
  }

  async start() {
    await listen(this.server, this.host, this.port)
    this.port = this.server.address().port
    await this.poll()
    // Publish readiness after the initial ADB poll so the first
    // /v1/sessions request already contains the connected device session.
    process.stdout.write(`STF_LITE_READY ${this.port}\n`)
    this.pollTimer = setInterval(() => this.poll(), this.pollMs)
  }

  async poll() {
    if (this.pollPromise || this.stopped) return
    this.pollPromise = this._poll().finally(() => {
      this.pollPromise = null
    })
    return this.pollPromise
  }

  async _poll() {
    let devices
    try {
      const result = await execFileAsync(this.adbPath, ['devices', '-l'], {timeout: 5000})
      devices = parseAdbDevices(result.stdout, this.serialFilter)
      this.lastError = null
      this.state = 'ready'
    } catch (error) {
      this.state = 'error'
      this.lastError = 'ADB device discovery failed'
      log('error', 'ADB device discovery failed', {error: error.message})
      return
    }

    for (const [serial, session] of this.sessions) {
      if (!devices.has(serial)) await session.disconnect('ADB device is disconnected')
    }
    for (const metadata of devices.values()) {
      const session = this.sessions.get(metadata.serial)
      if (session) await session.reconcile(metadata)
      else {
        const created = new DeviceSession(this, metadata)
        this.sessions.set(metadata.serial, created)
        created.start()
      }
    }
  }

  _sessionFromPath(pathname) {
    const match = /^\/v1\/sessions\/([^/]+)(?:\/([^/]+))?$/.exec(pathname)
    if (!match) return null
    const serial = decodeURIComponent(match[1])
    return {session: this.sessions.get(serial), action: match[2] || ''}
  }

  async _handle(request, response) {
    const parsed = new URL(request.url, `http://${this.host}:${this.port}`)
    if (request.method === 'GET' && parsed.pathname === '/health') {
      sendJson(response, 200, {
        status: this.state,
        version: VERSION,
        pid: process.pid,
        platform: `${process.platform}-${process.arch}`,
        error: this.lastError,
      })
      return
    }
    if (request.method === 'GET' && parsed.pathname === '/v1/sessions') {
      sendJson(response, 200, {sessions: Array.from(this.sessions.values()).map(session => session.toJSON())})
      return
    }
    if (request.method === 'POST' && parsed.pathname === '/v1/runtime/stop') {
      sendJson(response, 202, {accepted: true})
      setImmediate(() => this.stop())
      return
    }
    const route = this._sessionFromPath(parsed.pathname)
    if (!route || !route.session) {
      sendJson(response, 404, {error: 'session_not_found'})
      return
    }
    try {
      if (request.method === 'POST' && route.action === 'control') {
        const payload = await readJson(request)
        const result = await route.session.control(payload)
        sendJson(response, 200, result && typeof result === 'object'
          ? result
          : {success: result !== false})
        return
      }
      if (request.method === 'POST' && route.action === 'clipboard') {
        const payload = await readJson(request)
        const success = await route.session.clipboard(payload.text)
        sendJson(response, 200, {success: success !== false})
        return
      }
    } catch (error) {
      sendJson(response, 409, {success: false, error: route.session._publicError(error)})
      return
    }
    sendJson(response, 404, {error: 'not_found'})
  }

  _upgrade(request, socket, head) {
    const parsed = new URL(request.url, `http://${this.host}:${this.port}`)
    const route = this._sessionFromPath(parsed.pathname)
    if (
      !route ||
      !route.session ||
      !['screen', 'control-stream'].includes(route.action) ||
      request.headers.upgrade?.toLowerCase() !== 'websocket'
    ) {
      socket.destroy()
      return
    }
    const key = request.headers['sec-websocket-key']
    if (!key) {
      socket.destroy()
      return
    }
    socket.write([
      'HTTP/1.1 101 Switching Protocols',
      'Upgrade: websocket',
      'Connection: Upgrade',
      `Sec-WebSocket-Accept: ${websocketAccept(key)}`,
      '\r\n',
    ].join('\r\n'))
    if (route.action === 'screen') route.session.addScreenClient(socket, head)
    else route.session.addControlClient(socket, head)
  }

  async stop() {
    if (this.stopped) return
    this.stopped = true
    if (this.pollTimer) clearInterval(this.pollTimer)
    await Promise.all(Array.from(this.sessions.values()).map(session => session.stop()))
    await new Promise(resolve => this.server.close(() => resolve()))
    process.stdout.write('STF_LITE_STOPPED\n')
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2))
  const runtime = new Runtime(options)
  const stop = () => runtime.stop().catch(error => {
    log('error', 'runtime stop failed', {error: error.message})
    process.exitCode = 1
  })
  process.once('SIGTERM', stop)
  process.once('SIGINT', stop)
  await runtime.start()
}

if (require.main === module) {
  main().catch(error => {
    log('error', 'runtime failed to start', {error: error.message})
    process.exitCode = 1
  })
}

module.exports = {normalizeKeyName, resolveKey}
