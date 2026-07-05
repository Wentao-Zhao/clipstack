import AppKit
import ClipboardHistoryCore

@MainActor
final class PreferencesWindowController: NSWindowController {
  private let preferencesStore: ClipboardPreferencesStore
  private let onConfigurationChanged: () -> Void

  private let retentionPopup = NSPopUpButton()
  private let maxTextField = NSTextField()
  private let maxImageField = NSTextField()
  private let maxTextSizeField = NSTextField()
  private let maxImageSizeField = NSTextField()
  private let memoryBudgetPopup = NSPopUpButton()
  private let panelEdgePopup = NSPopUpButton()
  private let panelAppearancePopup = NSPopUpButton()
  private let activationShortcutPopup = NSPopUpButton()
  private let shortcutRecorderButton = ShortcutRecorderButton()
  private let selectionActionPopup = NSPopUpButton()
  private let launchAtLoginSwitch = NSSwitch()
  private let clearOnQuitSwitch = NSSwitch()

  init(
    preferencesStore: ClipboardPreferencesStore,
    onConfigurationChanged: @escaping () -> Void
  ) {
    self.preferencesStore = preferencesStore
    self.onConfigurationChanged = onConfigurationChanged

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 460, height: 504),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "ClipStack 偏好设置"
    window.isReleasedWhenClosed = false

