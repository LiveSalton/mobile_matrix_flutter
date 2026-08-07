require('angular-route')
require('@material-design-icons/font/round.css')
require('./fatal-message.css')

module.exports = angular.module('stf.fatal-message', [
  require('stf/common-ui/modals/common').name,
  'ngRoute'
])
  .factory('FatalMessageService', require('./fatal-message-service'))
