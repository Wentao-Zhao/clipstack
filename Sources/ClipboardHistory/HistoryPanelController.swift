import AppKit
import ClipboardHistoryCore
import QuartzCore

@MainActor
final class HistoryPanelController: NSObject, NSSearchFieldDelegate {
  private let store: ClipboardHistoryStore
  private let configurationProvider: () -> ClipboardConfiguration
  private let onSelect: (ClipboardHistoryItem, NSRunningApplication?) -> Void
  private let onPinImage: (ClipboardHistoryItem, PinnedImageStyle) -> Void
  private var targetApplication: NSRunningApplication?
  private var panel: HistoryPanel?
  private var allRows: [ClipboardHistoryItem] = []
  private var rows: [ClipboardHistoryItem] = []
  private var searchQuery = ""
  private var focusState = HistoryPanelFocusState()
  private var selectionState = ClipboardHistorySelectionState(itemCount: 0)
  private var noteViews: [StickyNoteView] = []
  private weak var activeSearchField: HistorySearchField?
  private weak var notesFocusView: HistoryNotesFocusView?
  private var activePanelEdge: ClipboardPanelEdge = .bottom
  private var activePanelAppearance: PanelAppearance = .light

  init(
    store: ClipboardHistoryStore,
    configurationProvider: @escaping () -> ClipboardConfiguration,
    onSelect: @escaping (ClipboardHistoryItem, NSRunningApplication?) -> Void,
    onPinImage: @escaping (ClipboardHistoryItem, PinnedImageStyle) -> Void
  ) {
    self.store = store
    self.configurationProvider = configurationProvider
    self.onSelect = onSelect
    self.onPinImage = onPinImage
    super.init()
  }

  func show() {
    allRows = store.items
    searchQuery = ""
    focusState = HistoryPanelFocusState()
    rows = ClipboardSearchFilter.filteredItems(query: searchQuery, items: allRows)
    selectionState = ClipboardHistorySelectionState(itemCount: rows.count)
    targetApplication = frontmostTargetApplication()

    let config = configurationProvider()
    let edge = config.panelEdge
    let appearance = resolvedAppearance(for: config.panelAppearance)
    let panel = ensurePanel()
    panel.appearance = NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
    panel.setFrame(panelFrame(for: edge), display: false)
    rebuildContent(in: panel, edge: edge, appearance: appearance)

    panel.onDefaultAction = { [weak self] in
      self?.activateSelectedItem()
    }
    panel.onMoveSelection = { [weak self] step in
      self?.moveSelection(by: step)
    }

    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    focusNotes()
  }

  func close() {
    panel?.orderOut(nil)
  }

