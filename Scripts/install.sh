#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="build/EveryDevice.app"
BUNDLE_ID="com.everydevice.xxx"

if [ ! -d "$APP" ]; then
    echo "error: ${APP} not found; run ./Scripts/build-app.sh first" >&2
    exit 1
fi

DEST="/Applications/EveryDevice.app"
if [ ! -w "/Applications" ]; then
    mkdir -p "$HOME/Applications"
    DEST="$HOME/Applications/EveryDevice.app"
fi

if [ -d "$DEST" ]; then
    EXISTING_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$DEST/Contents/Info.plist" 2>/dev/null || true)"
    if [ "$EXISTING_ID" != "$BUNDLE_ID" ]; then
        echo "error: ${DEST} exists and is not EveryDevice (id: ${EXISTING_ID:-unknown})" >&2
        exit 1
    fi
fi

PIDS="$(pgrep -f "EveryDevice.app/Contents/MacOS/EveryDevice" || true)"
if [ -n "$PIDS" ]; then
    # shellcheck disable=SC2086
    kill $PIDS 2>/dev/null || true
    for _ in $(seq 1 20); do
        pgrep -f "EveryDevice.app/Contents/MacOS/EveryDevice" >/dev/null || break
        sleep 0.1
    done
fi

rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
codesign --verify --deep --strict "$DEST"

open "$DEST"

echo "installed: ${DEST}"
