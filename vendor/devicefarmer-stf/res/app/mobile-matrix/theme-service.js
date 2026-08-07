'use strict'

var STORAGE_KEY = 'mobile-matrix-theme'
var DEFAULT_THEME = 'default'
var THEMES = {
  default: true
, roseGlow: true
}

module.exports = function MobileMatrixThemeFactory($window) {
  var currentTheme = DEFAULT_THEME

  function normalize(theme) {
    return THEMES[theme] ? theme : DEFAULT_THEME
  }

  function apply(theme) {
    currentTheme = normalize(theme)
    $window.document.documentElement.setAttribute(
      'data-mm-theme', currentTheme)
    updateBrandIcons(currentTheme)
    $window.localStorage.setItem(STORAGE_KEY, currentTheme)
    return currentTheme
  }

  function updateBrandIcons(theme) {
    var suffix = theme === 'roseGlow' ? '-rose' : ''
    var version = theme === 'roseGlow' ? 'rose-r2' : 'blue-r2'
    var iconUrl = '/static/logo/exports/mobile-matrix-128' + suffix +
      '.png?v=mm-theme-' + version
    var links = $window.document.querySelectorAll(
      'link[rel~="icon"], link[rel="apple-touch-icon"]')

    Array.prototype.forEach.call(links, function(link) {
      link.setAttribute('href', iconUrl)
    })
  }

  return {
    initialize: function() {
      return apply($window.localStorage.getItem(STORAGE_KEY))
    }
  , get: function() {
      return currentTheme
    }
  , set: function(theme) {
      return apply(theme)
    }
  , toggle: function() {
      return apply(currentTheme === DEFAULT_THEME ? 'roseGlow' : DEFAULT_THEME)
    }
  , normalize: normalize
  }
}
