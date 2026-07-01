import AppKit

@MainActor
final class StatusItemController: NSObject {
  private let statusItem: NSStatusItem
  private let onOpenHistory: () -> Void
  private let onOpenPreferences: () -> Void
  private let onClearHistory: () -> Void
  private let onQuit: () -> Void

  init(
    onOpenHistory: @escaping () -> Void,
    onOpenPreferences: @escaping () -> Void,
    onClearHistory: @escaping () -> Void,
    onQuit: @escaping () -> Void
  ) {
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    self.onOpenHistory = onOpenHistory
    self.onOpenPreferences = onOpenPreferences
    self.onClearHistory = onClearHistory
    self.onQuit = onQuit
    super.init()
    configure()
  }

  private func configure() {
    guard let button = statusItem.button else {
      return
    }

    button.image = MenuBarIcon.image
    button.imagePosition = .imageOnly
    button.toolTip = "右键打开 ClipStack 菜单"
    button.target = self
    button.action = #selector(showMenu(_:))
    button.sendAction(on: [.rightMouseUp])
  }

  @objc private func showMenu(_ sender: NSStatusBarButton) {
    let menu = NSMenu()

    let openItem = NSMenuItem(title: "打开 ClipStack", action: #selector(openHistory), keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)

    let preferencesItem = NSMenuItem(title: "偏好设置", action: #selector(openPreferences), keyEquivalent: ",")
    preferencesItem.target = self
    menu.addItem(preferencesItem)

    menu.addItem(.separator())

    let clearItem = NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: "")
    clearItem.target = self
    menu.addItem(clearItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "退出 App", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY - 4), in: sender)
  }

  @objc private func openHistory() {
    onOpenHistory()
  }

  @objc private func openPreferences() {
    onOpenPreferences()
  }

  @objc private func clearHistory() {
    let alert = NSAlert()
    alert.messageText = "清空 ClipStack 历史？"
    alert.informativeText = "这会删除本机保存的所有文本和图片历史。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "清空")
    alert.addButton(withTitle: "取消")

    if alert.runModal() == .alertFirstButtonReturn {
      onClearHistory()
    }
  }

  @objc private func quit() {
    onQuit()
  }
}
