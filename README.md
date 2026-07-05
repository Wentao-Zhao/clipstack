# ClipStack

一个 macOS 13+ 菜单栏剪贴板历史工具，用于保留文本和图片复制历史，并通过快捷键快速呼出便签式历史面板。

## 功能

- 后台记录纯文本和图片剪贴板历史。
- 不影响系统默认 `Command+C` 和 `Command+V`。
- 默认双击 `Command` 呼出历史面板，也支持自定义呼出快捷键。
- 历史面板以便签形式贴在屏幕边缘展示，可配置上、下、左、右位置。
- 呼出后默认聚焦历史便签；直接输入文字会自动进入搜索，清空搜索内容后自动返回便签区域。
- 文本搜索基于前 500 个字符预览，新增图片支持 OCR 后搜索。
- 搜索框和便签区域支持键盘焦点切换：搜索框按 `↓` 进入便签区域，便签区域按 `↑` 回到搜索框。
- 点击历史项后可自动粘贴到之前的前台 App，也可配置为仅复制到系统剪贴板。
- 图片只在列表中展示缩略图。
- 图片便签支持置顶显示，可同时打开多个可调整大小的置顶图片窗口。
- 大文本只展示前 500 个字符。
- 文件、视频和复杂富文本不记录。

## 默认配置

- 保留时间：6 小时。
- 文本最多：100 条。
- 图片最多：10 张。
- 单条文本上限：4 MB。
- 单张图片上限：5 MB。
- 内存预算：32 MB。
- 呼出位置：屏幕下方。
- 外观模式：跟随系统，可选浅色模式或深色模式。
- 呼出快捷键：双击 `Command`，可改为双击 `Option`、`Control`、`Shift`、自定义组合键，或关闭快捷键。
- 选中后动作：自动粘贴到当前 App，可改为仅复制到剪贴板。
- 开机自启：默认关闭。
- 退出 App 时清空历史：默认关闭。

配置可以在菜单栏右键菜单的「偏好设置」里调整。

## 安装

从 GitHub Releases 下载最新 DMG：

```text
ClipStack.dmg
```

安装步骤：

1. 打开 DMG。
2. 将 `ClipStack.app` 拖到 `Applications`。
3. 如果 macOS 阻止直接打开，请右键 `ClipStack.app`，选择「打开」，并在系统提示中确认。
4. App 启动后不会显示 Dock 图标，只驻留在菜单栏。

## 使用

常用流程：

1. 正常使用 `Command+C` 复制文本或图片。
2. 双击 `Command` 呼出历史面板。
3. 输入关键字搜索历史，或使用方向键切换选中项。
4. 点击便签或按 `Enter`，按配置自动粘贴到当前 App 或复制回系统剪贴板。
5. 图片便签上的置顶按钮可以把图片作为独立悬浮窗口显示。

## 权限说明

记录剪贴板不需要辅助功能权限。

以下能力需要辅助功能权限：

- 全局监听双击 `Command` 或自定义快捷键。
- 选择历史项后自动发送 `Command+V`。

首次使用自动粘贴时，如果权限未开启，App 会把历史项复制回系统剪贴板，并提示开启权限。进入：

```text
系统设置 > 隐私与安全性 > 辅助功能
```

允许「ClipStack」后即可自动粘贴。

## 隐私边界

- 剪贴板历史保存在当前 Mac 当前用户的 Application Support 目录。
- 默认不加密，不上传，不做云同步。
- 图片 OCR 只处理新增图片，并只保存最多 500 个字符的可搜索文本。
- 敏感场景建议打开「退出 App 时清空历史」，或通过菜单栏右键菜单手动「清空历史」。

## 构建

```bash
cd ClipboardHistory
./scripts/package-app.sh
```

生成文件：

```text
dist/ClipStack.app
```

如果本机 Command Line Tools 存在 Swift SDK 小版本不匹配问题，可以指定已安装 SDK：

```bash
CLIPBOARD_HISTORY_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  ./scripts/package-app.sh
```

## 生成 DMG

```bash
./scripts/package-dmg.sh
```

生成文件：

```text
dist/ClipStack.dmg
```

## 自动化检查

逻辑测试：

```bash
swift run ClipboardHistoryLogicTests
```

发布构建：

```bash
swift build -c release
```
