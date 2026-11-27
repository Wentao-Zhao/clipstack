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
    .binaryTarget(
      name: "Sparkle",
      url: "https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-for-Swift-Package-Manager.zip",
      checksum: "4c2e48a3e50ebcc2c88a58a4c7264a1a99c3c31857ce754357afb9cdb323022a"
    ),
    .target(
      name: "ClipboardHistoryCore",
      path: "Sources/ClipboardHistoryCore"
    ),
    .executableTarget(
      name: "ClipboardHistory",
      dependencies: ["ClipboardHistoryCore", "Sparkle"],
      path: "Sources/ClipboardHistory",
      linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
    ),
    .executableTarget(
      name: "ClipboardHistoryLogicTests",
      dependencies: ["ClipboardHistoryCore"],
      path: "Tests/ClipboardHistoryTests"
    ),
  ]
)

