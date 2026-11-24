import AppKit
import ClipboardHistoryCore

enum PanelAppearance {
  case light, dark
}

struct PanelTheme {
  static let cobalt = NSColor(red: 0.24, green: 0.35, blue: 0.96, alpha: 1)
  let appearance: PanelAppearance
  let fill: NSColor
  let border: NSColor
  let text: NSColor
  let secondary: NSColor
  let separator: NSColor
  let paper = NSColor(white: 0.98, alpha: 1)
  let ink = NSColor(white: 0.12, alpha: 1)

  init(appearance: PanelAppearance) {
    self.appearance = appearance
    let dark = appearance == .dark
    fill = dark ? NSColor(red: 0.105, green: 0.113, blue: 0.129, alpha: 1) : NSColor(white: 0.94, alpha: 1)
    border = dark ? NSColor(white: 1, alpha: 0.13) : NSColor(white: 0, alpha: 0.12)
    text = dark ? NSColor(white: 0.95, alpha: 1) : NSColor(white: 0.12, alpha: 1)
    secondary = dark ? NSColor(white: 0.65, alpha: 1) : NSColor(white: 0.40, alpha: 1)
    separator = dark ? NSColor(white: 1, alpha: 0.14) : NSColor(white: 0, alpha: 0.12)
  }
}

@MainActor
enum ShelfDrawing {
  static func text(
    _ value: String, in rect: NSRect, font: NSFont, color: NSColor,
    alignment: NSTextAlignment = .left, wrap: Bool = false
  ) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = wrap ? .byWordWrapping : .byTruncatingTail
    paragraph.minimumLineHeight = font.pointSize + 4
    paragraph.maximumLineHeight = font.pointSize + 4
    (value as NSString).draw(
      with: rect,
      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
      attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    )
  }

  static func line(from start: NSPoint, to end: NSPoint, color: NSColor) {
    color.setStroke()
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = 0.5
    path.stroke()
  }

  static func symbol(_ name: String, in rect: NSRect, color: NSColor) {
    NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))?
      .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
  }

  static func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
  }
}

/// Native shell shared by horizontal and vertical shelves. Coordinates are top-down.
final class HistoryShelfView: NSView {
  let theme: PanelTheme
  let isHorizontal: Bool
  private let searchField: NSSearchField
  private let notesContainer: NSView
  private var filterButtons: [ShelfFilterButton] = []
  private let settingsButton = NSButton()
  private let selectionAction: ClipboardSelectionAction
  var onFilterChange: ((ClipboardItemKind?) -> Void)?
  var onOpenPreferences: (() -> Void)?
  var resultCount = 0 { didSet { needsDisplay = true } }
  var totalCount = 0 { didSet { needsDisplay = true } }
  var selectedIndex: Int? { didSet { needsDisplay = true } }
  var selectedKind: ClipboardItemKind? {
    didSet {
      for (index, button) in filterButtons.enumerated() {
        button.state = index == selectedFilterIndex ? .on : .off
        button.needsDisplay = true
      }
    }
  }

