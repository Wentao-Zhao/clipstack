#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ClipStack.app"
DMG_DIR="$ROOT_DIR/dist/dmg"
DMG_PATH="$ROOT_DIR/dist/ClipStack.dmg"
VOLUME_NAME="ClipStack"

if [[ ! -d "$APP_DIR" ]]; then
    echo "Missing app bundle: $APP_DIR" >&2
    echo "Run scripts/package-app.sh first." >&2
    exit 1
fi

rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"

ditto "$APP_DIR" "$DMG_DIR/ClipStack.app"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_DIR"

echo "Created: $DMG_PATH"