  private func ensurePanel() -> HistoryPanel {
    if let panel {
      return panel
    }

    let panel = HistoryPanel(
      contentRect: NSRect(x: 0, y: 0, width: 960, height: 214),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.isReleasedWhenClosed = false
    panel.onEscape = { [weak self] in self?.close() }

    self.panel = panel
    return panel
  }

  private func rebuildContent(in panel: NSPanel, edge: ClipboardPanelEdge, appearance: PanelAppearance) {
    let config = configurationProvider()
    let theme = PanelTheme(appearance: appearance)
    let root = GlassShelfView(frame: NSRect(origin: .zero, size: panel.frame.size), theme: theme)
    root.autoresizingMask = [.width, .height]
    panel.contentView = root
    activePanelEdge = edge
    activePanelAppearance = appearance

    let titleField = NSTextField(labelWithString: "ClipStack")
    titleField.translatesAutoresizingMaskIntoConstraints = false
    titleField.font = .systemFont(ofSize: 15, weight: .semibold)
    titleField.textColor = theme.titleText

    let subtitleText = config.selectionAction == .pasteToActiveApp
      ? "点击便签自动粘贴到当前 App"
      : "点击便签复制到系统剪贴板"
    let subtitleField = NSTextField(labelWithString: subtitleText)
    subtitleField.translatesAutoresizingMaskIntoConstraints = false
    subtitleField.font = .systemFont(ofSize: 12, weight: .regular)
    subtitleField.textColor = theme.subtitleText

    root.addSubview(titleField)
    root.addSubview(subtitleField)

    let searchField = HistorySearchField()
    searchField.translatesAutoresizingMaskIntoConstraints = false
    searchField.placeholderString = "搜索历史"
    searchField.stringValue = searchQuery
    searchField.font = .systemFont(ofSize: 12)
    searchField.delegate = self
    searchField.onDefaultAction = { [weak self] in self?.activateSelectedItem() }
    searchField.onFocusNotes = { [weak self] in self?.focusNotes() }
    searchField.onEscape = { [weak self] in
      guard let self else {
        return
      }
      if self.searchQuery.isEmpty {
        self.close()
      } else {
        self.updateSearchQuery("")
      }
    }
    activeSearchField = searchField
    root.addSubview(searchField)

    let notesContainer = HistoryNotesFocusView()
    notesContainer.translatesAutoresizingMaskIntoConstraints = false
    notesContainer.onDefaultAction = { [weak self] in self?.activateSelectedItem() }
    notesContainer.onMoveSelection = { [weak self] step in self?.moveSelection(by: step) }
    notesContainer.onFocusSearch = { [weak self] in self?.focusSearch() }
    notesContainer.onBeginSearch = { [weak self] event in
      self?.beginSearch(with: event)
    }
    notesContainer.onEscape = { [weak self] in self?.close() }
    notesFocusView = notesContainer
    root.addSubview(notesContainer)

    NSLayoutConstraint.activate([
      titleField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
      titleField.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
      searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
      searchField.centerYAnchor.constraint(equalTo: titleField.centerYAnchor),
      searchField.widthAnchor.constraint(equalToConstant: edge.isHorizontal ? 220 : 146),
      titleField.trailingAnchor.constraint(lessThanOrEqualTo: searchField.leadingAnchor, constant: -12),
      subtitleField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
      subtitleField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 2),
      subtitleField.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -24),
      notesContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
      notesContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
      notesContainer.topAnchor.constraint(equalTo: subtitleField.bottomAnchor, constant: 10),
      notesContainer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),
    ])

    rebuildNotes(in: notesContainer, edge: edge, theme: theme)
  }

  private func rebuildNotes(in container: NSView, edge: ClipboardPanelEdge, theme: PanelTheme) {
    container.subviews.forEach { $0.removeFromSuperview() }

    guard !rows.isEmpty else {
      noteViews = []
      let emptyMessage = allRows.isEmpty ? "暂无剪贴板历史" : "没有匹配的历史"
      let emptyField = NSTextField(labelWithString: emptyMessage)
      emptyField.translatesAutoresizingMaskIntoConstraints = false
      emptyField.font = .systemFont(ofSize: 15, weight: .medium)
      emptyField.textColor = theme.subtitleText
      container.addSubview(emptyField)

      NSLayoutConstraint.activate([
        emptyField.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        emptyField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      ])
      return
    }

    let notes = rows.enumerated().map { index, item in
      let noteStyle = theme.noteStyles[index % theme.noteStyles.count]

      return StickyNoteView(
        item: item,
        thumbnailURL: store.thumbnailURL(for: item),
        style: noteStyle,
        isSelected: selectionState.selectedIndex == index,
        onSelect: { [weak self] selectedItem in
          self?.select(selectedItem)
        },
        onActivate: { [weak self] selectedItem in
          self?.activate(selectedItem)
        },
        onPin: item.kind == .image ? { [weak self] selectedItem in
          self?.onPinImage(
            selectedItem,
            PinnedImageStyle(
              background: noteStyle.background,
              accent: noteStyle.accent,
              border: noteStyle.border
            )
          )
        } : nil
      )
    }

    let scrollView = EdgeScrollView(axis: edge.isHorizontal ? .horizontal : .vertical)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.scrollerStyle = .overlay
    scrollView.hasHorizontalScroller = edge.isHorizontal
    scrollView.hasVerticalScroller = !edge.isHorizontal
    scrollView.autohidesScrollers = true
    scrollView.documentView = StickyNotesDocumentView(notes: notes, isHorizontal: edge.isHorizontal)
    noteViews = notes
    updateSelectionViews(scrollIntoView: false)

    container.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: container.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  private func panelFrame(for edge: ClipboardPanelEdge) -> NSRect {
    let screen = screenForPanel()
    let visibleFrame = screen.visibleFrame
    let margin: CGFloat = 26

    if edge.isHorizontal {
      let width = min(visibleFrame.width - margin * 2, 1120)
      let height: CGFloat = 214
      let x = visibleFrame.midX - width / 2
      let y: CGFloat

      switch edge {
      case .top:
        y = visibleFrame.maxY - height - margin
      case .bottom:
        y = visibleFrame.minY + margin
      case .left, .right:
        y = visibleFrame.minY + margin
      }

      return NSRect(x: x, y: y, width: width, height: height)
    }

    let width: CGFloat = 286
    let height = min(visibleFrame.height - margin * 2, 680)
    let x = edge == .left ? visibleFrame.minX + margin : visibleFrame.maxX - width - margin
    let y = visibleFrame.midY - height / 2

    return NSRect(x: x, y: y, width: width, height: height)
  }

  private func screenForPanel() -> NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
      ?? NSScreen()
  }

  private func resolvedAppearance(for appearance: ClipboardPanelAppearance) -> PanelAppearance {
    switch appearance {
    case .light:
      return .light
    case .dark:
      return .dark
    case .system:
      let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
      return bestMatch == .darkAqua ? .dark : .light
    }
  }

  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? HistorySearchField, field === activeSearchField else {
      return
    }

    updateSearchQuery(field.stringValue)
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    guard control === activeSearchField else {
      return false
    }

    switch commandSelector {
    case #selector(NSResponder.moveDown(_:)):
      focusNotes()
      return true
    case #selector(NSResponder.insertNewline(_:)):
      activateSelectedItem()
      return true
    case #selector(NSResponder.cancelOperation(_:)):
      if searchQuery.isEmpty {
        close()
      } else {
        updateSearchQuery("")
      }
      return true
    default:
      return false
    }
  }

  private func updateSearchQuery(_ query: String) {
    guard searchQuery != query else {
      return
    }

    searchQuery = query
    focusState.searchQueryDidChange(query)
    rows = ClipboardSearchFilter.filteredItems(query: searchQuery, items: allRows)
    selectionState = ClipboardHistorySelectionState(itemCount: rows.count)

    if activeSearchField?.stringValue != query {
      activeSearchField?.stringValue = query
    }

    guard let notesFocusView else {
      return
    }

    rebuildNotes(
      in: notesFocusView,
      edge: activePanelEdge,
      theme: PanelTheme(appearance: activePanelAppearance)
    )

    if focusState.target == .notes {
      focusNotes()
    }
  }

  private func focusSearch() {
    guard let activeSearchField else {
      return
    }

    focusState.focusSearch()
    panel?.makeFirstResponder(activeSearchField)
  }

  private func focusNotes() {
    guard let notesFocusView else {
      return
    }

    focusState.focusNotes()
    panel?.makeFirstResponder(notesFocusView)
  }

  private func beginSearch(with event: NSEvent) {
    guard let activeSearchField else {
      return
    }

    focusState.beginSearchInput()
    panel?.makeFirstResponder(activeSearchField)

    if let editor = activeSearchField.currentEditor() {
      editor.keyDown(with: event)
    } else {
      activeSearchField.keyDown(with: event)
    }
  }

  private func activateSelectedItem() {
    guard
      let selectedIndex = selectionState.selectedIndex,
      rows.indices.contains(selectedIndex)
    else {
      return
    }

    activate(rows[selectedIndex])
  }

  private func moveSelection(by step: Int) {
    guard step != 0 else {
      return
    }

    if step > 0 {
      selectionState.moveForward()
    } else {
      selectionState.moveBackward()
    }

    updateSelectionViews(scrollIntoView: true)
  }

  private func select(_ item: ClipboardHistoryItem) {
    guard let index = rows.firstIndex(where: { $0.id == item.id }) else {
      return
    }

    selectionState.select(index)
    updateSelectionViews(scrollIntoView: false)
  }

  private func updateSelectionViews(scrollIntoView: Bool) {
    for (index, noteView) in noteViews.enumerated() {
      noteView.isSelected = selectionState.selectedIndex == index
    }

    guard
      scrollIntoView,
      let selectedIndex = selectionState.selectedIndex,
      noteViews.indices.contains(selectedIndex)
    else {
      return
    }

    noteViews[selectedIndex].scrollToVisible(noteViews[selectedIndex].bounds.insetBy(dx: -18, dy: -18))
  }

  private func activate(_ item: ClipboardHistoryItem) {
    close()
    onSelect(item, targetApplication)
  }

  private func frontmostTargetApplication() -> NSRunningApplication? {
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let app = NSWorkspace.shared.frontmostApplication
    return app?.processIdentifier == currentPID ? nil : app
  }
}

