#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP_NAME="EveryDevice"
BUNDLE_ID="com.everydevice.xxx"
APP_DIR="build/${APP_NAME}.app"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist)}"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

if [ ! -x "$BIN_PATH" ]; then
    echo "error: ${BIN_PATH} not found" >&2
    exit 1
fi

if [ ! -f Resources/AppIcon.icns ]; then
    echo "error: Resources/AppIcon.icns not found" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
cp Resources/PkgInfo "$APP_DIR/Contents/PkgInfo"

RESOURCE_BUNDLES=("$BIN_DIR"/*.bundle)
if [ ! -d "${RESOURCE_BUNDLES[0]}" ]; then
    echo "error: no SwiftPM resource bundle in ${BIN_DIR}" >&2
    exit 1
fi
cp -R "${RESOURCE_BUNDLES[@]}" "$APP_DIR/Contents/Resources/"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$APP_DIR/Contents/Info.plist"

codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR" >/dev/null
codesign --verify --verbose=2 "$APP_DIR"
plutil -lint "$APP_DIR/Contents/Info.plist"

echo "built: ${APP_DIR} (${VERSION} build ${BUILD_NUMBER})"
