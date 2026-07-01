# 剪贴板历史实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 构建一个 macOS 菜单栏 App，记录文本和图片剪贴板历史，通过双击 `Command` 呼出列表并自动粘贴选中项。

**架构：** 使用 Swift Package 拆分为 `ClipboardHistoryCore` 和 `ClipboardHistory` 两个 target。核心策略保持纯 Swift、可测试；AppKit target 负责菜单栏、剪贴板、磁盘、面板和权限集成。

**技术栈：** Swift 5.9、AppKit、Foundation、CoreGraphics、ServiceManagement、UserDefaults、JSON 文件存储、轻量自定义测试 runner。

---

## 文件结构

- 创建：`Package.swift`，定义 App、Core、测试 runner 三个 target。
- 创建：`Resources/Info.plist`，定义菜单栏 App 信息。
- 创建：`Sources/ClipboardHistoryCore/ClipboardConfiguration.swift`，配置模型和默认值。
- 创建：`Sources/ClipboardHistoryCore/ClipboardHistoryItem.swift`，历史项元数据模型。
- 创建：`Sources/ClipboardHistoryCore/ClipboardCapturePolicy.swift`，文本和图片大小限制、文本预览策略。
- 创建：`Sources/ClipboardHistoryCore/ClipboardEvictionPolicy.swift`，过期、数量和缓存预算驱逐策略。
- 创建：`Sources/ClipboardHistoryCore/CommandDoubleTapDetector.swift`，双击 `Command` 状态机。
- 创建：`Sources/ClipboardHistory/ClipboardHistoryApp.swift`，App 入口和协调器。
- 创建：`Sources/ClipboardHistory/AccessibilityPermissionManager.swift`，辅助功能权限检查和跳转。
- 创建：`Sources/ClipboardHistory/PasteboardMonitor.swift`，监听系统剪贴板变化。
- 创建：`Sources/ClipboardHistory/ClipboardHistoryStore.swift`，磁盘索引、内容文件和缩略图存储。
- 创建：`Sources/ClipboardHistory/HistoryPanelController.swift`，历史列表面板。
- 创建：`Sources/ClipboardHistory/PreferencesWindowController.swift`，偏好设置窗口。
- 创建：`Sources/ClipboardHistory/StatusItemController.swift`，菜单栏右键菜单。
- 创建：`Sources/ClipboardHistory/MenuBarIcon.swift`，状态栏小图标。
- 创建：`Tests/ClipboardHistoryTests/TestRunner.swift`，核心逻辑测试。
- 创建：`README.md`，中文使用和构建说明。
- 创建：`scripts/package-app.sh`，生成 `.app`。
- 创建：`scripts/generate-app-icon.swift` 和 `scripts/generate-app-icon.sh`，生成 App 图标。

## 任务 1：项目骨架和红灯测试

**文件：**
- 创建：`Package.swift`
- 创建：`Tests/ClipboardHistoryTests/TestRunner.swift`

- [ ] **步骤 1：创建 Swift Package 骨架**

定义 `ClipboardHistoryCore`、`ClipboardHistory`、`ClipboardHistoryLogicTests` 三个 target。

- [ ] **步骤 2：编写失败的核心测试**

测试内容覆盖默认配置、文本限制、图片限制、预览截断、过期清理、数量清理、内存预算和双击 `Command`。

- [ ] **步骤 3：运行测试验证失败**

运行：

```bash
HOME="$PWD/.swift-home" CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk swift run --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ClipboardHistoryLogicTests
```

预期：编译失败，提示 `ClipboardConfiguration` 等核心类型未定义。

## 任务 2：实现核心配置、捕获策略和驱逐策略

**文件：**
- 创建：`Sources/ClipboardHistoryCore/ClipboardConfiguration.swift`
- 创建：`Sources/ClipboardHistoryCore/ClipboardHistoryItem.swift`
- 创建：`Sources/ClipboardHistoryCore/ClipboardCapturePolicy.swift`
- 创建：`Sources/ClipboardHistoryCore/ClipboardEvictionPolicy.swift`
- 修改：`Tests/ClipboardHistoryTests/TestRunner.swift`

- [ ] **步骤 1：实现最小核心模型和策略**

实现测试需要的公开 API：

- `ClipboardConfiguration.default`
- `ClipboardRetentionOption`
- `ClipboardHistoryItem`
- `ClipboardCapturePolicy`
- `ClipboardEvictionPolicy`

- [ ] **步骤 2：运行测试验证通过**

运行任务 1 的测试命令，预期所有已实现测试通过。

- [ ] **步骤 3：重构命名和边界**