private final class HistoryPanel: NSPanel {
  var onEscape: (() -> Void)?
  var onDefaultAction: (() -> Void)?
  var onMoveSelection: ((Int) -> Void)?

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 36, 76:
      onDefaultAction?()
    case 123, 126:
      onMoveSelection?(-1)
    case 124, 125:
      onMoveSelection?(1)
    case 53:
      onEscape?()
    default:
      super.keyDown(with: event)
    }
  }
}

private final class HistorySearchField: NSSearchField {
  var onEscape: (() -> Void)?
  var onDefaultAction: (() -> Void)?
  var onFocusNotes: (() -> Void)?

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 36, 76:
      onDefaultAction?()
    case 125:
      onFocusNotes?()
    case 53:
      onEscape?()
    default:
      super.keyDown(with: event)
    }
  }
}

private final class HistoryNotesFocusView: NSView {
  var onEscape: (() -> Void)?
  var onDefaultAction: (() -> Void)?
  var onMoveSelection: ((Int) -> Void)?
  var onFocusSearch: (() -> Void)?
  var onBeginSearch: ((NSEvent) -> Void)?

  override var acceptsFirstResponder: Bool {
    true
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 36, 76:
      onDefaultAction?()
    case 123:
      onMoveSelection?(-1)
    case 124, 125:
      onMoveSelection?(1)
    case 126:
      onFocusSearch?()
    case 53:
      onEscape?()
    default:
      if HistorySearchInputRouting.shouldBeginSearch(
        characters: event.characters,
        keyCode: event.keyCode,
        modifiers: Self.commandModifiers(from: event)
      ) {
        onBeginSearch?(event)
      } else {
        super.keyDown(with: event)
      }
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
}

private enum PanelAppearance {
  case light
  case dark
}

private struct PanelTheme {
  let appearance: PanelAppearance
  let shelfFill: NSColor
  let shelfShadow: NSColor
  let shelfBorderColors: [CGColor]
  let titleText: NSColor
  let subtitleText: NSColor
  let noteStyles: [StickyNoteStyle]

