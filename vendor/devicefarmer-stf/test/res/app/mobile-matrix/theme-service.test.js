'use strict'

var assert = require('node:assert/strict')
var test = require('node:test')

var createThemeService = require('../../../../res/app/mobile-matrix/theme-service')

function createWindow(initialTheme) {
  var values = Object.create(null)
  if (initialTheme !== undefined) {
    values['mobile-matrix-theme'] = initialTheme
  }
  var appliedTheme

  return {
    localStorage: {
      getItem: function(key) {
        return values[key] || null
      }
    , setItem: function(key, value) {
        values[key] = value
      }
    }
  , document: {
      documentElement: {
        setAttribute: function(name, value) {
          assert.equal(name, 'data-mm-theme')
          appliedTheme = value
        }
      }
    }
  , appliedTheme: function() {
      return appliedTheme
    }
  , storedTheme: function() {
      return values['mobile-matrix-theme']
    }
  }
}

test('uses the persisted roseGlow theme', function() {
  var window = createWindow('roseGlow')
  var theme = createThemeService(window)

  assert.equal(theme.initialize(), 'roseGlow')
  assert.equal(window.appliedTheme(), 'roseGlow')
})

test('falls back to default for an unknown persisted theme', function() {
  var window = createWindow('untrusted-theme')
  var theme = createThemeService(window)

  assert.equal(theme.initialize(), 'default')
  assert.equal(window.appliedTheme(), 'default')
  assert.equal(window.storedTheme(), 'default')
})

test('toggles between the only two supported themes', function() {
  var window = createWindow('default')
  var theme = createThemeService(window)

  theme.initialize()
  assert.equal(theme.toggle(), 'roseGlow')
  assert.equal(theme.toggle(), 'default')
})
