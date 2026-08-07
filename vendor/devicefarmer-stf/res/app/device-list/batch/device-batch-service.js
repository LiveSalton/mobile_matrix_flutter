'use strict'

module.exports = function DeviceBatchServiceFactory() {
  return {
    run: function(devices, operation, concurrency) {
      var limit = Math.max(1, Math.floor(Number(concurrency) || 1))
      var results = new Array(devices.length)
      var active = 0
      var nextIndex = 0
      var completed = 0

      return new Promise(function(resolve) {
        function finish() {
          var failed = results.filter(function(result) {
            return result.status === 'failed'
          }).length

          resolve({
            total: results.length
          , succeeded: results.length - failed
          , failed: failed
          , results: results
          })
        }

        function launch() {
          if (!devices.length) {
            finish()
            return
          }

          while (active < limit && nextIndex < devices.length) {
            (function(index) {
              var device = devices[index]
              active += 1
              nextIndex += 1

              Promise.resolve()
                .then(function() {
                  return operation(device)
                })
                .then(function() {
                  results[index] = {
                    serial: device.serial
                  , status: 'succeeded'
                  }
                })
                .catch(function(error) {
                  results[index] = {
                    serial: device.serial
                  , status: 'failed'
                  , error: error && error.message ? error.message : '设备操作失败'
                  }
                })
                .then(function() {
                  active -= 1
                  completed += 1
                  if (completed === devices.length) {
                    finish()
                  }
                  else {
                    launch()
                  }
                })
            })(nextIndex)
          }
        }

        launch()
      })
    }
  }
}
