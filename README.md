# ClipStack

一个 macOS 13+ 菜单栏小工具，用于保留文本和图片剪贴板历史。

## 功能

- 后台记录纯文本和图片剪贴板历史。
- 不影响系统默认 `Command+C` 和 `Command+V`。
- 双击 `Command` 呼出历史面板。
- 历史面板以便签形式贴在屏幕边缘展示，可配置上、下、左、右位置。
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
- 呼出快捷键：双击 `Command`，可改为双击 `Option`、`Control`、`Shift`，或关闭快捷键。
- 选中后动作：自动粘贴到当前 App，可改为仅复制到剪贴板。
- 开机自启：默认关闭。
- 内容落盘保存到本机 Application Support 目录，不加密。
- 退出 App 时清空历史：默认关闭。

配置可以在菜单栏右键菜单的「偏好设置」里调整。

## 权限说明

记录剪贴板不需要辅助功能权限。

以下能力需要辅助功能权限：

- 全局监听双击 `Command`。
- 选择历史项后自动发送 `Command+V`。

首次使用自动粘贴时，如果权限未开启，App 会把历史项复制回系统剪贴板，并提示开启权限。进入：

```text
系统设置 > 隐私与安全性 > 辅助功能
```

允许「ClipStack」后即可自动粘贴。

## 构建

```bash
cd ClipboardHistory
./scripts/package-app.sh
```

生成文件：

```text
dist/ClipStack.app
```

当前机器的 Command Line Tools 如果存在 Swift SDK 小版本不匹配问题，可以指定已安装 SDK：

```bash
CLIPBOARD_HISTORY_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  ./scripts/package-app.sh
```

## 运行

```bash
open dist/ClipStack.app
```

App 打开后不会显示 Dock 图标，也不会弹出主窗口。请看菜单栏右侧的小剪贴板图标，右键可打开菜单。

## 自动化检查

逻辑测试：

```bash
SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
swift run --sdk "$SDK" ClipboardHistoryLogicTests
```

发布构建：

```bash
SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
swift build -c release --sdk "$SDK"
```

## 隐私边界

第一版不加密，也不做云同步。历史只保存在当前 Mac 当前用户目录下。敏感场景建议打开「退出 App 时清空历史」，或通过菜单栏右键菜单手动「清空历史」。
