require('./theme.css')

module.exports = angular.module('mobile-matrix', [])
  .factory('MobileMatrixTheme', require('./theme-service'))
  .run(function(MobileMatrixTheme) {
    MobileMatrixTheme.initialize()
  })