  init(appearance: PanelAppearance) {
    self.appearance = appearance

    switch appearance {
    case .light:
      shelfFill = NSColor.white.withAlphaComponent(0.88)
      shelfShadow = NSColor.black.withAlphaComponent(0.10)
      shelfBorderColors = [
        CGColor(red: 0.78, green: 0.64, blue: 0.67, alpha: 0.34),
        CGColor(red: 0.68, green: 0.75, blue: 0.64, alpha: 0.34),
        CGColor(red: 0.62, green: 0.71, blue: 0.79, alpha: 0.34),
        CGColor(red: 0.83, green: 0.74, blue: 0.60, alpha: 0.34),
      ]
      titleText = NSColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 0.96)
      subtitleText = NSColor(red: 0.34, green: 0.36, blue: 0.40, alpha: 0.76)
      noteStyles = StickyNoteStyle.lightPalette

    case .dark:
      shelfFill = NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 0.92)
      shelfShadow = NSColor.black.withAlphaComponent(0.26)
      shelfBorderColors = [
        CGColor(red: 0.72, green: 0.54, blue: 0.60, alpha: 0.42),
        CGColor(red: 0.55, green: 0.66, blue: 0.54, alpha: 0.42),
        CGColor(red: 0.47, green: 0.58, blue: 0.70, alpha: 0.42),
        CGColor(red: 0.73, green: 0.63, blue: 0.46, alpha: 0.42),
      ]
      titleText = NSColor.white.withAlphaComponent(0.92)
      subtitleText = NSColor.white.withAlphaComponent(0.64)
      noteStyles = StickyNoteStyle.darkPalette
    }
  }
}