    super.init(window: window)
    buildContent()
    reloadControls()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show() {
    reloadControls()
    window?.center()
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func buildContent() {
    let stack = NSStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.edgeInsets = NSEdgeInsets(top: 20, left: 22, bottom: 20, right: 22)

    configureControls()

    stack.addArrangedSubview(row(label: "保留时间", control: retentionPopup))
    stack.addArrangedSubview(row(label: "文本最多", control: maxTextField, suffix: "条"))
    stack.addArrangedSubview(row(label: "图片最多", control: maxImageField, suffix: "张"))
    stack.addArrangedSubview(row(label: "单条文本上限", control: maxTextSizeField, suffix: "MB"))
    stack.addArrangedSubview(row(label: "单张图片上限", control: maxImageSizeField, suffix: "MB"))
    stack.addArrangedSubview(row(label: "内存预算", control: memoryBudgetPopup))
    stack.addArrangedSubview(row(label: "呼出位置", control: panelEdgePopup))
    stack.addArrangedSubview(row(label: "外观模式", control: panelAppearancePopup))
    stack.addArrangedSubview(row(label: "呼出快捷键", control: shortcutControls()))
    stack.addArrangedSubview(row(label: "选中后动作", control: selectionActionPopup))
    stack.addArrangedSubview(row(label: "开机自启", control: launchAtLoginSwitch))
    stack.addArrangedSubview(row(label: "退出 App 时清空历史", control: clearOnQuitSwitch))

    let note = NSTextField(labelWithString: "内容保存在本机 Application Support 目录，不加密。修改后立即生效。")
    note.translatesAutoresizingMaskIntoConstraints = false
    note.textColor = .secondaryLabelColor
    note.font = .systemFont(ofSize: 12)
    note.maximumNumberOfLines = 2
    stack.addArrangedSubview(note)

    window?.contentView = stack

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: window!.contentView!.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: window!.contentView!.trailingAnchor),
      stack.topAnchor.constraint(equalTo: window!.contentView!.topAnchor),
      stack.bottomAnchor.constraint(equalTo: window!.contentView!.bottomAnchor),
    ])
  }

  private func configureControls() {
    for option in ClipboardRetentionOption.allCases {
      retentionPopup.addItem(withTitle: option.displayName)
      retentionPopup.lastItem?.representedObject = option.rawValue
    }

    for value in [32, 64, 128, 256] {
      memoryBudgetPopup.addItem(withTitle: "\(value) MB")
      memoryBudgetPopup.lastItem?.representedObject = value
    }

    for edge in ClipboardPanelEdge.allCases {
      panelEdgePopup.addItem(withTitle: edge.displayName)
      panelEdgePopup.lastItem?.representedObject = edge.rawValue
    }

    for appearance in ClipboardPanelAppearance.allCases {
      panelAppearancePopup.addItem(withTitle: appearance.displayName)
      panelAppearancePopup.lastItem?.representedObject = appearance.rawValue
    }

    for shortcut in ClipboardActivationShortcut.allCases {
      activationShortcutPopup.addItem(withTitle: shortcut.displayName)
      activationShortcutPopup.lastItem?.representedObject = shortcut.rawValue
    }

    for action in ClipboardSelectionAction.allCases {
      selectionActionPopup.addItem(withTitle: action.displayName)
      selectionActionPopup.lastItem?.representedObject = action.rawValue
    }

    for textField in [maxTextField, maxImageField, maxTextSizeField, maxImageSizeField] {
      textField.alignment = .right
      textField.controlSize = .regular
      textField.target = self
      textField.action = #selector(controlChanged)
    }

    retentionPopup.target = self
    retentionPopup.action = #selector(controlChanged)
    memoryBudgetPopup.target = self
    memoryBudgetPopup.action = #selector(controlChanged)
    panelEdgePopup.target = self
    panelEdgePopup.action = #selector(controlChanged)
    panelAppearancePopup.target = self
    panelAppearancePopup.action = #selector(controlChanged)
    activationShortcutPopup.target = self
    activationShortcutPopup.action = #selector(controlChanged)
    shortcutRecorderButton.onShortcutCaptured = { [weak self] shortcut in
      self?.customShortcutCaptured(shortcut)
    }
    selectionActionPopup.target = self
    selectionActionPopup.action = #selector(controlChanged)
    launchAtLoginSwitch.target = self
    launchAtLoginSwitch.action = #selector(controlChanged)
    clearOnQuitSwitch.target = self
    clearOnQuitSwitch.action = #selector(controlChanged)
  }

  private func reloadControls() {
    let config = preferencesStore.configuration
    let option = ClipboardRetentionOption.allCases.first { $0.duration == config.retentionDuration } ?? .sixHours

    retentionPopup.selectItem(withTitle: option.displayName)
    maxTextField.stringValue = "\(config.maxTextItems)"
    maxImageField.stringValue = "\(config.maxImageItems)"
    maxTextSizeField.stringValue = "\(config.maxTextBytes / 1024 / 1024)"
    maxImageSizeField.stringValue = "\(config.maxImageBytes / 1024 / 1024)"
    memoryBudgetPopup.selectItem(withTitle: "\(config.memoryBudgetBytes / 1024 / 1024) MB")
    panelEdgePopup.selectItem(withTitle: config.panelEdge.displayName)
    panelAppearancePopup.selectItem(withTitle: config.panelAppearance.displayName)
    activationShortcutPopup.selectItem(withTitle: config.activationShortcut.displayName)
    shortcutRecorderButton.shortcut = config.customActivationShortcut
    shortcutRecorderButton.isEnabled = config.activationShortcut == .customKeyCombo
    selectionActionPopup.selectItem(withTitle: config.selectionAction.displayName)
    launchAtLoginSwitch.state = config.launchAtLoginEnabled ? .on : .off
    clearOnQuitSwitch.state = config.clearHistoryOnQuit ? .on : .off
  }

  @objc private func controlChanged() {
    var config = preferencesStore.configuration

    if
      let rawValue = retentionPopup.selectedItem?.representedObject as? String,
      let option = ClipboardRetentionOption(rawValue: rawValue)
    {
      config.retentionDuration = option.duration
    }

    config.maxTextItems = positiveInt(from: maxTextField, fallback: config.maxTextItems)
    config.maxImageItems = positiveInt(from: maxImageField, fallback: config.maxImageItems)
    config.maxTextBytes = positiveInt(from: maxTextSizeField, fallback: config.maxTextBytes / 1024 / 1024) * 1024 * 1024
    config.maxImageBytes = positiveInt(from: maxImageSizeField, fallback: config.maxImageBytes / 1024 / 1024) * 1024 * 1024

    if let memoryMB = memoryBudgetPopup.selectedItem?.representedObject as? Int {
      config.memoryBudgetBytes = memoryMB * 1024 * 1024
    }

    if
      let rawValue = panelEdgePopup.selectedItem?.representedObject as? String,
      let panelEdge = ClipboardPanelEdge(rawValue: rawValue)
    {
      config.panelEdge = panelEdge
    }

    if
      let rawValue = panelAppearancePopup.selectedItem?.representedObject as? String,
      let panelAppearance = ClipboardPanelAppearance(rawValue: rawValue)
    {
      config.panelAppearance = panelAppearance
    }

    if
      let rawValue = activationShortcutPopup.selectedItem?.representedObject as? String,
      let activationShortcut = ClipboardActivationShortcut(rawValue: rawValue)
    {
      config.activationShortcut = activationShortcut
    }
    if config.activationShortcut == .customKeyCombo {
      config.customActivationShortcut = shortcutRecorderButton.shortcut
    }

    if
      let rawValue = selectionActionPopup.selectedItem?.representedObject as? String,
      let selectionAction = ClipboardSelectionAction(rawValue: rawValue)
    {
      config.selectionAction = selectionAction
    }

    config.launchAtLoginEnabled = launchAtLoginSwitch.state == .on
    config.clearHistoryOnQuit = clearOnQuitSwitch.state == .on
    preferencesStore.configuration = config
    shortcutRecorderButton.isEnabled = config.activationShortcut == .customKeyCombo
    onConfigurationChanged()
  }

  private func customShortcutCaptured(_ shortcut: KeyboardShortcut) {
    var config = preferencesStore.configuration
    config.activationShortcut = .customKeyCombo
    config.customActivationShortcut = shortcut
    preferencesStore.configuration = config
    reloadControls()
    onConfigurationChanged()
  }

  private func shortcutControls() -> NSView {
    let stack = NSStackView()
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(activationShortcutPopup)
    stack.addArrangedSubview(shortcutRecorderButton)

    activationShortcutPopup.widthAnchor.constraint(equalToConstant: 132).isActive = true
    shortcutRecorderButton.widthAnchor.constraint(equalToConstant: 128).isActive = true
    return stack
  }

  private func row(label: String, control: NSView, suffix: String? = nil) -> NSView {
    let labelField = NSTextField(labelWithString: label)
    labelField.translatesAutoresizingMaskIntoConstraints = false
    labelField.widthAnchor.constraint(equalToConstant: 150).isActive = true

    let row = NSStackView()
    row.translatesAutoresizingMaskIntoConstraints = false
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 10
    row.addArrangedSubview(labelField)

    control.translatesAutoresizingMaskIntoConstraints = false
    control.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
    row.addArrangedSubview(control)

    if let suffix {
      let suffixField = NSTextField(labelWithString: suffix)
      suffixField.textColor = .secondaryLabelColor
      row.addArrangedSubview(suffixField)
    }

    return row
  }

  private func positiveInt(from textField: NSTextField, fallback: Int) -> Int {
    max(1, Int(textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback)
  }
}

