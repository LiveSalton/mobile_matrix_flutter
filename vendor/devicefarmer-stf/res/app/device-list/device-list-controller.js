/**
* Copyright © 2019 contains code contributed by Orange SA, authors: Denis Barbaron - Licensed under the Apache license 2.0
**/

var QueryParser = require('./util/query-parser')

module.exports = function DeviceListCtrl(
  $scope
, DeviceService
, DeviceColumnService
, GroupService
, ControlService
, SettingsService
, $location
, MobileMatrixTheme
, DeviceBatchService
, $q
) {
  $scope.tracker = DeviceService.trackAll($scope)
  $scope.control = ControlService.create($scope.tracker.devices, '*ALL')
  $scope.mmTheme = MobileMatrixTheme.get()

  $scope.setTheme = function(theme) {
    $scope.mmTheme = MobileMatrixTheme.set(theme)
  }

  $scope.selectionMode = false
  $scope.selectedSerials = Object.create(null)
  $scope.batchState = {
    running: false
  , action: null
  , result: null
  }

  $scope.screenshots = Object.create(null)
  $scope.screenshotState = {
    running: false
  , lastUpdated: null
  , failed: 0
  }

  function screenshotHref(result) {
    var body = result && result.body ? result.body : result
    return body && body.href
  }

  $scope.hasReadyDevices = function() {
    return $scope.tracker.devices.some(function(device) {
      return device.present && device.ready
    })
  }

  $scope.refreshScreenshots = function() {
    var devices = $scope.tracker.devices.filter(function(device) {
      return device.present && device.ready
    })
    if ($scope.screenshotState.running || !devices.length) {
      return
    }

    var nextScreenshots = Object.create(null)
    var failed = 0
    $scope.screenshotState.running = true

    return $q.all(devices.map(function(device) {
      var control = ControlService.create(device, device.channel || device.serial)
      return $q.when(control.screenshot()).then(function(result) {
        var href = screenshotHref(result)
        if (href) {
          var separator = href.indexOf('?') === -1 ? '?' : '&'
          nextScreenshots[device.serial] = href + separator + 'mm-refresh=' + Date.now()
        }
      }, function() {
        failed += 1
      })
    })).then(function() {
      $scope.screenshots = nextScreenshots
      $scope.screenshotState.lastUpdated = new Date()
      $scope.screenshotState.failed = failed
    }).finally(function() {
      $scope.screenshotState.running = false
    })
  }

  var initialScreenshotRequested = false
  function requestInitialScreenshots() {
    if (!initialScreenshotRequested && $scope.tracker.devices.length) {
      initialScreenshotRequested = true
      $scope.refreshScreenshots()
    }
  }

  $scope.tracker.on('add', requestInitialScreenshots)
  requestInitialScreenshots()

  $scope.selectedCount = function() {
    return Object.keys($scope.selectedSerials).length
  }

  $scope.clearSelection = function() {
    $scope.selectedSerials = Object.create(null)
  }

  $scope.toggleSelectionMode = function() {
    $scope.selectionMode = !$scope.selectionMode
    $scope.batchState.result = null
    if (!$scope.selectionMode) {
      $scope.clearSelection()
    }
  }

  function selectedDevices() {
    return $scope.tracker.devices.filter(function(device) {
      return Boolean($scope.selectedSerials[device.serial])
    })
  }

  $scope.runBatch = function(action) {
    var devices = selectedDevices()
    if ($scope.batchState.running || !devices.length) {
      return
    }

    var operation = action === 'lease' ?
      GroupService.invite : GroupService.kick

    $scope.batchState.running = true
    $scope.batchState.action = action
    $scope.batchState.result = null

    return $q.when(DeviceBatchService.run(devices, operation, 4))
      .then(function(result) {
        $scope.batchState.result = result
        return result
      })
      .finally(function() {
        $scope.batchState.running = false
        $scope.batchState.action = null
      })
  }

  $scope.columnDefinitions = DeviceColumnService

  var defaultColumns = [
    {
      name: 'state'
    , selected: true
    }
  , {
      name: 'model'
    , selected: true
    }
  , {
      name: 'name'
    , selected: true
    }
  , {
      name: 'serial'
    , selected: false
    }
  , {
      name: 'operator'
    , selected: true
    }
  , {
      name: 'releasedAt'
    , selected: true
    }
  , {
      name: 'version'
    , selected: true
    }
  , {
      name: 'network'
    , selected: false
    }
  , {
      name: 'display'
    , selected: false
    }
  , {
      name: 'manufacturer'
    , selected: false
    }
  , {
      name: 'marketName'
    , selected: false
    }
  , {
      name: 'sdk'
    , selected: false
    }
  , {
      name: 'abi'
    , selected: false
    }
  , {
      name: 'cpuPlatform'
    , selected: false
    }
  , {
      name: 'openGLESVersion'
    , selected: false
    }
  , {
      name: 'browser'
    , selected: false
    }
  , {
      name: 'phone'
    , selected: false
    }
  , {
      name: 'imei'
    , selected: false
    }
  , {
      name: 'imsi'
    , selected: false
    }
  , {
      name: 'iccid'
    , selected: false
    }
  , {
      name: 'batteryHealth'
    , selected: false
    }
  , {
      name: 'batterySource'
    , selected: false
    }
  , {
      name: 'batteryStatus'
    , selected: false
    }
  , {
      name: 'batteryLevel'
    , selected: false
    }
  , {
      name: 'batteryTemp'
    , selected: false
    }
  , {
      name: 'provider'
    , selected: true
    }
  , {
      name: 'notes'
    , selected: true
    }
  , {
      name: 'owner'
    , selected: true
    }
  , {
      name: 'group'
    , selected: false
    }
  , {
      name: 'groupSchedule'
    , selected: false
    }
  , {
      name: 'groupStartTime'
    , selected: false
    }
  , {
      name: 'groupEndTime'
    , selected: false
    }
  , {
      name: 'groupRepetitions'
    , selected: false
    }
  , {
      name: 'groupOwner'
    , selected: false
    }
  , {
      name: 'groupOrigin'
    , selected: false
    }
  ]

  $scope.columns = defaultColumns

  SettingsService.bind($scope, {
    target: 'columns'
  , source: 'deviceListColumns'
  })

  var defaultSort = {
    fixed: [
      {
        name: 'state'
        , order: 'asc'
      }
    ]
    , user: [
      {
        name: 'name'
        , order: 'asc'
      }
    ]
  }

  $scope.sort = defaultSort

  SettingsService.bind($scope, {
    target: 'sort'
  , source: 'deviceListSort'
  })

  $scope.filter = []

  $scope.activeTabs = {
    icons: true
  , details: false
  }

  SettingsService.bind($scope, {
    target: 'activeTabs'
  , source: 'deviceListActiveTabs'
  })

  $scope.toggle = function(device) {
    if (device.using) {
      $scope.kick(device)
    } else {
      $location.path('/control/' + device.serial)
    }
  }

  $scope.invite = function(device) {
    return GroupService.invite(device).then(function() {
      $scope.$digest()
    })
  }

  $scope.applyFilter = function(query) {
    $scope.filter = QueryParser.parse(query)
  }

  $scope.search = {
    deviceFilter: '',
    focusElement: false
  }

  $scope.focusSearch = function() {
    if (!$scope.basicMode) {
      $scope.search.focusElement = true
    }
  }

  $scope.reset = function() {
    $scope.search.deviceFilter = ''
    $scope.filter = []
    $scope.sort = defaultSort
    $scope.columns = defaultColumns
  }

  $scope.$on('$destroy', function() {
    $scope.clearSelection()
    $scope.tracker.removeListener('add', requestInitialScreenshots)
  })
}
