/**
* Copyright © 2019 contains code contributed by Orange SA, authors: Denis Barbaron - Licensed under the Apache license 2.0
**/

module.exports =
  function ControlPanesController($scope, $http, gettext, $routeParams,
    $timeout, $location, DeviceService, GroupService, ControlService,
    StorageService, FatalMessageService, SettingsService) {

    $scope.workspaceMode = 'execution'
    $scope.deviceToolGroups = [
      {
        title: gettext('Quick Actions'),
        tools: [
          {
            title: gettext('Dashboard'),
            materialIcon: 'dashboard',
            templateUrl: 'control-panes/dashboard/dashboard.pug',
            filters: ['native', 'web']
          }
        ]
      },
      {
        title: gettext('Records & Diagnostics'),
        tools: [
          {
            title: gettext('Logs'),
            materialIcon: 'receipt_long',
            templateUrl: 'control-panes/logs/logs.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('Screenshots'),
            materialIcon: 'photo_camera',
            templateUrl: 'control-panes/screenshots/screenshots.pug',
            filters: ['native', 'web']
          }
        ]
      },
      {
        title: gettext('Device Management'),
        tools: [
          {
            title: gettext('Automation'),
            materialIcon: 'route',
            templateUrl: 'control-panes/automation/automation.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('File Explorer'),
            materialIcon: 'folder_open',
            templateUrl: 'control-panes/explorer/explorer.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('Advanced'),
            materialIcon: 'tune',
            templateUrl: 'control-panes/advanced/advanced.pug',
            filters: ['native', 'web']
          },
          {
            title: gettext('Info'),
            materialIcon: 'info',
            templateUrl: 'control-panes/info/info.pug',
            filters: ['native', 'web']
          }
        ]
      }
    ]

    $scope.activeDeviceTool = $scope.deviceToolGroups[0].tools[0]

    $scope.selectWorkspaceMode = function(mode) {
      if (mode === 'execution' || mode === 'tools') {
        $scope.workspaceMode = mode
      }
    }

    $scope.selectDeviceTool = function(tool) {
      if (tool && $scope.deviceToolVisible(tool)) {
        $scope.activeDeviceTool = tool
      }
    }

    $scope.deviceToolVisible = function(tool) {
      return !tool.filters || tool.filters.indexOf($scope.$root.platform) !== -1
    }

    $scope.device = null
    $scope.control = null
    $scope.airtest = {
      state: 'checking',
      task: 'capture',
      tasks: [],
      result: null,
      selectedSerials: Object.create(null),
      message: gettext('Checking Airtest execution engine')
    }
    $scope.airtestTracker = DeviceService.trackAll($scope)

    $scope.airtestDeviceReady = function() {
      return $scope.device && (
        $scope.device.state === 'available' || $scope.device.state === 'using'
      )
    }

    $scope.airtestReady = function() {
      return $scope.airtest.state === 'ready' &&
        $scope.airtestTargetCount() > 0
    }

    $scope.refreshAirtestTasks = function() {
      return $http.get('/app/api/v1/airtest/tasks')
        .then(function(response) {
          $scope.airtest.tasks = response.data.tasks || []
          if (!$scope.airtest.tasks.some(function(task) {
            return task.id === $scope.airtest.task
          })) {
            $scope.airtest.task = $scope.airtest.tasks.length ?
              $scope.airtest.tasks[0].id : null
          }
        })
    }

    $scope.airtestDeviceSelectable = function(device) {
      return device && (device.state === 'available' || device.state === 'using')
    }

    $scope.airtestTargetDevices = function() {
      var devices = $scope.airtestTracker.devices.filter(function(device) {
        return $scope.airtestDeviceSelectable(device)
      })
      if ($scope.device && !devices.some(function(device) {
        return device.serial === $scope.device.serial
      }) && $scope.airtestDeviceSelectable($scope.device)) {
        devices.unshift($scope.device)
      }
      return devices
    }

    $scope.airtestTargetCount = function() {
      return $scope.airtestTargetDevices().filter(function(device) {
        return Boolean($scope.airtest.selectedSerials[device.serial])
      }).length
    }

    $scope.toggleAirtestTarget = function(device) {
      if (!$scope.airtestDeviceSelectable(device) ||
          $scope.airtest.state === 'running') {
        return
      }
      if ($scope.airtest.selectedSerials[device.serial]) {
        delete $scope.airtest.selectedSerials[device.serial]
      }
      else {
        $scope.airtest.selectedSerials[device.serial] = true
      }
      $scope.airtest.result = null
    }

    $scope.selectAllAirtestTargets = function() {
      if ($scope.airtest.state === 'running') {
        return
      }
      $scope.airtestTargetDevices().forEach(function(device) {
        $scope.airtest.selectedSerials[device.serial] = true
      })
      $scope.airtest.result = null
    }

    $scope.refreshAirtestStatus = function() {
      $scope.airtest.state = 'checking'
      $scope.airtest.result = null
      $scope.airtest.message = gettext('Checking Airtest execution engine')

      return $http.get('/app/api/v1/airtest/status')
        .then(function(response) {
          if (response.data && response.data.available) {
            $scope.airtest.state = 'ready'
            $scope.airtest.version = response.data.version
            $scope.airtest.message = gettext('Airtest execution engine is ready')
          }
          else {
            $scope.airtest.state = 'unavailable'
            $scope.airtest.message = response.data.message ||
              gettext('Airtest execution engine is unavailable')
          }
        })
        .catch(function(response) {
          $scope.airtest.state = 'unavailable'
          $scope.airtest.message = response.data && response.data.message ||
            gettext('Airtest execution engine is unavailable')
        })
    }

    $scope.runAirtestAction = function() {
      if (!$scope.airtestReady() || $scope.airtest.state === 'running') {
        return
      }

      $scope.airtest.state = 'running'
      $scope.airtest.result = null
      $scope.airtest.message = gettext('Running on selected devices')

      var serials = $scope.airtestTargetDevices().filter(function(device) {
        return Boolean($scope.airtest.selectedSerials[device.serial])
      }).map(function(device) {
        return device.serial
      })

      return $http.post('/app/api/v1/airtest/execute-batch', {
        serials: serials,
        task: $scope.airtest.task
      })
        .then(function(response) {
          $scope.airtest.state = 'ready'
          $scope.airtest.result = response.data
          $scope.airtest.message = response.data.status === 'partial' ?
            gettext('Action completed with device failures') :
            gettext('Action completed on selected devices')
        })
        .catch(function(response) {
          $scope.airtest.state = 'ready'
          $scope.airtest.result = response.data || {}
          $scope.airtest.message = $scope.airtest.result.message ||
            gettext('Airtest execution failed')
        })
    }

    // TODO: Move this out to Ctrl.resolve
    function getDevice(serial) {
      DeviceService.get(serial, $scope)
        .then(function(device) {
          return GroupService.invite(device)
        })
        .then(function(device) {
          $scope.device = device
          $scope.control = ControlService.create(device, device.channel)
          if ($scope.$root.platform !== 'native' &&
              $scope.$root.platform !== 'web') {
            $scope.$root.platform = 'native'
          }

          // TODO: Change title, flickers too much on Chrome
          // $rootScope.pageTitle = device.name

          SettingsService.set('lastUsedDevice', serial)
          $scope.airtest.selectedSerials[serial] = true

          $scope.refreshAirtestStatus()
          $scope.refreshAirtestTasks()

          return device
        })
        .catch(function() {
          $timeout(function() {
            $location.path('/')
          })
        })
    }

    getDevice($routeParams.serial)

    $scope.$watch('device.state', function(newValue, oldValue) {
      if (newValue !== oldValue) {
/*************** fix bug: it seems automation state was forgotten ? *************/
        if (oldValue === 'using' || oldValue === 'automation') {
/******************************************************************************/
          FatalMessageService.open($scope.device, false)
        }
      }
    }, true)

  }
