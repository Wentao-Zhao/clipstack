import AppKit
import ClipboardHistoryCore

/// Selection changes the surface and colors while preserving the item's geometry.
final class HistoryNoteView: NSControl {
  var isSelected: Bool {
    didSet {
      guard oldValue != isSelected else { return }
      needsDisplay = true
      updatePinButtonVisibility()
      setAccessibilityValue(isSelected ? "已选择" : "")
    }
  }

  private let item: ClipboardHistoryItem
  private let index: Int
  private let theme: PanelTheme
  private let presentation: ClipboardContentPresentation
  private let thumbnail: NSImage?
  private let onSelect: (ClipboardHistoryItem) -> Void
  private let onActivate: (ClipboardHistoryItem) -> Void
  private let onPin: ((ClipboardHistoryItem) -> Void)?
  private let selectionAction: ClipboardSelectionAction
  private let pinButton = NSButton()
  private var pointerState = ClipboardNotePointerState()
  private var isHovered = false
  private var isPressed = false
  private let timeText: String
  private let sizeText: String

  init(
    item: ClipboardHistoryItem, index: Int, thumbnailURL: URL?, theme: PanelTheme,
    isSelected: Bool, selectionAction: ClipboardSelectionAction,
    onSelect: @escaping (ClipboardHistoryItem) -> Void,
    onActivate: @escaping (ClipboardHistoryItem) -> Void,
    onPin: ((ClipboardHistoryItem) -> Void)?
  ) {
    self.item = item
    self.index = index
    self.theme = theme
    self.isSelected = isSelected
    self.selectionAction = selectionAction
    self.onSelect = onSelect
    self.onActivate = onActivate
    self.onPin = onPin
    presentation = ClipboardContentPresentation(item: item)
    thumbnail = thumbnailURL.flatMap(NSImage.init(contentsOf:))
    let relativeFormatter = RelativeDateTimeFormatter()
    relativeFormatter.locale = Locale(identifier: "zh_CN")
    relativeFormatter.unitsStyle = .short
    timeText = relativeFormatter.localizedString(for: item.lastUsedAt, relativeTo: Date())
    let sizeFormatter = ByteCountFormatter()
    sizeFormatter.countStyle = .file
    sizeText = sizeFormatter.string(fromByteCount: Int64(item.byteSize))
    super.init(frame: .zero)
    focusRingType = .none
    setAccessibilityElement(true)
    setAccessibilityRole(.button)
    let accessibleContent = presentation.kind == .code
      ? presentation.body
      : presentation.title + (presentation.body.isEmpty ? "" : "\n" + presentation.body)
    setAccessibilityLabel("\(presentation.badge)，\(accessibleContent.prefix(500))，\(timeText)")
    setAccessibilityValue(isSelected ? "已选择" : "")
    setAccessibilityHelp(selectionAction == .pasteToActiveApp ? "激活以粘贴到之前的 App" : "激活以复制到剪贴板")
    pinButton.isBordered = false
    pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "置顶图片")
    pinButton.target = self
    pinButton.action = #selector(pinImage)
    pinButton.toolTip = "置顶图片"
    pinButton.setAccessibilityLabel("置顶这张图片")
    addSubview(pinButton)
    updatePinButtonVisibility()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override var isFlipped: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func accessibilityPerformPress() -> Bool {
    onSelect(item)
    onActivate(item)
    return true
  }

  override func layout() {
    super.layout()
    pinButton.frame = NSRect(x: bounds.width - 33, y: 15, width: 24, height: 24)
  }

