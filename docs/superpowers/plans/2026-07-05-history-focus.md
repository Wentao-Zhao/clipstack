# 历史面板焦点优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 让 ClipStack 默认聚焦历史区、直接键入即可搜索，并在搜索清空后自动返回历史区。

**架构：** 新增纯 Swift 输入路由判断可打印键盘事件，AppKit 视图只转发符合条件的事件。移除旧的初始搜索焦点配置，面板统一采用历史区初始焦点。

**技术栈：** Swift 5.9、AppKit、现有命令行逻辑测试。

---

### 任务 1：输入路由逻辑

**文件：**
- 创建：`Sources/ClipboardHistoryCore/HistorySearchInputRouting.swift`
- 修改：`Tests/ClipboardHistoryTests/TestRunner.swift`

- [x] 编写失败测试，覆盖普通字符可启动搜索，以及控制键、方向键和快捷键不可启动搜索。
- [x] 运行 `swift run ClipboardHistoryLogicTests`，确认因输入路由类型不存在而失败。
- [x] 实现只接受可打印文本且排除 Command/Control 与功能键的输入路由。
- [x] 再次运行逻辑测试并确认通过。

### 任务 2：焦点交互与配置清理

**文件：**
- 修改：`Sources/ClipboardHistory/HistoryPanelController.swift`
- 修改：`Sources/ClipboardHistoryCore/ClipboardConfiguration.swift`
- 修改：`Sources/ClipboardHistory/ClipboardPreferencesStore.swift`
- 修改：`Sources/ClipboardHistory/PreferencesWindowController.swift`
- 修改：`Tests/ClipboardHistoryTests/TestRunner.swift`

- [x] 先修改配置测试，要求默认配置不再暴露 `focusSearchOnShow`。
- [x] 运行逻辑测试，确认旧配置断言或编译产生预期失败。
- [x] 移除配置字段、UserDefaults 读写和偏好设置控件。
- [x] 将历史区设为统一初始焦点；普通输入切换并转发至搜索框；查询清空后恢复历史区焦点。
- [x] 运行逻辑测试并确认通过。

### 任务 3：文档与发布验证

**文件：**
- 修改：`README.md`

- [x] 更新默认焦点和直接输入搜索说明。
- [x] 运行 `swift run ClipboardHistoryLogicTests`，预期全部通过。
- [x] 运行 `swift build -c release`，预期构建成功且无新增错误。
- [x] 运行 `git diff --check`，预期无空白错误。