  init(
    frame: NSRect, theme: PanelTheme, isHorizontal: Bool,
    searchField: NSSearchField, notesContainer: NSView, selectionAction: ClipboardSelectionAction
  ) {
    self.theme = theme
    self.isHorizontal = isHorizontal
    self.searchField = searchField
    self.notesContainer = notesContainer
    self.selectionAction = selectionAction
    super.init(frame: frame)
    addSubview(searchField)
    addSubview(notesContainer)
    searchField.isBezeled = false
    searchField.drawsBackground = false
    searchField.focusRingType = .none
    searchField.font = .systemFont(ofSize: 12)
    searchField.textColor = theme.text
    searchField.sendsSearchStringImmediately = true
    searchField.setAccessibilityLabel("搜索剪贴板历史")
    (searchField.cell as? NSSearchFieldCell)?.placeholderAttributedString = NSAttributedString(
      string: "搜索历史", attributes: [.foregroundColor: theme.secondary, .font: NSFont.systemFont(ofSize: 12)]
    )
    for (index, title) in ["全部", "文本", "图片"].enumerated() {
      let button = ShelfFilterButton(title: title, target: self, action: #selector(changeFilter(_:)))
      button.theme = theme
      button.tag = index
      button.state = index == 0 ? .on : .off
      button.isBordered = false
      button.focusRingType = .none
      button.setAccessibilityLabel("筛选\(title)")
      filterButtons.append(button)
      addSubview(button)
    }
    settingsButton.isBordered = false
    settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "偏好设置")
    settingsButton.contentTintColor = theme.secondary
    settingsButton.target = self
    settingsButton.action = #selector(openPreferences)
    settingsButton.toolTip = "偏好设置"
    settingsButton.setAccessibilityLabel("偏好设置")
    addSubview(settingsButton)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override var isFlipped: Bool { true }

  private var selectedFilterIndex: Int {
    switch selectedKind {
    case .none: return 0
    case .text: return 1
    case .image: return 2
    }
  }

  override func layout() {
    super.layout()
    let w = bounds.width
    settingsButton.frame = NSRect(x: w - 48, y: 13, width: 26, height: 26)
    if isHorizontal {
      let compact = w < 760
      let filterX: CGFloat = compact ? 174 : 204
      for (index, button) in filterButtons.enumerated() {
        button.frame = NSRect(x: filterX + CGFloat(index) * 54, y: 10, width: 48, height: 36)
      }
      let searchWidth = min(220, max(110, w - filterX - 230))
      searchField.frame = NSRect(x: w - 62 - searchWidth, y: 16, width: searchWidth, height: 24)
      notesContainer.frame = NSRect(x: 18, y: 60, width: w - 36, height: bounds.height - 96)
    } else {
      searchField.frame = NSRect(x: 20, y: 51, width: w - 40, height: 26)
      for (index, button) in filterButtons.enumerated() {
        button.frame = NSRect(x: 16 + CGFloat(index) * 54, y: 83, width: 48, height: 34)
      }
      notesContainer.frame = NSRect(x: 18, y: 126, width: w - 36, height: bounds.height - 162)
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
    ShelfDrawing.roundedRect(rect, radius: 18, color: theme.fill)
    theme.border.setStroke()
    let outline = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
    outline.lineWidth = 0.7
    outline.stroke()

    // The small stacked-sheets mark is the only decorative brand element.
    let rear = NSBezierPath(roundedRect: NSRect(x: 27, y: 22, width: 13, height: 13), xRadius: 3, yRadius: 3)
    PanelTheme.cobalt.setStroke()
    rear.lineWidth = 1.3
    rear.stroke()
    ShelfDrawing.roundedRect(NSRect(x: 22, y: 17, width: 13, height: 13), radius: 3, color: PanelTheme.cobalt)
    ShelfDrawing.text("ClipStack", in: NSRect(x: 50, y: 17, width: 81, height: 22), font: .systemFont(ofSize: 14, weight: .semibold), color: theme.text)
    let count = "\(totalCount)"
    let countWidth = max(25, CGFloat(count.count) * 7 + 12)
    ShelfDrawing.roundedRect(NSRect(x: 138, y: 17, width: countWidth, height: 21), radius: 6, color: theme.separator.withAlphaComponent(0.08))
    ShelfDrawing.text(count, in: NSRect(x: 138, y: 20, width: countWidth, height: 17), font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium), color: theme.secondary, alignment: .center)

    let dividerY: CGFloat = isHorizontal ? 52 : 118
    ShelfDrawing.line(from: NSPoint(x: 20, y: dividerY), to: NSPoint(x: bounds.width - 20, y: dividerY), color: theme.separator)
    drawFooter()
  }

  private func drawFooter() {
    let y = bounds.height - 34
    ShelfDrawing.line(from: NSPoint(x: 20, y: y), to: NSPoint(x: bounds.width - 20, y: y), color: theme.separator)
    let position = selectedIndex.map { $0 + 1 } ?? 0
    let segmentCount = min(resultCount, 5)
    if isHorizontal && segmentCount > 0 {
      let active = min(segmentCount - 1, (selectedIndex ?? 0) * segmentCount / max(1, resultCount))
      for index in 0..<segmentCount {
        ShelfDrawing.roundedRect(
          NSRect(x: 22 + CGFloat(index) * 10, y: y + 15, width: 8, height: 3), radius: 1.5,
          color: index == active ? PanelTheme.cobalt : theme.secondary.withAlphaComponent(0.35)
        )
      }
    }
    let countX: CGFloat = isHorizontal ? 84 : 22
    ShelfDrawing.text("\(position) / \(resultCount)", in: NSRect(x: countX, y: y + 9, width: 82, height: 18), font: .monospacedDigitSystemFont(ofSize: 10, weight: .regular), color: theme.secondary)
    let action = selectionAction == .pasteToActiveApp ? "粘贴" : "复制"
    let hints = isHorizontal ? "← → 选择     ↵ \(action)     esc 关闭" : "↵ \(action)   esc 关闭"
    ShelfDrawing.text(hints, in: NSRect(x: bounds.width - (isHorizontal ? 264 : 173), y: y + 9, width: isHorizontal ? 242 : 151, height: 18), font: .systemFont(ofSize: 10), color: theme.secondary, alignment: .right)
  }

  @objc private func changeFilter(_ sender: NSButton) {
    selectedKind = [nil, ClipboardItemKind.text, ClipboardItemKind.image][sender.tag]
    onFilterChange?(selectedKind)
  }

  @objc private func openPreferences() { onOpenPreferences?() }
}

private final class ShelfFilterButton: NSButton {
  var theme = PanelTheme(appearance: .dark)
  override var isFlipped: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    let selected = state == .on
    ShelfDrawing.text(title, in: NSRect(x: 0, y: 8, width: bounds.width, height: 20), font: .systemFont(ofSize: 12, weight: selected ? .semibold : .regular), color: selected ? theme.text : theme.secondary, alignment: .center)
    if selected {
      ShelfDrawing.roundedRect(NSRect(x: bounds.midX - 12, y: bounds.height - 3, width: 24, height: 2), radius: 1, color: PanelTheme.cobalt)
    }
  }
}