  override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil))
  }

  override func mouseEntered(with event: NSEvent) {
    isHovered = true
    onSelect(item)
    updatePinButtonVisibility()
  }

  override func mouseExited(with event: NSEvent) {
    isHovered = false
    updatePinButtonVisibility()
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let onPinButton = isPinButtonPoint(point)
    _ = pointerState.pointerDown(onPinButton: onPinButton)
    guard !onPinButton else { return }
    onSelect(item)
    isPressed = true
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let action = pointerState.pointerUp(insideNote: bounds.contains(point), onPinButton: isPinButtonPoint(point))
    isPressed = false
    needsDisplay = true
    switch action {
    case .none: break
    case .activate: onActivate(item)
    case .pin: pinImage()
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    let w = bounds.width
    let h = bounds.height
    let primary = isSelected ? theme.ink : theme.text
    let secondary = isSelected ? NSColor(white: 0.40, alpha: 1) : theme.secondary
    if isSelected {
      ShelfDrawing.roundedRect(NSRect(x: 1, y: 9, width: w - 2, height: h - 13), radius: 9, color: isPressed ? NSColor(white: 0.92, alpha: 1) : theme.paper)
      if theme.appearance == .light {
        theme.border.setStroke()
        let outline = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 9.5, width: w - 3, height: h - 14), xRadius: 9, yRadius: 9)
        outline.lineWidth = 0.5
        outline.stroke()
      }
      ShelfDrawing.roundedRect(NSRect(x: 1, y: 23, width: 3, height: 17), radius: 1, color: PanelTheme.cobalt)
      ShelfDrawing.roundedRect(NSRect(x: w - 34, y: h - 32, width: 23, height: 21), radius: 6, color: PanelTheme.cobalt)
      ShelfDrawing.symbol(selectionAction == .pasteToActiveApp ? "return" : "doc.on.doc", in: NSRect(x: w - 29, y: h - 28, width: 13, height: 13), color: .white)
    }

    ShelfDrawing.text(String(format: "%02d", index + 1), in: NSRect(x: 14, y: 20, width: 28, height: 17), font: .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium), color: secondary)
    if !isSelected || item.kind != .image {
      ShelfDrawing.symbol(symbolName, in: NSRect(x: 45, y: 21, width: 13, height: 13), color: secondary)
      ShelfDrawing.text(timeText, in: NSRect(x: 64, y: 20, width: w - 78, height: 17), font: .systemFont(ofSize: 10), color: secondary, alignment: .right)
    }

    switch presentation.kind {
    case .image: drawImage(primary: primary, secondary: secondary)
    case .text: drawText(primary: primary, secondary: secondary)
    case .link: drawLink(primary: primary, secondary: secondary)
    case .code: drawCode(primary: primary, secondary: secondary)
    }
  }

  private var symbolName: String {
    switch presentation.kind {
    case .image: return "photo"
    case .text: return "quote.opening"
    case .link: return "link"
    case .code: return "chevron.left.forwardslash.chevron.right"
    }
  }

  private func drawImage(primary: NSColor, secondary: NSColor) {
    let rect = NSRect(x: 12, y: 48, width: bounds.width - 24, height: 98)
    let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
    (isSelected ? NSColor(white: 0.90, alpha: 1) : theme.separator.withAlphaComponent(0.06)).setFill()
    path.fill()
    if let thumbnail, thumbnail.size.width > 0, thumbnail.size.height > 0 {
      // Aspect-fit, rather than cropping away potentially important screenshot content.
      let scale = min(rect.width / thumbnail.size.width, rect.height / thumbnail.size.height)
      let size = NSSize(width: thumbnail.size.width * scale, height: thumbnail.size.height * scale)
      let destination = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
      NSGraphicsContext.saveGraphicsState()
      path.addClip()
      thumbnail.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
      NSGraphicsContext.restoreGraphicsState()
    } else {
      ShelfDrawing.symbol("photo", in: NSRect(x: rect.midX - 13, y: rect.midY - 13, width: 26, height: 26), color: secondary)
    }
    ShelfDrawing.text("截图", in: NSRect(x: 14, y: 154, width: 40, height: 18), font: .systemFont(ofSize: 11, weight: .medium), color: primary)
    if isSelected {
      ShelfDrawing.text(timeText, in: NSRect(x: 58, y: 155, width: bounds.width - 100, height: 17), font: .systemFont(ofSize: 10), color: secondary)
    }
    drawSize(secondary: secondary, y: isSelected ? 172 : 155, alignment: isSelected ? .left : .right)
  }

  private func drawText(primary: NSColor, secondary: NSColor) {
    let width = bounds.width - 28
    ShelfDrawing.text("“", in: NSRect(x: 10, y: 40, width: 40, height: 48), font: .systemFont(ofSize: 42, weight: .bold), color: primary.withAlphaComponent(0.13))
    let titleRect = NSRect(x: 18, y: 62, width: width - 4, height: presentation.body.isEmpty ? 83 : 37)
    ShelfDrawing.text(presentation.title, in: titleRect, font: .systemFont(ofSize: 13, weight: .semibold), color: primary, wrap: true)
    if !presentation.body.isEmpty {
      ShelfDrawing.text(presentation.body, in: NSRect(x: 18, y: 104, width: width - 4, height: 45), font: .systemFont(ofSize: 11.5), color: secondary, wrap: true)
    }
    ShelfDrawing.line(from: NSPoint(x: 14, y: 158), to: NSPoint(x: bounds.width - 14, y: 158), color: primary.withAlphaComponent(0.12))
    drawSize(secondary: secondary)
  }

  private func drawLink(primary: NSColor, secondary: NSColor) {
    ShelfDrawing.roundedRect(NSRect(x: 14, y: 55, width: 27, height: 29), radius: 6, color: isSelected ? NSColor(white: 0.90, alpha: 1) : NSColor(white: 0.96, alpha: 1))
    ShelfDrawing.symbol("doc.text", in: NSRect(x: 20, y: 61, width: 15, height: 17), color: theme.ink)
    ShelfDrawing.text("网页链接", in: NSRect(x: 50, y: 61, width: bounds.width - 70, height: 20), font: .systemFont(ofSize: 12, weight: .medium), color: primary)
    ShelfDrawing.text(presentation.title, in: NSRect(x: 14, y: 96, width: bounds.width - 28, height: 19), font: .systemFont(ofSize: 12, weight: .medium), color: primary)
    ShelfDrawing.text(presentation.body, in: NSRect(x: 14, y: 119, width: bounds.width - 28, height: 32), font: .systemFont(ofSize: 11), color: secondary, wrap: true)
    let badgeRect = NSRect(x: 14, y: 166, width: 43, height: 15)
    secondary.withAlphaComponent(0.4).setStroke()
    let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4)
    badge.lineWidth = 0.5
    badge.stroke()
    ShelfDrawing.text(presentation.badge, in: badgeRect.offsetBy(dx: 0, dy: 1), font: .systemFont(ofSize: 9), color: secondary, alignment: .center)
    drawSize(secondary: secondary)
  }

  private func drawCode(primary: NSColor, secondary: NSColor) {
    let lines = presentation.body.components(separatedBy: .newlines)
    let visible = Array(lines.prefix(6))
    ShelfDrawing.line(from: NSPoint(x: 33, y: 54), to: NSPoint(x: 33, y: 54 + CGFloat(visible.count) * 16), color: primary.withAlphaComponent(0.13))
    for (index, line) in visible.enumerated() {
      let y = 54 + CGFloat(index) * 16
      ShelfDrawing.text("\(index + 1)", in: NSRect(x: 8, y: y + 1, width: 17, height: 16), font: .monospacedSystemFont(ofSize: 9, weight: .regular), color: secondary, alignment: .right)
      ShelfDrawing.text(line.isEmpty ? " " : line, in: NSRect(x: 42, y: y, width: bounds.width - 54, height: 17), font: .monospacedSystemFont(ofSize: 11, weight: .regular), color: primary)
    }
    ShelfDrawing.text(presentation.badge, in: NSRect(x: 14, y: 168, width: 44, height: 17), font: .systemFont(ofSize: 9, weight: .medium), color: secondary)
    drawSize(secondary: secondary)
  }

  private func drawSize(secondary: NSColor, y: CGFloat = 168, alignment: NSTextAlignment = .right) {
    let x: CGFloat = alignment == .left ? 14 : 62
    let reserved: CGFloat = isSelected && alignment == .right ? 40 : 14
    ShelfDrawing.text(sizeText, in: NSRect(x: x, y: y, width: bounds.width - x - reserved, height: 16), font: .monospacedDigitSystemFont(ofSize: 9.5, weight: .regular), color: secondary, alignment: alignment)
  }

  private func updatePinButtonVisibility() {
    pinButton.isHidden = onPin == nil || !(isSelected || isHovered)
    pinButton.contentTintColor = isSelected ? theme.ink : theme.text
  }

  private func isPinButtonPoint(_ point: NSPoint) -> Bool {
    onPin != nil && !pinButton.isHidden && pinButton.frame.contains(point)
  }

  @objc private func pinImage() {
    pointerState.pinButtonActionPerformed()
    onSelect(item)
    onPin?(item)
  }
}
