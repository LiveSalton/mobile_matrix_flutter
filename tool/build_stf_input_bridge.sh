#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_PATH="${1:-$PROJECT_ROOT/tools/stf_lite/input_bridge/stf-input-bridge.dex.jar}"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
PLATFORM_JAR="${MOBILE_MATRIX_ANDROID_PLATFORM:-$SDK_ROOT/platforms/android-35/android.jar}"
D8_BIN="${MOBILE_MATRIX_D8:-}"

if [[ -z "$D8_BIN" ]]; then
  for candidate in "$SDK_ROOT"/build-tools/*/d8; do
    if [[ -x "$candidate" ]]; then
      D8_BIN="$candidate"
    fi
  done
fi

SOURCE_PATH="$PROJECT_ROOT/tools/stf_lite/input_bridge/src/StfInputBridge.java"
if [[ ! -f "$SOURCE_PATH" ]]; then
  echo "Missing input bridge source: $SOURCE_PATH" >&2
  exit 1
fi
if [[ ! -f "$PLATFORM_JAR" ]]; then
  echo "Missing Android platform jar: $PLATFORM_JAR" >&2
  exit 1
fi
if [[ -z "$D8_BIN" || ! -x "$D8_BIN" ]]; then
  echo "Unable to locate Android d8. Set MOBILE_MATRIX_D8 or install build-tools." >&2
  exit 1
fi

BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mobile-matrix-stf-input.XXXXXX")"
trap 'rm -rf "$BUILD_ROOT"' EXIT

mkdir -p "$BUILD_ROOT/classes" "$BUILD_ROOT/dex"
javac \
  -source 8 \
  -target 8 \
  -cp "$PLATFORM_JAR" \
  -d "$BUILD_ROOT/classes" \
  "$SOURCE_PATH"

"$D8_BIN" \
  --lib "$PLATFORM_JAR" \
  --output "$BUILD_ROOT/dex" \
  "$BUILD_ROOT/classes/StfInputBridge.class"

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"
(
  cd "$BUILD_ROOT/dex"
  zip -q -j "$OUTPUT_PATH" classes.dex
)

echo "Built $OUTPUT_PATH"