final class EdgeScrollView: NSScrollView {
  enum Axis { case horizontal, vertical }
  private let axis: Axis

  init(axis: Axis) {
    self.axis = axis
    super.init(frame: .zero)
    usesPredominantAxisScrolling = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func scrollWheel(with event: NSEvent) {
    guard axis == .horizontal, let documentView else {
      super.scrollWheel(with: event)
      return
    }
    let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
    let maxX = max(0, documentView.bounds.width - contentView.bounds.width)
    var origin = contentView.bounds.origin
    origin.x = min(max(origin.x + delta, 0), maxX)
    contentView.scroll(to: origin)
    reflectScrolledClipView(contentView)
  }
}

final class HistoryNotesDocumentView: NSView {
  private let notes: [HistoryNoteView]
  private let isHorizontal: Bool
  private let theme: PanelTheme
  private let cardSize: NSSize
  private let spacing: CGFloat = 16

  init(notes: [HistoryNoteView], isHorizontal: Bool, viewportWidth: CGFloat, theme: PanelTheme) {
    self.notes = notes
    self.isHorizontal = isHorizontal
    self.theme = theme
    let visibleCards = max(1, min(5, floor((viewportWidth - 16) / 192)))
    let width = isHorizontal
      ? floor((viewportWidth - 16 - (visibleCards - 1) * 16) / visibleCards)
      : viewportWidth - 16
    cardSize = NSSize(width: max(160, width), height: 190)
    let count = CGFloat(notes.count)
    let length = count * (isHorizontal ? cardSize.width : cardSize.height) + max(0, count - 1) * 16 + 16
    super.init(frame: NSRect(x: 0, y: 0, width: isHorizontal ? length : viewportWidth, height: isHorizontal ? 206 : length))
    for note in notes { addSubview(note) }
    layoutNotes()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }
  override var isFlipped: Bool { true }

  override func layout() {
    super.layout()
    layoutNotes()
  }

  private func layoutNotes() {
    for (index, note) in notes.enumerated() {
      let offset = 8 + CGFloat(index) * ((isHorizontal ? cardSize.width : cardSize.height) + spacing)
      note.frame = NSRect(x: isHorizontal ? offset : 8, y: isHorizontal ? 8 : offset, width: cardSize.width, height: cardSize.height)
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    for note in notes.dropLast() {
      if isHorizontal {
        let x = note.frame.maxX + spacing / 2
        ShelfDrawing.line(from: NSPoint(x: x, y: 18), to: NSPoint(x: x, y: bounds.height - 18), color: theme.separator)
      } else {
        let y = note.frame.maxY + spacing / 2
        ShelfDrawing.line(from: NSPoint(x: 16, y: y), to: NSPoint(x: bounds.width - 16, y: y), color: theme.separator)
      }
    }
  }
}
