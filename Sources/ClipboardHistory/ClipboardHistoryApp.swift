import AppKit
import ClipboardHistoryCore
import CoreGraphics

@MainActor
@main
enum ClipboardHistoryMain {
  private static let appDelegate = AppDelegate()

  static func main() {
    let application = NSApplication.shared
    application.delegate = appDelegate
    application.setActivationPolicy(.accessory)
    application.run()
  }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
  private var controller: ClipboardHistoryApplicationController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    controller = ClipboardHistoryApplicationController()
    controller?.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    controller?.stop()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}

@MainActor
private final class ClipboardHistoryApplicationController {
  private let preferencesStore = ClipboardPreferencesStore()
  private let permissionManager = AccessibilityPermissionManager()
  private lazy var historyStore = ClipboardHistoryStore {
    self.preferencesStore.configuration
  }
  private lazy var pasteboardMonitor = PasteboardMonitor(
    store: historyStore,
    configurationProvider: { self.preferencesStore.configuration }
  )
  private lazy var historyPanelController = HistoryPanelController(
    store: historyStore,
    configurationProvider: { self.preferencesStore.configuration },
    onSelect: { [weak self] item, targetApplication in
      self?.paste(item, targetApplication: targetApplication)
    },
    onPinImage: { [weak self] item in
      self?.pinImage(item)
    },
    onOpenPreferences: { [weak self] in
      self?.preferencesWindowController.show()
    }
  )
  private lazy var pinnedImageWindowManager = PinnedImageWindowManager()
  private lazy var preferencesWindowController = PreferencesWindowController(
    preferencesStore: preferencesStore,
    onConfigurationChanged: { [weak self] in
      self?.applyAppPreferences()
    }
  )
  private lazy var commandKeyMonitor = CommandKeyMonitor(
    configurationProvider: { self.preferencesStore.configuration },
    onTrigger: { [weak self] in
      self?.showHistoryPanel()
    }
  )
  private lazy var statusItemController = StatusItemController(
    onOpenHistory: { [weak self] in self?.showHistoryPanel() },
    onOpenPreferences: { [weak self] in self?.preferencesWindowController.show() },
    onClearHistory: { [weak self] in self?.historyStore.clearAll() },
    onQuit: { [weak self] in self?.quit() }
  )

  func start() {
    _ = statusItemController
    applyAppPreferences()
    historyStore.prune()
    pasteboardMonitor.start()
    commandKeyMonitor.start()
  }

  func stop() {
    pasteboardMonitor.stop()
    commandKeyMonitor.stop()

    if preferencesStore.configuration.clearHistoryOnQuit {
      historyStore.clearAll()
    }
  }

  private func showHistoryPanel() {
    historyPanelController.show()
  }

  private func applyAppPreferences() {
    let config = preferencesStore.configuration
    LaunchAtLoginController.apply(enabled: config.launchAtLoginEnabled)
    commandKeyMonitor.refreshConfiguration()
    historyStore.prune()
  }

  private func paste(
    _ item: ClipboardHistoryItem,
    targetApplication: NSRunningApplication?
  ) {
    guard historyStore.writeToPasteboard(item) else {
      presentMessage("无法读取这条历史记录", informativeText: "对应的本地内容文件可能已经被删除。")
      return
    }

    historyStore.markUsed(item)

    guard preferencesStore.configuration.selectionAction == .pasteToActiveApp else {
      return
    }

    guard permissionManager.isTrusted else {
      permissionManager.requestAccess()
      presentMessage(
        "已复制到系统剪贴板",
        informativeText: "开启辅助功能权限后，选择历史项会自动粘贴到当前 App。"
      )
      return
    }

    targetApplication?.activate(options: [.activateIgnoringOtherApps])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      Self.sendPasteShortcut()
    }
  }

  private func pinImage(_ item: ClipboardHistoryItem) {
    guard item.kind == .image else {
      return
    }

    guard
      let data = historyStore.contentData(for: item),
      let image = NSImage(data: data)
    else {
      presentMessage("无法置顶这张图片", informativeText: "对应的本地图片文件可能已经被删除。")
      return
    }

    historyStore.markUsed(item)
    pinnedImageWindowManager.show(image: image)
  }

  private func quit() {
    stop()
    NSApp.terminate(nil)
  }

  private func presentMessage(_ message: String, informativeText: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = informativeText
    alert.alertStyle = .informational
    alert.runModal()
  }

  private static func sendPasteShortcut() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyCodeV: CGKeyCode = 9

    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
    keyDown?.flags = .maskCommand

    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
    keyUp?.flags = .maskCommand

    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }
}
