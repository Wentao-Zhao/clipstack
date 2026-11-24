import AppKit
import ClipboardHistoryCore

/// Exercises the actual panel with scratch history. Never touches the system clipboard.
@MainActor
@main
enum PanelPreview {
  static func main() throws {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("clipstack-panel-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: scratch) }
    var config = ClipboardConfiguration.default
    config.panelAppearance = .dark
    let seededStore = ClipboardHistoryStore(rootURL: scratch) { config }
    seed(seededStore)
    let legacyURL = seededStore.thumbnailURL(for: seededStore.items[0])!
    try fixtureImage(terminal: false, size: NSSize(width: 96, height: 52)).write(to: legacyURL)
    let store = ClipboardHistoryStore(rootURL: scratch) { config }
    var activated: [String] = []
    var pinned: [String] = []
    var openedPreferences = false
    let controller = HistoryPanelController(
      store: store, configurationProvider: { config },
      onSelect: { item, _ in activated.append(item.id) },
      onPinImage: { item, _ in pinned.append(item.id) },
      onOpenPreferences: { openedPreferences = true }
    )
    controller.show()
    let window = app.windows.first { $0.contentView is HistoryShelfView }!
    defer { controller.close() }
    func root() -> HistoryShelfView { window.contentView as! HistoryShelfView }
    func views() -> [NSView] { descendants(root()) }
    func notes() -> [HistoryNoteView] { views().compactMap { $0 as? HistoryNoteView } }
    func filter(_ title: String) {
      let button = root().subviews.compactMap { $0 as? NSButton }.first { $0.title == title }!
      button.performClick(nil)
    }
    func search(_ query: String) {
      let field = root().subviews.compactMap { $0 as? NSSearchField }.first!
      field.stringValue = query
      controller.controlTextDidChange(Notification(name: Notification.Name("PreviewSearchChange"), object: field))
    }
    func key(_ code: UInt16) {
      let characters: String
      switch code {
      case 123: characters = "\u{F702}"
      case 124: characters = "\u{F703}"
      case 125: characters = "\u{F701}"
      case 126: characters = "\u{F700}"
      case 36: characters = "\r"
      default: characters = ""
      }
      let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
      window.firstResponder?.keyDown(with: event)
    }
    func snapshot(_ name: String) throws {
      root().layoutSubtreeIfNeeded()
      let image = root().bitmapImageRepForCachingDisplay(in: root().bounds)!
      root().cacheDisplay(in: root().bounds, to: image)
      try image.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
    }

    precondition(root().resultCount == 5 && root().selectedIndex == 0)
    precondition(notes().count == 5 && notes().allSatisfy { $0.bounds.width > 160 })
    let previewURL = store.thumbnailURL(for: store.items[0])!
    let thumbnail = NSBitmapImageRep(data: try Data(contentsOf: previewURL))!
    precondition(max(thumbnail.pixelsWide, thumbnail.pixelsHigh) >= 480, "Large previews need Retina-sized thumbnail pixels")
    try snapshot("dark")
    let pin = notes()[0].subviews.compactMap { $0 as? NSButton }.first!
    pin.performClick(nil)
    precondition(pinned.count == 1 && activated.isEmpty, "Pinning must not activate or paste")
    key(124)
    precondition(root().selectedIndex == 1, "Right arrow selects the next item")
    try snapshot("dark-text-selected")
    key(126)
    precondition(window.firstResponder is NSTextView || window.firstResponder is NSSearchField, "Up moves focus to search")
    key(125)
    precondition(!(window.firstResponder is NSTextView), "Down returns focus to items")
    search("developer")
    precondition(root().resultCount == 1)
    precondition(notes()[0].accessibilityLabel()?.contains("/docs") == true, "VoiceOver exposes URL paths")
    filter("图片")
    precondition(root().resultCount == 0 && root().selectedIndex == nil)
    try snapshot("no-results")
    search("")
    precondition(root().resultCount == 2 && root().selectedIndex == 0)
    filter("文本")
    precondition(root().resultCount == 3)
    filter("全部")
    precondition(root().resultCount == 5)
    key(124)
    key(124)
    key(124)
    key(124)
    precondition(notes().last!.accessibilityLabel()?.contains("SELECT owner_id") == true, "VoiceOver exposes code content")
    key(36)
    precondition(activated.count == 1 && !window.isVisible, "Enter activates one item and dismisses the panel")

    config.panelAppearance = .light
    controller.show()
    try snapshot("light")
    config.selectionAction = .copyToClipboard
    controller.show()
    precondition(notes()[0].accessibilityHelp()?.contains("复制") == true)
    try snapshot("light-copy-mode")
    for edge in [ClipboardPanelEdge.left, .right, .top] {
      config.panelEdge = edge
      controller.show()
      precondition(root().isHorizontal == edge.isHorizontal)
      precondition(notes()[0].bounds.width >= 160)
      try snapshot(edge.rawValue)
    }

    config.panelEdge = .bottom
    config.panelAppearance = .dark
    for i in 0..<20 { store.saveText("第 \(i + 1) 条测试历史") }
    controller.show()
    for _ in 0..<24 { key(124) }
    precondition(root().selectedIndex == 24)
    let last = notes().last!
    let viewport = last.enclosingScrollView!.contentView.bounds
    precondition(viewport.maxX >= last.frame.maxX - 1, "Keyboard selection scrolls the item into view")
    try snapshot("scrolled")
    let settings = root().subviews.compactMap { $0 as? NSButton }.first { $0.toolTip == "偏好设置" }!
    settings.performClick(nil)
    precondition(openedPreferences && !window.isVisible)
    store.clearAll()
    controller.show()
    precondition(root().resultCount == 0)
    try snapshot("empty")
    print("PASS: native panel rendering and interaction checks; snapshots: \(directory.path)")
  }

  private static func descendants(_ view: NSView) -> [NSView] {
    view.subviews.flatMap { [$0] + descendants($0) }
  }

  private static func seed(_ store: ClipboardHistoryStore) {
    let now = Date()
    store.saveText("SELECT owner_id,\n       tenant_id\nFROM users;", now: now.addingTimeInterval(-1860))
    store.saveText("https://developer.example.com/docs", now: now.addingTimeInterval(-540))
    store.saveImageData(fixtureImage(terminal: true), now: now.addingTimeInterval(-420))
    store.saveText("检查提交重大风险\n合并前检查数据安全、权限变更与兼容性影响。", now: now.addingTimeInterval(-300))
    store.saveImageData(fixtureImage(terminal: false), now: now.addingTimeInterval(-240))
  }

  private static func fixtureImage(terminal: Bool, size: NSSize = NSSize(width: 600, height: 320)) -> Data {
    let image = NSImage(size: size, flipped: true) { rect in
      (terminal ? NSColor(white: 0.06, alpha: 1) : .white).setFill()
      rect.fill()
      if terminal {
        ShelfDrawing.text("● ● ●     ~ — zsh", in: NSRect(x: 18, y: 12, width: 560, height: 32), font: .monospacedSystemFont(ofSize: 20, weight: .regular), color: .lightGray)
        ShelfDrawing.text("❯ git status\nOn branch main\nYour branch is up to date.\n\nnothing to commit,\nworking tree clean", in: NSRect(x: 20, y: 63, width: 560, height: 245), font: .monospacedSystemFont(ofSize: 23, weight: .regular), color: .white, wrap: true)
      } else {
        let rows = ["地区          销售额       同比", "华东        1,240,000     +12.3%", "华南          980,000      +8.7%", "华北          760,000      +5.1%", "华中          640,000      +4.6%"]
        for (index, line) in rows.enumerated() {
          let y = CGFloat(index) * 62
          if index == 0 { ShelfDrawing.roundedRect(NSRect(x: 0, y: 0, width: 600, height: 62), radius: 0, color: NSColor(white: 0.93, alpha: 1)) }
          ShelfDrawing.text(line, in: NSRect(x: 16, y: y + 15, width: 568, height: 36), font: .monospacedSystemFont(ofSize: 23, weight: index == 0 ? .semibold : .regular), color: .black)
          ShelfDrawing.line(from: NSPoint(x: 0, y: y + 61), to: NSPoint(x: 600, y: y + 61), color: .lightGray)
        }
      }
      return true
    }
    return NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
  }
}