private final class ShortcutRecorderButton: NSButton {
  var shortcut: KeyboardShortcut? {
    didSet {
      updateTitle()
    }
  }
  var onShortcutCaptured: ((KeyboardShortcut) -> Void)?
  private var isRecording = false {
    didSet {
      updateTitle()
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    title = "点击录入"
    bezelStyle = .rounded
    target = self
    action = #selector(beginRecording)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  override func resignFirstResponder() -> Bool {
    isRecording = false
    return super.resignFirstResponder()
  }

  override func keyDown(with event: NSEvent) {
    guard isRecording else {
      super.keyDown(with: event)
      return
    }

    let modifiers = Self.commandModifiers(from: event)
    let shortcut = KeyboardShortcut(keyCode: event.keyCode, modifiers: modifiers)
    guard shortcut.isValid else {
      NSSound.beep()
      return
    }

    self.shortcut = shortcut
    isRecording = false
    onShortcutCaptured?(shortcut)
  }

  @objc private func beginRecording() {
    isRecording = true
    window?.makeFirstResponder(self)
  }

  private func updateTitle() {
    if isRecording {
      title = "按下快捷键"
    } else if let shortcut {
      title = Self.displayString(for: shortcut)
    } else {
      title = "点击录入"
    }
  }

  private static func commandModifiers(from event: NSEvent) -> Set<CommandModifier> {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    var modifiers: Set<CommandModifier> = []

    if flags.contains(.command) {
      modifiers.insert(.command)
    }
    if flags.contains(.shift) {
      modifiers.insert(.shift)
    }
    if flags.contains(.option) {
      modifiers.insert(.option)
    }
    if flags.contains(.control) {
      modifiers.insert(.control)
    }
    if flags.contains(.function) {
      modifiers.insert(.function)
    }

    return modifiers
  }

  private static func displayString(for shortcut: KeyboardShortcut) -> String {
    let orderedModifiers: [(CommandModifier, String)] = [
      (.control, "⌃"),
      (.option, "⌥"),
      (.shift, "⇧"),
      (.command, "⌘"),
      (.function, "fn"),
    ]
    let modifierText = orderedModifiers
      .filter { shortcut.modifiers.contains($0.0) }
      .map(\.1)
      .joined()

    return modifierText + keyName(for: shortcut.keyCode)
  }

  private static func keyName(for keyCode: UInt16) -> String {
    let names: [UInt16: String] = [
      0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
      11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
      18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
      31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
      36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
      123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
    return names[keyCode] ?? "Key \(keyCode)"
  }
}