private final class GlassShelfView: NSView {
  private let theme: PanelTheme

  init(frame frameRect: NSRect, theme: PanelTheme) {
    self.theme = theme
    super.init(frame: frameRect)
    wantsLayer = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var isOpaque: Bool {
    false
  }

  override func draw(_ dirtyRect: NSRect) {
    let rect = bounds.insetBy(dx: 2, dy: 2)
    let radius = min(CGFloat(32), min(rect.width, rect.height) / 2)
    let fillPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let shadow = NSShadow()
    shadow.shadowColor = theme.shelfShadow
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -4)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    theme.shelfFill.setFill()
    fillPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    guard
      let context = NSGraphicsContext.current?.cgContext,
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: theme.shelfBorderColors as CFArray,
        locations: [0, 0.36, 0.72, 1]
      )
    else {
      return
    }

    context.saveGState()
    let strokePath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(strokePath)
    context.setLineWidth(1.2)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
      gradient,
      start: CGPoint(x: rect.minX, y: rect.minY),
      end: CGPoint(x: rect.maxX, y: rect.maxY),
      options: []
    )
    context.restoreGState()
  }
}

private final class EdgeScrollView: NSScrollView {
  enum Axis {
    case horizontal
    case vertical
  }

  private let axis: Axis

  init(axis: Axis) {
    self.axis = axis
    super.init(frame: .zero)
    usesPredominantAxisScrolling = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func scrollWheel(with event: NSEvent) {
    guard axis == .horizontal, let documentView else {
      super.scrollWheel(with: event)
      return
    }

    let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
      ? event.scrollingDeltaX
      : event.scrollingDeltaY
    guard delta != 0 else {
      super.scrollWheel(with: event)
      return
    }

    let maxX = max(0, documentView.bounds.width - contentView.bounds.width)
    var origin = contentView.bounds.origin
    origin.x = min(max(origin.x + delta, 0), maxX)
    contentView.scroll(to: origin)
    reflectScrolledClipView(contentView)
  }
}

private final class StickyNotesDocumentView: NSView {
  private static let spacing: CGFloat = 14
  private static let padding: CGFloat = 8

  private let notes: [StickyNoteView]
  private let isHorizontal: Bool
  private let cardSize: NSSize

