/**
* Copyright © 2024 contains code contributed by Orange SA, authors: Denis Barbaron - Licensed under the Apache license 2.0
**/

var http = require('http')
var url = require('url')
var fs = require('fs')
var path = require('path')
var childProcess = require('child_process')
var crypto = require('crypto')

var express = require('express')
var cookieSession = require('cookie-session')
var bodyParser = require('body-parser')
var serveFavicon = require('serve-favicon')
var serveStatic = require('serve-static')
var csrf = require('@dr.pogodin/csurf')
var compression = require('compression')

var logger = require('../../util/logger')
var pathutil = require('../../util/pathutil')
var packageJson = require('../../../package.json')

var auth = require('./middleware/auth')
var deviceIconMiddleware = require('./middleware/device-icons')
var browserIconMiddleware = require('./middleware/browser-icons')
var appstoreIconMiddleware = require('./middleware/appstore-icons')

var markdownServe = require('markdown-serve')

var airtestRunner = path.resolve(__dirname, 'airtest-runner.py')
var allowedAirtestTasks = ['capture', 'douyin_follow_message']
var airtestEvidenceRoot = process.env.AIRTEST_EVIDENCE_DIR ||
  path.resolve(process.cwd(), '.runtime', 'airtest-evidence')

function runProcess(command, args) {
  return new Promise(function(resolve, reject) {
    var child = childProcess.spawn(command, args, {
      stdio: ['ignore', 'pipe', 'pipe']
    })
    var stdout = ''
    var stderr = ''

    child.stdout.on('data', function(data) {
      stdout += data.toString()
    })
    child.stderr.on('data', function(data) {
      stderr += data.toString()
    })
    child.on('error', reject)
    child.on('close', function(code) {
      if (code === 0) {
        resolve(stdout)
      }
      else {
        var error = new Error(stderr || stdout || 'Process exited with code ' + code)
        error.code = code
        reject(error)
      }
    })
  })
}

function parseRunnerResult(output) {
  var lines = output.trim().split(/\r?\n/)
  return JSON.parse(lines[lines.length - 1])
}

function isSafeSerial(serial) {
  return typeof serial === 'string' && /^[A-Za-z0-9._:-]+$/.test(serial)
}

function airtestUnavailable(err) {
  return {
    available: false,
    message: err && err.message ? err.message : 'Airtest runtime is unavailable'
  }
}

function isSafeEvidencePart(value) {
  return typeof value === 'string' && /^[A-Za-z0-9._-]+$/.test(value)
}

function createRunId() {
  return Date.now().toString(36) + '-' + crypto.randomBytes(6).toString('hex')
}

function evidenceUrls(runId, serial, result) {
  var files = Array.isArray(result.screenshots) ? result.screenshots : []
  result.screenshots = files.filter(isSafeEvidencePart).map(function(filename) {
    return {
      name: filename,
      url: '/app/api/v1/airtest/evidence/' + runId + '/' + serial + '/' + filename
    }
  })
  return result
}

function executeAirtestAction(python, serial, task, runId) {
  var evidenceDir = path.join(airtestEvidenceRoot, runId, serial)
  fs.mkdirSync(evidenceDir, { recursive: true })
  return runProcess('adb', ['-s', serial, 'get-state'])
    .then(function(output) {
      if (output.trim() !== 'device') {
        throw new Error('Target device is not available')
      }
      return runProcess(python, [
        airtestRunner,
        '--serial', serial,
        '--task', task,
        '--evidence-dir', evidenceDir
      ])
    })
    .then(function(output) {
      return parseRunnerResult(output)
    })
    .catch(function(err) {
      return {
        status: 'failed',
        serial: serial,
        task: task,
        message: err.message || 'Airtest execution failed'
      }
    })
    .then(function(result) {
      result.task = result.task || task
      result.serial = result.serial || serial
      return evidenceUrls(runId, serial, result)
    })
}

