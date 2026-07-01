#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
mkdir -p "$ROOT_DIR/.build" "$CLANG_MODULE_CACHE_PATH"

BUILD_ARGS=()
if [[ -n "${CLIPSTACK_SDK:-}" ]]; then
    BUILD_ARGS+=(-sdk "$CLIPSTACK_SDK")
elif [[ -n "${CLIPBOARD_HISTORY_SDK:-}" ]]; then
    BUILD_ARGS+=(-sdk "$CLIPBOARD_HISTORY_SDK")
fi

swiftc "${BUILD_ARGS[@]}" scripts/generate-app-icon.swift -o "$ROOT_DIR/.build/generate-app-icon"
"$ROOT_DIR/.build/generate-app-icon"
iconutil -c icns "$ROOT_DIR/Resources/AppIcon.iconset" -o "$ROOT_DIR/Resources/AppIcon.icns"
rm -rf "$ROOT_DIR/Resources/AppIcon.iconset"

echo "Created: $ROOT_DIR/Resources/AppIcon.icns"