  init(notes: [StickyNoteView], isHorizontal: Bool) {
    self.notes = notes
    self.isHorizontal = isHorizontal
    self.cardSize = isHorizontal
      ? NSSize(width: 224, height: 104)
      : NSSize(width: 218, height: 118)

    let count = CGFloat(notes.count)
    let gap = max(0, count - 1) * Self.spacing
    let size = isHorizontal
      ? NSSize(width: count * cardSize.width + gap + Self.padding * 2, height: cardSize.height + Self.padding * 2)
      : NSSize(width: cardSize.width + Self.padding * 2, height: count * cardSize.height + gap + Self.padding * 2)

    super.init(frame: NSRect(origin: .zero, size: size))

    for note in notes {
      note.frame.size = cardSize
      addSubview(note)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var isFlipped: Bool {
    true
  }

  override func layout() {
    super.layout()

    var offset = Self.padding
    for note in notes {
      if isHorizontal {
        note.frame = NSRect(x: offset, y: Self.padding, width: cardSize.width, height: cardSize.height)
        offset += cardSize.width + Self.spacing
      } else {
        note.frame = NSRect(x: Self.padding, y: offset, width: cardSize.width, height: cardSize.height)
        offset += cardSize.height + Self.spacing
      }
    }
  }
}

private struct StickyNoteStyle {
  let background: NSColor
  let accent: NSColor
  let titleText: NSColor
  let metaText: NSColor
  let previewText: NSColor
  let thumbnailBackground: NSColor
  let border: NSColor

  static let lightPalette: [StickyNoteStyle] = [
    StickyNoteStyle.light(background: NSColor(red: 0.82, green: 0.70, blue: 0.72, alpha: 0.74), accent: NSColor(red: 0.75, green: 0.54, blue: 0.59, alpha: 1)),
    StickyNoteStyle.light(background: NSColor(red: 0.70, green: 0.78, blue: 0.68, alpha: 0.74), accent: NSColor(red: 0.55, green: 0.67, blue: 0.52, alpha: 1)),
    StickyNoteStyle.light(background: NSColor(red: 0.68, green: 0.75, blue: 0.82, alpha: 0.74), accent: NSColor(red: 0.50, green: 0.62, blue: 0.72, alpha: 1)),
    StickyNoteStyle.light(background: NSColor(red: 0.84, green: 0.76, blue: 0.64, alpha: 0.74), accent: NSColor(red: 0.74, green: 0.63, blue: 0.45, alpha: 1)),
    StickyNoteStyle.light(background: NSColor(red: 0.75, green: 0.70, blue: 0.82, alpha: 0.74), accent: NSColor(red: 0.61, green: 0.55, blue: 0.72, alpha: 1)),
    StickyNoteStyle.light(background: NSColor(red: 0.82, green: 0.72, blue: 0.66, alpha: 0.74), accent: NSColor(red: 0.70, green: 0.56, blue: 0.48, alpha: 1)),
  ]

  static let darkPalette: [StickyNoteStyle] = [
    StickyNoteStyle.dark(background: NSColor(red: 0.42, green: 0.29, blue: 0.33, alpha: 0.80), accent: NSColor(red: 0.76, green: 0.54, blue: 0.61, alpha: 1)),
    StickyNoteStyle.dark(background: NSColor(red: 0.29, green: 0.38, blue: 0.31, alpha: 0.80), accent: NSColor(red: 0.56, green: 0.68, blue: 0.54, alpha: 1)),
    StickyNoteStyle.dark(background: NSColor(red: 0.28, green: 0.36, blue: 0.45, alpha: 0.80), accent: NSColor(red: 0.54, green: 0.66, blue: 0.78, alpha: 1)),
    StickyNoteStyle.dark(background: NSColor(red: 0.44, green: 0.36, blue: 0.25, alpha: 0.80), accent: NSColor(red: 0.78, green: 0.65, blue: 0.45, alpha: 1)),
    StickyNoteStyle.dark(background: NSColor(red: 0.36, green: 0.31, blue: 0.46, alpha: 0.80), accent: NSColor(red: 0.66, green: 0.58, blue: 0.78, alpha: 1)),
    StickyNoteStyle.dark(background: NSColor(red: 0.42, green: 0.32, blue: 0.27, alpha: 0.80), accent: NSColor(red: 0.72, green: 0.58, blue: 0.50, alpha: 1)),
  ]

  private static func light(background: NSColor, accent: NSColor) -> StickyNoteStyle {
    StickyNoteStyle(
      background: background,
      accent: accent,
      titleText: NSColor(red: 0.24, green: 0.25, blue: 0.27, alpha: 0.95),
      metaText: NSColor(red: 0.34, green: 0.35, blue: 0.38, alpha: 0.76),
      previewText: NSColor(red: 0.28, green: 0.29, blue: 0.32, alpha: 0.82),
      thumbnailBackground: NSColor.white.withAlphaComponent(0.34),
      border: NSColor.white.withAlphaComponent(0.48)
    )
  }

  private static func dark(background: NSColor, accent: NSColor) -> StickyNoteStyle {
    StickyNoteStyle(
      background: background,
      accent: accent,
      titleText: NSColor.white.withAlphaComponent(0.92),
      metaText: NSColor.white.withAlphaComponent(0.68),
      previewText: NSColor.white.withAlphaComponent(0.78),
      thumbnailBackground: NSColor.black.withAlphaComponent(0.22),
      border: NSColor.white.withAlphaComponent(0.18)
    )
  }
}

private final class StickyNoteView: NSControl {
  var isSelected: Bool {
    didSet {
      guard oldValue != isSelected else {
        return
      }
      applyLayerStyle()
      updatePinButtonVisibility()
    }
  }

  private let item: ClipboardHistoryItem
  private let onSelect: (ClipboardHistoryItem) -> Void
  private let onActivate: (ClipboardHistoryItem) -> Void
  private let onPin: ((ClipboardHistoryItem) -> Void)?
  private let style: StickyNoteStyle
  private let accentBar = NSView()
  private let titleField = NSTextField(labelWithString: "")
  private let metaField = NSTextField(labelWithString: "")
  private let previewField = NSTextField(labelWithString: "")
  private let thumbnailView = NSImageView()
  private let pinButton = NSButton(frame: .zero)
  private var pointerState = ClipboardNotePointerState()
  private var isHovered = false {
    didSet {
      updatePinButtonVisibility()
    }
  }
  private var isPressed = false {
    didSet {
      applyLayerStyle()
    }
  }

  init(
    item: ClipboardHistoryItem,
    thumbnailURL: URL?,
    style: StickyNoteStyle,
    isSelected: Bool,
    onSelect: @escaping (ClipboardHistoryItem) -> Void,
    onActivate: @escaping (ClipboardHistoryItem) -> Void,
    onPin: ((ClipboardHistoryItem) -> Void)?
  ) {
    self.item = item
    self.isSelected = isSelected
    self.onSelect = onSelect
    self.onActivate = onActivate
    self.onPin = onPin
    self.style = style
    super.init(frame: .zero)
    buildView(thumbnailURL: thumbnailURL)
    applyLayerStyle()
    updatePinButtonVisibility()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .pointingHand)
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    for trackingArea in trackingAreas {
      removeTrackingArea(trackingArea)
    }

    addTrackingArea(
      NSTrackingArea(
        rect: .zero,
        options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
        owner: self,
        userInfo: nil
      )
    )
  }

  override func mouseEntered(with event: NSEvent) {
    isHovered = true
    onSelect(item)
  }

  override func mouseExited(with event: NSEvent) {
    isHovered = false
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let isPinPoint = isPinButtonPoint(point)
    _ = pointerState.pointerDown(onPinButton: isPinPoint)

    guard !isPinPoint else {
      return
    }

    onSelect(item)
    isPressed = true
  }

  override func mouseUp(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let action = pointerState.pointerUp(
      insideNote: bounds.contains(point),
      onPinButton: isPinButtonPoint(point)
    )
    isPressed = false

    switch action {
    case .none:
      return
    case .activate:
      onActivate(item)
    case .pin:
      pinImage()
    }
  }

  private func buildView(thumbnailURL: URL?) {
    wantsLayer = true

    accentBar.translatesAutoresizingMaskIntoConstraints = false
    accentBar.wantsLayer = true
    accentBar.layer?.backgroundColor = style.accent.resolvedCGColor
    accentBar.layer?.cornerRadius = 2.5

    titleField.translatesAutoresizingMaskIntoConstraints = false
    titleField.font = .systemFont(ofSize: 13, weight: .semibold)
    titleField.textColor = style.titleText

    metaField.translatesAutoresizingMaskIntoConstraints = false
    metaField.font = .systemFont(ofSize: 10.5, weight: .medium)
    metaField.textColor = style.metaText

    previewField.translatesAutoresizingMaskIntoConstraints = false
    previewField.font = .systemFont(ofSize: 11.5, weight: .regular)
    previewField.textColor = style.previewText
    previewField.lineBreakMode = .byTruncatingTail
    previewField.maximumNumberOfLines = item.kind == .text ? 3 : 2

    addSubview(accentBar)
    addSubview(titleField)
    addSubview(metaField)
    addSubview(previewField)
    configurePinButton()

    NSLayoutConstraint.activate([
      accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      accentBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 12),
      accentBar.heightAnchor.constraint(equalToConstant: 5),
    ])

    configureText(thumbnailURL: thumbnailURL)
  }

