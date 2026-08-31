#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Release/Mobile Matrix.app"
RELEASE_DIR="$PROJECT_ROOT/build/releases"
MACOS_ARCH="${MOBILE_MATRIX_MACOS_ARCH:-arm64}"
ZIP_PATH="$RELEASE_DIR/Mobile-Matrix-macos-${MACOS_ARCH}.zip"

cd "$PROJECT_ROOT"
if [[ "$MACOS_ARCH" == "arm64" ]]; then
  # Flutter's default Release destination is universal. Building the
  # Apple-silicon artifact explicitly avoids compiling both AOT snapshots at
  # once and makes the supported architecture of this archive unambiguous.
  flutter build macos --release --config-only
  xcodebuild \
    -quiet \
    -jobs 1 \
    -workspace macos/Runner.xcworkspace \
    -configuration Release \
    -scheme Runner \
    -derivedDataPath build/macos \
    -destination 'platform=macOS,arch=arm64' \
    OBJROOT="$PROJECT_ROOT/build/macos/Build/Intermediates.noindex" \
    SYMROOT="$PROJECT_ROOT/build/macos/Build/Products" \
    COMPILER_INDEX_STORE_ENABLE=NO \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES
else
  # Keep the universal build serial as well; Flutter's two AOT snapshots can
  # otherwise exceed the memory available on a development Mac.
  flutter build macos --release --config-only
  xcodebuild \
    -quiet \
    -jobs 1 \
    -workspace macos/Runner.xcworkspace \
    -configuration Release \
    -scheme Runner \
    -derivedDataPath build/macos \
    -destination 'generic/platform=macOS' \
    OBJROOT="$PROJECT_ROOT/build/macos/Build/Intermediates.noindex" \
    SYMROOT="$PROJECT_ROOT/build/macos/Build/Products" \
    COMPILER_INDEX_STORE_ENABLE=NO
fi
"$PROJECT_ROOT/tool/package_macos_app.sh" "$APP_PATH"

mkdir -p "$RELEASE_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Release app: $APP_PATH"
echo "Shareable archive: $ZIP_PATH"
