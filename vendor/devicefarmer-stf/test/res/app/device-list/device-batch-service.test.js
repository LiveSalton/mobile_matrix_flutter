'use strict'

var assert = require('node:assert/strict')
var test = require('node:test')

var createDeviceBatchService = require('../../../../res/app/device-list/batch/device-batch-service')

test('runs device operations with bounded concurrency and one result per target', async function() {
  var service = createDeviceBatchService()
  var active = 0
  var maximumActive = 0
  var devices = [
    {serial: 'A'}
  , {serial: 'B'}
  , {serial: 'C'}
  , {serial: 'D'}
  ]

  var result = await service.run(devices, function(device) {
    active += 1
    maximumActive = Math.max(maximumActive, active)
    return new Promise(function(resolve) {
      setTimeout(function() {
        active -= 1
        resolve(device.serial)
      }, 5)
    })
  }, 2)

  assert.equal(maximumActive, 2)
  assert.equal(result.total, 4)
  assert.equal(result.succeeded, 4)
  assert.equal(result.failed, 0)
  assert.deepEqual(result.results.map(function(item) {
    return item.serial
  }), ['A', 'B', 'C', 'D'])
})

test('preserves successful siblings when one device operation fails', async function() {
  var service = createDeviceBatchService()
  var devices = [
    {serial: 'READY'}
  , {serial: 'BUSY'}
  , {serial: 'OFFLINE'}
  ]

  var result = await service.run(devices, function(device) {
    if (device.serial === 'BUSY') {
      return Promise.reject(new Error('设备忙碌'))
    }
    return Promise.resolve()
  }, 2)

  assert.equal(result.total, 3)
  assert.equal(result.succeeded, 2)
  assert.equal(result.failed, 1)
  assert.deepEqual(result.results, [
    {serial: 'READY', status: 'succeeded'}
  , {serial: 'BUSY', status: 'failed', error: '设备忙碌'}
  , {serial: 'OFFLINE', status: 'succeeded'}
  ])
})

test('returns an empty aggregate without invoking the operation', async function() {
  var service = createDeviceBatchService()
  var invoked = false

  var result = await service.run([], function() {
    invoked = true
  }, 4)

  assert.equal(invoked, false)
  assert.deepEqual(result, {
    total: 0
  , succeeded: 0
  , failed: 0
  , results: []
  })
})