  private func configurePinButton() {
    pinButton.translatesAutoresizingMaskIntoConstraints = false
    pinButton.isBordered = false
    pinButton.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)
    pinButton.imagePosition = .imageOnly
    pinButton.contentTintColor = style.accent
    pinButton.toolTip = nil
    pinButton.target = self
    pinButton.action = #selector(pinImage)
    pinButton.wantsLayer = true
    pinButton.layer?.backgroundColor = style.thumbnailBackground.withAlphaComponent(0.88).resolvedCGColor
    pinButton.layer?.cornerRadius = 10
    pinButton.layer?.borderWidth = 1
    pinButton.layer?.borderColor = style.border.resolvedCGColor
    addSubview(pinButton)

    NSLayoutConstraint.activate([
      pinButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      pinButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      pinButton.widthAnchor.constraint(equalToConstant: 24),
      pinButton.heightAnchor.constraint(equalToConstant: 24),
    ])
  }

  private func configureText(thumbnailURL: URL?) {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    metaField.stringValue = "\(formatter.string(fromByteCount: Int64(item.byteSize))) · \(relativeTime(from: item.lastUsedAt))"

    switch item.kind {
    case .text:
      titleField.stringValue = "文本"
      previewField.stringValue = item.preview.isEmpty ? "空文本" : item.preview

      NSLayoutConstraint.activate([
        titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
        titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
        titleField.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 10),

        metaField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
        metaField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
        metaField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 3),

        previewField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
        previewField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
        previewField.topAnchor.constraint(equalTo: metaField.bottomAnchor, constant: 7),
        previewField.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
      ])