保持测试通过，确保策略代码只依赖 Foundation。

## 任务 3：实现双击 Command 状态机

**文件：**
- 创建：`Sources/ClipboardHistoryCore/CommandDoubleTapDetector.swift`
- 修改：`Tests/ClipboardHistoryTests/TestRunner.swift`

- [ ] **步骤 1：编写双击 `Command` 测试**

覆盖单独双击触发、超时不触发、组合键不触发、普通按键取消。

- [ ] **步骤 2：运行测试验证失败**

预期：`CommandDoubleTapDetector` 未定义或行为未实现。

- [ ] **步骤 3：实现状态机**

使用纯 Swift 输入事件模型，不依赖 AppKit，便于测试。

- [ ] **步骤 4：运行测试验证通过**

运行逻辑测试，预期全部通过。

## 任务 4：实现 AppKit 集成

**文件：**
- 创建：`Sources/ClipboardHistory/ClipboardHistoryApp.swift`
- 创建：`Sources/ClipboardHistory/AccessibilityPermissionManager.swift`
- 创建：`Sources/ClipboardHistory/PasteboardMonitor.swift`
- 创建：`Sources/ClipboardHistory/ClipboardHistoryStore.swift`
- 创建：`Sources/ClipboardHistory/HistoryPanelController.swift`
- 创建：`Sources/ClipboardHistory/PreferencesWindowController.swift`
- 创建：`Sources/ClipboardHistory/StatusItemController.swift`
- 创建：`Sources/ClipboardHistory/MenuBarIcon.swift`
- 创建：`Resources/Info.plist`

- [ ] **步骤 1：实现菜单栏 App 入口**

创建 `NSApplicationDelegate`，设置 `.accessory` 激活策略，初始化状态栏、存储、监听器和面板控制器。

- [ ] **步骤 2：实现剪贴板监听和磁盘存储**

轮询 `NSPasteboard.general.changeCount`，保存文本、图片、索引和缩略图。

- [ ] **步骤 3：实现历史面板**

使用 `NSPanel` + `NSTableView` 展示文本预览和图片缩略图，选择后调用粘贴流程。

- [ ] **步骤 4：实现偏好设置**

用 AppKit 控件写入 `UserDefaults`，修改后立即影响后续捕获和清理。

- [ ] **步骤 5：实现权限和自动粘贴**

检查辅助功能权限；有权限时模拟 `Command+V`，无权限时只复制回剪贴板并提示。

## 任务 5：图标、文档和打包

**文件：**
- 创建：`README.md`
- 创建：`scripts/package-app.sh`
- 创建：`scripts/generate-app-icon.swift`
- 创建：`scripts/generate-app-icon.sh`
- 生成：`Resources/AppIcon.icns`

- [ ] **步骤 1：生成 App 图标**

使用脚本生成剪贴板风格图标和 `.icns`。

- [ ] **步骤 2：实现 `.app` 打包脚本**

复用 `ScreenCleaner` 的 Swift Package 打包模式，生成 `dist/ClipboardHistory.app`。

- [ ] **步骤 3：写 README**

说明功能、权限、构建、运行和测试方式。

## 任务 6：最终验证

**文件：**
- 修改：按验证结果修复必要文件

- [ ] **步骤 1：运行逻辑测试**

```bash
HOME="$PWD/.swift-home" CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk swift run --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ClipboardHistoryLogicTests
```

预期：全部通过。

- [ ] **步骤 2：运行发布构建**

```bash
HOME="$PWD/.swift-home" CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk swift build -c release --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
```

预期：构建成功。

- [ ] **步骤 3：运行打包脚本**

```bash
CLIPBOARD_HISTORY_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk HOME="$PWD/.swift-home" ./scripts/package-app.sh
```

预期：生成 `dist/ClipboardHistory.app`，签名验证通过。

- [ ] **步骤 4：检查格式和脚本语法**

```bash
zsh -n scripts/package-app.sh
zsh -n scripts/generate-app-icon.sh
```

预期：无输出，退出码为 0。

## 自检

- 规格中的 App 形态、核心流程、权限、存储、配置、清理、UI 和测试策略均有对应任务。
- 计划没有保留“待定”“TODO”或“后续实现”占位内容。
- 类型命名在计划中保持一致：`ClipboardConfiguration`、`ClipboardHistoryItem`、`ClipboardCapturePolicy`、`ClipboardEvictionPolicy`、`CommandDoubleTapDetector`。
- 由于当前父目录不是 Git 仓库，本计划不强制每个任务 commit；如后续初始化 Git，可按任务粒度提交。
