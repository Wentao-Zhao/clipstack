#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
module_cache="$PWD/.build/clang-module-cache"
mkdir -p "$module_cache"
compiler_args=(-target "$(uname -m)-apple-macos13" -module-cache-path "$module_cache")
swiftc "${compiler_args[@]}" -module-name ClipboardHistoryCore -emit-module -emit-library -static \
  -o "$build_dir/libClipboardHistoryCore.a" Sources/ClipboardHistoryCore/*.swift
sources=(Sources/ClipboardHistory/*PinnedImage*.swift Sources/ClipboardHistory/*OCR*.swift(N)
         Sources/ClipboardHistory/ImageTextRecognizer.swift)
swiftc "${compiler_args[@]}" -I "$build_dir" -L "$build_dir" -lClipboardHistoryCore \
  -o "$build_dir/PinnedImageAppTests" "${sources[@]}" Tests/PinnedImageAppTests/TestRunner.swift
"$build_dir/PinnedImageAppTests" "${1:-$PWD/output/pinned-preview}" | tee "$build_dir/results"
rg -q '^PASS: [0-9]+ AppKit interaction checks$' "$build_dir/results"