module.exports = function(options) {
  var log = logger.createLogger('app')
  var app = express()
  var server = http.createServer(app)

  app.use('/static/wiki', markdownServe.middleware({
    rootDirectory: pathutil.root('node_modules/@devicefarmer/stf-wiki')
  , view: 'docs'
  }))

  app.set('view engine', 'pug')
  app.set('views', pathutil.resource('app/views'))
  app.set('strict routing', true)
  app.set('case sensitive routing', true)
  app.set('trust proxy', true)

  if (fs.existsSync(pathutil.resource('build'))) {
    log.info('Using pre-built resources')
    app.use(compression())
    app.use('/static/app/build/entry',
      serveStatic(pathutil.resource('build/entry')))
    app.use('/static/app/build', serveStatic(pathutil.resource('build'), {
      maxAge: '10d'
    }))
  }
  else {
    log.info('Using webpack')
    // Keep webpack-related requires here, as our prebuilt package won't
    // have them at all.
    var webpackServerConfig = require('./../../../webpack.config').webpackServer
    app.use('/static/app/build',
      require('./middleware/webpack')(webpackServerConfig))
  }

  app.use('/static/bower_components',
    serveStatic(pathutil.resource('bower_components')))
  app.use('/static/app/data', serveStatic(pathutil.resource('data')))
  app.use('/static/app/status', serveStatic(pathutil.resource('common/status')))
  app.use('/static/app/browsers', browserIconMiddleware())
  app.use('/static/app/appstores', appstoreIconMiddleware())
  app.use('/static/app/devices', deviceIconMiddleware())
  app.use('/static/app', serveStatic(pathutil.resource('app')))

  app.use('/static/logo',
    serveStatic(pathutil.resource('common/logo')))
  app.use(serveFavicon(pathutil.resource(
    'common/logo/exports/mobile-matrix-128.png')))

  app.use(cookieSession({
    name: options.ssid
  , keys: [options.secret]
  , httpOnly: false
  }))

  app.use(auth({
    secret: options.secret
  , authUrl: options.authUrl
  , trustedLocal: options.trustedLocal
  , localUser: options.localUser
  }))

  // This needs to be before the csrf() middleware or we'll get nasty
  // errors in the logs. The dummy endpoint is a hack used to enable
  // autocomplete on some text fields.
  app.all('/app/api/v1/dummy', function(req, res) {
    res.send('OK')
  })

  app.use(bodyParser.json())
  app.use(csrf())

  app.use(function(req, res, next) {
    res.cookie('XSRF-TOKEN', req.csrfToken())
    next()
  })

  app.disable('x-powered-by')

  app.get('/', function(req, res) {
    res.render('index')
  })

  app.get('/app/api/v1/state.js', function(req, res) {
    var state = {
      config: {
        websocketUrl: (function() {
          var wsUrl = url.parse(options.websocketUrl, true)
          wsUrl.query.uip = req.ip
          return url.format(wsUrl)
        })()
      , stfVersion: packageJson.version
      }
    , user: req.user
    }

    if (options.userProfileUrl) {
      state.config.userProfileUrl = (function() {
        return options.userProfileUrl
      })()
    }

    res.type('application/javascript')
    res.send('var GLOBAL_APPSTATE = ' + JSON.stringify(state))
  })

  function getAirtestPython() {
    return process.env.AIRTEST_PYTHON || ''
  }

  app.get('/app/api/v1/airtest/status', function(req, res) {
    var python = getAirtestPython()
    if (!python || !fs.existsSync(python)) {
      return res.status(503).json(airtestUnavailable(new Error(
        'Airtest Python runtime is not configured'
      )))
    }

    return runProcess(python, [airtestRunner, '--status'])
      .then(function(output) {
        res.json(parseRunnerResult(output))
      })
      .catch(function(err) {
        res.status(503).json(airtestUnavailable(err))
      })
  })

  app.get('/app/api/v1/airtest/tasks', function(req, res) {
    res.json({
      tasks: [
        {
          id: 'capture',
          title: 'Capture current screen',
          description: 'Capture a fresh screen without changing device content.'
        },
        {
          id: 'douyin_follow_message',
          title: 'Douyin follow + greeting',
          description: 'Run the existing Douyin profile verification and greeting task.'
        }
      ]
    })
  })

  app.get('/app/api/v1/airtest/evidence/:runId/:serial/:filename', function(req, res) {
    var runId = req.params.runId
    var serial = req.params.serial
    var filename = req.params.filename
    if (!isSafeEvidencePart(runId) || !isSafeSerial(serial) ||
        !/^[A-Za-z0-9._-]+\.png$/.test(filename)) {
      return res.status(404).end()
    }

    var root = path.resolve(airtestEvidenceRoot)
    var target = path.resolve(root, runId, serial, filename)
    if (target.indexOf(root + path.sep) !== 0) {
      return res.status(404).end()
    }
    // Stream the already-validated evidence file explicitly.  `sendFile` is
    // subject to the app's static/auth middleware and can return 403 for a
    // valid runtime artifact outside the public asset root.
    return fs.stat(target, function(err, stats) {
      if (err || !stats.isFile()) {
        return res.status(404).end()
      }

      res.type('png')
      var stream = fs.createReadStream(target)
      stream.on('error', function() {
        if (!res.headersSent) {
          res.status(404).end()
        }
      })
      stream.pipe(res)
    })
  })

  app.post('/app/api/v1/airtest/execute', function(req, res) {
    var serial = req.body && req.body.serial
    var task = req.body && (req.body.task || req.body.action)
    var python = getAirtestPython()

    if (!isSafeSerial(serial) || allowedAirtestTasks.indexOf(task) === -1) {
      return res.status(400).json({
        status: 'failed',
        message: 'Unsupported execution request'
      })
    }
    if (!python || !fs.existsSync(python)) {
      return res.status(503).json(airtestUnavailable(new Error(
        'Airtest Python runtime is not configured'
      )))
    }

    return executeAirtestAction(python, serial, task, createRunId())
      .then(function(result) {
        res.status(result.status === 'succeeded' ? 200 : 422).json(result)
      })
  })

  app.post('/app/api/v1/airtest/execute-batch', function(req, res) {
    var serials = req.body && req.body.serials
    var task = req.body && (req.body.task || req.body.action)
    var python = getAirtestPython()

    if (!Array.isArray(serials) || !serials.length || serials.length > 20 ||
        serials.some(function(serial) { return !isSafeSerial(serial) }) ||
        new Set(serials).size !== serials.length ||
        allowedAirtestTasks.indexOf(task) === -1) {
      return res.status(400).json({
        status: 'failed',
        message: 'Unsupported batch execution request'
      })
    }
    if (!python || !fs.existsSync(python)) {
      return res.status(503).json(airtestUnavailable(new Error(
        'Airtest Python runtime is not configured'
      )))
    }

    var runId = createRunId()
    return serials.reduce(function(results, serial) {
      return results.then(function(items) {
        return executeAirtestAction(python, serial, task, runId)
          .then(function(result) {
            items.push(result)
            return items
          })
      })
    }, Promise.resolve([]))
      .then(function(results) {
        var succeeded = results.filter(function(result) {
          return result.status === 'succeeded'
        }).length
        res.json({
          status: succeeded === results.length ? 'succeeded' :
            (succeeded ? 'partial' : 'failed'),
          task: task,
          results: results
        })
      })
  })

  server.listen(options.port)
  log.info('Listening on port %d', options.port)
}
