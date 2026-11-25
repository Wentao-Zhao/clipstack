#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/panel-preview"
OUTPUT_DIR="${1:-$ROOT_DIR/output/panel-preview}"
mkdir -p "$BUILD_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"

swiftc -parse-as-library -emit-library -emit-module -module-name ClipboardHistoryCore \
  -emit-module-path "$BUILD_DIR/ClipboardHistoryCore.swiftmodule" \
  "$ROOT_DIR"/Sources/ClipboardHistoryCore/*.swift \
  -o "$BUILD_DIR/libClipboardHistoryCore.dylib"

swiftc -parse-as-library -I "$BUILD_DIR" -L "$BUILD_DIR" -lClipboardHistoryCore \
  "$ROOT_DIR/Sources/ClipboardHistory/HistoryPanelController.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/HistoryShelfView.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/HistoryNoteView.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/ClipboardHistoryStore.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/ImageTextRecognizer.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/PinnedImageWindowManager.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/PinnedImageFrameView.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/OCRStatusPanelView.swift" \
  "$ROOT_DIR/Sources/ClipboardHistory/PasteboardWriter.swift" \
  "$ROOT_DIR/Tests/PanelPreview/PanelPreview.swift" \
  -o "$BUILD_DIR/PanelPreview"

DYLD_LIBRARY_PATH="$BUILD_DIR" "$BUILD_DIR/PanelPreview" "$OUTPUT_DIR"
