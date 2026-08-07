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
