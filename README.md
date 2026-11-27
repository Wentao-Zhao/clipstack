# ClipStack

一个 macOS 13+ 菜单栏剪贴板历史工具，用于保留文本和图片复制历史，并通过快捷键快速呼出便签式历史面板。

## 功能

- 后台记录纯文本和图片剪贴板历史。
- 不影响系统默认 `Command+C` 和 `Command+V`。
- 默认双击 `Command` 呼出历史面板，也支持自定义呼出快捷键。
- 历史面板以便签形式贴在屏幕边缘展示，可配置上、下、左、右位置。
- 内容条使用白底选中态与钴蓝操作提示；选中时保持原尺寸，不使用放大、叠层或卡片阴影。
- 支持「全部 / 文本 / 图片」分类，分类可与关键词搜索组合使用。
- 普通文字、网页链接和可识别代码采用不同预览排版；复制与粘贴始终使用原始内容。
- 呼出后默认聚焦历史便签；直接输入文字会自动进入搜索，清空搜索内容后自动返回便签区域。
- 文本搜索基于前 500 个字符预览，新增图片支持 OCR 后搜索。
- 搜索框和便签区域支持键盘焦点切换：搜索框按 `↓` 进入便签区域，便签区域按 `↑` 回到搜索框。
- 点击历史项后可自动粘贴到之前的前台 App，也可配置为仅复制到系统剪贴板。
- 图片只在列表中展示缩略图。
- 图片预览使用最长边 480 像素的缩略图，旧版小缩略图在需要展示时自动更新。
- 图片便签使用与 PinShot 截图置顶一致的无边框窗口。鼠标移入后显示复制、识别文字和关闭按钮，支持拖动移动、右下角等比缩放及 `⌘C` 复制原图。
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

从 [GitHub Releases](https://github.com/Wentao-Zhao/clipstack/releases/latest) 获取最新 DMG：

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
dist/ClipStack-1.1.0.dmg
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

原生面板视觉与交互检查（需要可用的 macOS 图形会话）：

```bash
zsh scripts/verify-panel.sh
```

使用隔离的临时历史数据验证搜索、分类、键盘焦点与选择、图片置顶、四边布局、空状态及旧缩略图更新，并在 `output/panel-preview/` 保存真实 AppKit 截图。检查不会读写现有历史或系统剪贴板。

置顶窗口交互检查（需要可用的 macOS 图形会话）：

```bash
zsh scripts/check-pinned-images.sh
```

验证无边框显示、悬停工具栏、等比缩放、多窗口独立操作、复制原图和 OCR 文字选择复制，并在 `output/pinned-preview/` 保存窗口截图。复制操作使用测试替身，不会改动系统剪贴板。


## 手动检查更新（Sparkle）

在应用菜单或菜单栏右键菜单选择「检查更新…」，可查看新版并确认下载安装、替换应用和重启。仅手动触发，不自动轮询、下载或上传系统信息。首次需手动安装一版带 Sparkle 的新包。

更新框架固定为 Sparkle 2.10.1，原始许可随应用打包在 `Contents/Resources/Sparkle-LICENSE.txt`。应用保持现有最低 macOS 要求。

### 维护与发布

- 发布配置：`Resources/UpdateRelease.json`；公钥与更新源：`Resources/Info.plist`。
- 私钥保存在本机登录钥匙串的独立账户。禁止将私钥导出至仓库或提交；备份钥匙串，丢失后旧用户可能无法升级。
- 更新源是 GitHub Release 的 `releases/latest/download/appcast.xml`，清单和 DMG 都签名。每次 Release 必须同时发布 appcast.xml、DMG 与 SHA256SUMS；不能只上传新 DMG。
- 正式对外分发可配置 Developer ID 签名和公证；本次仍使用本地临时签名，无需额外购买服务。

准备本地更新包（构建、检查更新器配置、签名和公钥验证）：

```bash
zsh scripts/release-update.sh --prepare
```

发布前提升 `CFBundleShortVersionString` 和递增 `CFBundleVersion`，提交并推送代码及对应的 annotated `v版本` 标签，再执行：

```bash
zsh scripts/release-update.sh --publish
```

发布脚本先创建草稿并上传全部附件，再设为最新版；不会覆盖已有 Release。`zsh scripts/check-updater.sh --network` 可检查线上 feed；`python3 Tests/UpdateTests/test_appcast.py` 验证生成与失败处理（可选真实密钥测试使用 Python cryptography，生产签名校验使用系统 CryptoKit）。
