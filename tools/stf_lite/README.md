# Mobile Matrix STF Lite

This directory contains the first development sidecar for the Mobile Matrix
single-machine Android runtime. It intentionally does not start `stf local`
and does not require Docker, Colima, RethinkDB, STF Web, authentication, or
the multi-user provider stack.

## Development resources

The sidecar does not copy the full reference STF checkout into the Flutter
application. Supply a resource directory that contains this layout:

```text
<resource-dir>/
  minicap-prebuilt/prebuilt/<abi>/bin/minicap
  minicap-prebuilt/prebuilt/<abi>/lib/android-<sdk>/minicap.so
  minicap-prebuilt/prebuilt/noarch/minicap.apk
  minitouch-prebuilt/prebuilt/<abi>/bin/minitouch
  STFService/STFService.apk
  input_bridge/stf-input-bridge.dex.jar
  bin/node
  bin/adb
```

For the current development checkout, the directories can be assembled from
the reference project without copying its `node_modules`:

```text
../mobile-matrix/vendor/devicefarmer-stf/node_modules/@devicefarmer/minicap-prebuilt
../mobile-matrix/vendor/devicefarmer-stf/node_modules/@devicefarmer/minitouch-prebuilt
../mobile-matrix/vendor/devicefarmer-stf/vendor/STFService
```

The release packaging script copies this layout into
`mobile_matrix.app/Contents/Resources/stf-lite`. The Flutter runtime starts
the bundled Node and passes the bundled ADB path to the sidecar. Development
builds may still use the documented sibling reference checkout as a fallback.

## Local protocol

The sidecar prints `STF_LITE_READY <port>` after binding its loopback HTTP
server. It exposes:

- `GET /health`
- `GET /v1/sessions`
- `POST /v1/sessions/:serial/control`
- `GET /v1/sessions/:serial/control-stream` as a persistent WebSocket endpoint
- `POST /v1/sessions/:serial/clipboard`
- `POST /v1/runtime/stop`
- `GET /v1/sessions/:serial/screen` as a WebSocket endpoint

The HTTP and WebSocket endpoints are loopback-only and carry no user or auth
state. Session state is held in memory and recreated after restart.

The control endpoint keeps the original STF coordinate contract. Touch
payloads use normalized `x` and `y` values in the `0..1` range, with
`gestureStart`, `touchDown`, `touchMove`, `touchUp`, `touchCommit`, and
`gestureStop` preserving the gesture lifecycle. High-frequency touch payloads
use the persistent control WebSocket; the HTTP endpoint remains as a fallback
for startup races and older clients. When minitouch is blocked on a modern
Android release, the sidecar starts the persistent `StfInputBridge` process
from `input_bridge/stf-input-bridge.dex.jar`; it keeps one Android gesture
session alive so single-pointer drags remain live. Devices without that
bridge fall back to a completed `input tap`/`input swipe` gesture. The screen
projection uses
the physical display size, while the fallback `adb input` driver converts the
same normalized coordinates to the device's logical input frame. It never
uses the rendered Flutter widget size as a device input size.
