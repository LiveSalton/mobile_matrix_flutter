'use strict'

var assert = require('node:assert/strict')
var test = require('node:test')

var createTrustedLocalAuth = require('../../../lib/units/app/middleware/trusted-local-auth')

function invoke(middleware, request) {
  return new Promise(function(resolve, reject) {
    middleware(request, {}, function(error) {
      if (error) {
        reject(error)
      }
      else {
        resolve()
      }
    })
  })
}

test('creates a trusted local session and exposes the persisted STF user', async function() {
  var savedUser
  var persistedUser = {
    name: 'administrator'
  , email: 'administrator@fakedomain.com'
  , privilege: 'admin'
  }
  var dbapi = {
    saveUserAfterLogin: function(user) {
      savedUser = user
      return Promise.resolve()
    }
  , loadUser: function(email) {
      assert.equal(email, persistedUser.email)
      return Promise.resolve(persistedUser)
    }
  }
  var middleware = createTrustedLocalAuth({
    localUser: {
      name: persistedUser.name
    , email: persistedUser.email
    }
  }, dbapi)
  var request = {
    ip: '127.0.0.1'
  , session: {}
  , sessionOptions: {}
  }

  await invoke(middleware, request)

  assert.deepEqual(savedUser, {
    name: persistedUser.name
  , email: persistedUser.email
  , ip: '127.0.0.1'
  })
  assert.deepEqual(request.session.jwt, {
    name: persistedUser.name
  , email: persistedUser.email
  })
  assert.equal(request.sessionOptions.httpOnly, false)
  assert.equal(request.user, persistedUser)
})

test('fails the request when the trusted local STF user cannot be loaded', async function() {
  var expected = new Error('Trusted local STF user could not be loaded')
  var dbapi = {
    saveUserAfterLogin: function() {
      return Promise.resolve()
    }
  , loadUser: function() {
      return Promise.resolve(null)
    }
  }
  var middleware = createTrustedLocalAuth({
    localUser: {
      name: 'administrator'
    , email: 'administrator@fakedomain.com'
    }
  }, dbapi)

  await assert.rejects(invoke(middleware, {
    ip: '127.0.0.1'
  , session: {}
  , sessionOptions: {}
  }), function(error) {
    assert.equal(error.message, expected.message)
    return true
  })
})
