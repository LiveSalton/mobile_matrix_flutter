const assert = require('node:assert/strict')

const {resolveKey} = require('../src/main')

for (let digit = 0; digit <= 9; digit += 1) {
  assert.deepEqual(resolveKey(String(digit)), {
    canonicalKey: String(digit),
    keyCode: digit === 0 ? 7 : digit + 7,
  })
}

assert.deepEqual(resolveKey(9), {canonicalKey: '9', keyCode: 9})
assert.deepEqual(resolveKey(16), {canonicalKey: '16', keyCode: 16})

console.log('key mapping tests passed')
