#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="${1:-$PROJECT_ROOT/build/macos/Build/Products/Release/Mobile Matrix.app}"
REFERENCE_ROOT="${MOBILE_MATRIX_STF_REFERENCE:-$PROJECT_ROOT/../mobile-matrix/vendor/devicefarmer-stf}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing macOS app: $APP_PATH" >&2
  echo "Build it first with: flutter build macos --release" >&2
  exit 1
fi

if [[ ! -d "$REFERENCE_ROOT" ]]; then
  echo "Missing STF reference checkout: $REFERENCE_ROOT" >&2
  exit 1
fi

NODE_SOURCE="${MOBILE_MATRIX_NODE_RUNTIME:-}"
if [[ -z "$NODE_SOURCE" && -x /usr/local/bin/node ]]; then
  NODE_SOURCE=/usr/local/bin/node
fi
if [[ -z "$NODE_SOURCE" ]]; then
  NODE_SOURCE="$(command -v node || true)"
fi

ADB_SOURCE="${MOBILE_MATRIX_ADB_RUNTIME:-}"
if [[ -z "$ADB_SOURCE" ]]; then
  for candidate in \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb" \
    "$HOME/Android/Sdk/platform-tools/adb"; do
    if [[ -x "$candidate" ]]; then
      ADB_SOURCE="$candidate"
      break
    fi
  done
fi
if [[ -z "$ADB_SOURCE" ]]; then
  ADB_SOURCE="$(command -v adb || true)"
fi

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [[ ! -d "$1" ]]; then
    echo "Missing required directory: $1" >&2
    exit 1
  fi
}

require_file "$NODE_SOURCE"
require_file "$ADB_SOURCE"
require_file "$PROJECT_ROOT/tools/stf_lite/src/main.js"
require_dir "$REFERENCE_ROOT/node_modules/@devicefarmer/minicap-prebuilt"
require_dir "$REFERENCE_ROOT/node_modules/@devicefarmer/minitouch-prebuilt"
require_file "$REFERENCE_ROOT/vendor/STFService/STFService.apk"

INPUT_BRIDGE_JAR="$PROJECT_ROOT/tools/stf_lite/input_bridge/stf-input-bridge.dex.jar"
if [[ ! -f "$INPUT_BRIDGE_JAR" ]]; then
  "$PROJECT_ROOT/tool/build_stf_input_bridge.sh" "$INPUT_BRIDGE_JAR"
fi
require_file "$INPUT_BRIDGE_JAR"

if ! lipo -archs "$NODE_SOURCE" | grep -q 'arm64'; then
  echo "The bundled Node runtime must contain arm64: $NODE_SOURCE" >&2
  exit 1
fi
if ! lipo -archs "$ADB_SOURCE" | grep -q 'arm64'; then
  echo "The bundled ADB must contain arm64: $ADB_SOURCE" >&2
  exit 1
fi

STF_ROOT="$APP_PATH/Contents/Resources/stf-lite"
rm -rf "$STF_ROOT"
mkdir -p "$STF_ROOT/bin" "$STF_ROOT/input_bridge" "$STF_ROOT/resources"

mkdir -p "$STF_ROOT/src"
cp "$PROJECT_ROOT/tools/stf_lite/src/main.js" "$STF_ROOT/src/main.js"
cp "$PROJECT_ROOT/tools/stf_lite/package.json" "$STF_ROOT/package.json"
cp "$PROJECT_ROOT/tools/stf_lite/resource-manifest.json" "$STF_ROOT/resource-manifest.json"
cp "$PROJECT_ROOT/tools/stf_lite/README.md" "$STF_ROOT/README.md"
cp "$PROJECT_ROOT/tools/stf_lite/THIRD_PARTY_NOTICES.md" "$STF_ROOT/THIRD_PARTY_NOTICES.md"

cp "$NODE_SOURCE" "$STF_ROOT/bin/node"
cp "$ADB_SOURCE" "$STF_ROOT/bin/adb"
chmod 755 "$STF_ROOT/bin/node" "$STF_ROOT/bin/adb"
cp "$INPUT_BRIDGE_JAR" "$STF_ROOT/input_bridge/stf-input-bridge.dex.jar"

cp -R "$REFERENCE_ROOT/node_modules/@devicefarmer/minicap-prebuilt" \
  "$STF_ROOT/resources/minicap-prebuilt"
cp -R "$REFERENCE_ROOT/node_modules/@devicefarmer/minitouch-prebuilt" \
  "$STF_ROOT/resources/minitouch-prebuilt"
mkdir -p "$STF_ROOT/resources/STFService"
cp "$REFERENCE_ROOT/vendor/STFService/STFService.apk" \
  "$STF_ROOT/resources/STFService/STFService.apk"

SIGNING_IDENTITY="${MOBILE_MATRIX_CODESIGN_IDENTITY:-}"
if [[ -n "$SIGNING_IDENTITY" ]]; then
  SIGN_OPTIONS=(--options runtime --timestamp --sign "$SIGNING_IDENTITY")
  echo "Signing embedded executables with $SIGNING_IDENTITY"
else
  SIGN_OPTIONS=(--sign -)
  echo "No Developer ID identity configured; using ad hoc signing"
fi

codesign --force "${SIGN_OPTIONS[@]}" "$STF_ROOT/bin/node"
codesign --force "${SIGN_OPTIONS[@]}" "$STF_ROOT/bin/adb"
codesign --force --deep "${SIGN_OPTIONS[@]}" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

echo "Packaged STF Lite runtime into: $STF_ROOT"
echo "Packaged app: $APP_PATH"