    case .image:
      titleField.stringValue = "图片"
      previewField.stringValue = "点击粘贴这张图片"
      thumbnailView.translatesAutoresizingMaskIntoConstraints = false
      thumbnailView.image = thumbnailURL.flatMap(NSImage.init(contentsOf:))
        ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
      thumbnailView.imageScaling = .scaleProportionallyUpOrDown
      thumbnailView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 26, weight: .regular)
      thumbnailView.wantsLayer = true
      thumbnailView.layer?.backgroundColor = style.thumbnailBackground.resolvedCGColor
      thumbnailView.layer?.cornerRadius = 12
      thumbnailView.layer?.masksToBounds = true
      addSubview(thumbnailView)

      NSLayoutConstraint.activate([
        thumbnailView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
        thumbnailView.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 12),
        thumbnailView.widthAnchor.constraint(equalToConstant: 52),
        thumbnailView.heightAnchor.constraint(equalToConstant: 52),

        titleField.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
        titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -48),
        titleField.topAnchor.constraint(equalTo: thumbnailView.topAnchor, constant: 1),

        metaField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
        metaField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
        metaField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 4),

        previewField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
        previewField.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
        previewField.topAnchor.constraint(equalTo: metaField.bottomAnchor, constant: 8),
      ])
    }
  }

  private func applyLayerStyle() {
    wantsLayer = true
    let backgroundAlpha: CGFloat
    if isPressed {
      backgroundAlpha = 0.96
    } else if isSelected {
      backgroundAlpha = 0.92
    } else {
      backgroundAlpha = 0.86
    }

    layer?.backgroundColor = style.background.withAlphaComponent(backgroundAlpha).resolvedCGColor
    layer?.cornerRadius = 22
    layer?.borderWidth = 1
    layer?.borderColor = (isSelected ? style.border.withAlphaComponent(0.72) : style.border).resolvedCGColor
    layer?.shadowColor = NSColor.black.resolvedCGColor
    layer?.shadowOpacity = isPressed ? 0.06 : (isSelected ? 0.18 : 0.14)
    layer?.shadowRadius = isPressed ? 7 : (isSelected ? 16 : 14)
    layer?.shadowOffset = NSSize(width: 0, height: isPressed ? -1 : (isSelected ? -5 : -4))
    layer?.zPosition = isSelected ? 10 : 0
    layer?.transform = CATransform3DMakeScale(isSelected ? 1.035 : 1, isSelected ? 1.035 : 1, 1)
  }

  private func updatePinButtonVisibility() {
    let shouldShow = onPin != nil && (isSelected || isHovered)
    pinButton.isHidden = !shouldShow
    pinButton.alphaValue = shouldShow ? 1 : 0
  }

  private func isPinButtonPoint(_ point: NSPoint) -> Bool {
    onPin != nil && !pinButton.isHidden && pinButton.frame.contains(point)
  }

  @objc private func pinImage() {
    pointerState.pinButtonActionPerformed()
    onSelect(item)
    onPin?(item)
  }

  private func relativeTime(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

private extension NSColor {
  var resolvedCGColor: CGColor {
    usingColorSpace(.deviceRGB)?.cgColor ?? cgColor
  }
}
