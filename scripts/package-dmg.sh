#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ClipStack.app"
DMG_DIR="$ROOT_DIR/dist/dmg"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DMG_PATH="$ROOT_DIR/dist/ClipStack-$VERSION.dmg"
VOLUME_NAME="ClipStack"

"$ROOT_DIR/scripts/package-app.sh"

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

zsh "$ROOT_DIR/scripts/verify-dmg.sh" "$DMG_PATH"
rm -rf "$DMG_DIR"

echo "Created: $DMG_PATH"
