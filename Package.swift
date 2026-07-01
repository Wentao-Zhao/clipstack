// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "ClipboardHistory",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "ClipboardHistory", targets: ["ClipboardHistory"]),
    .executable(name: "ClipboardHistoryLogicTests", targets: ["ClipboardHistoryLogicTests"]),
  ],
  targets: [
    .target(
      name: "ClipboardHistoryCore",
      path: "Sources/ClipboardHistoryCore"
    ),
    .executableTarget(
      name: "ClipboardHistory",
      dependencies: ["ClipboardHistoryCore"],
      path: "Sources/ClipboardHistory"
    ),
    .executableTarget(
      name: "ClipboardHistoryLogicTests",
      dependencies: ["ClipboardHistoryCore"],
      path: "Tests/ClipboardHistoryTests"
    ),
  ]
)

