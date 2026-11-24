import AppKit
import ClipboardHistoryCore

@MainActor
final class HistoryPanelController: NSObject, NSSearchFieldDelegate {
  private let store: ClipboardHistoryStore
  private let configurationProvider: () -> ClipboardConfiguration
  private let onSelect: (ClipboardHistoryItem, NSRunningApplication?) -> Void
  private let onPinImage: (ClipboardHistoryItem, PinnedImageStyle) -> Void
  private let onOpenPreferences: () -> Void
  private var targetApplication: NSRunningApplication?
  private var panel: HistoryPanel?
  private var allRows: [ClipboardHistoryItem] = []
  private var rows: [ClipboardHistoryItem] = []
  private var searchQuery = ""
  private var focusState = HistoryPanelFocusState()
  private var selectionState = ClipboardHistorySelectionState(itemCount: 0)
  private var noteViews: [HistoryNoteView] = []
  private weak var shelfView: HistoryShelfView?
  private var selectedKind: ClipboardItemKind?
  private weak var activeSearchField: HistorySearchField?
  private weak var notesFocusView: HistoryNotesFocusView?
  private var activePanelEdge: ClipboardPanelEdge = .bottom
  private var activePanelAppearance: PanelAppearance = .light

  init(
    store: ClipboardHistoryStore,
    configurationProvider: @escaping () -> ClipboardConfiguration,
    onSelect: @escaping (ClipboardHistoryItem, NSRunningApplication?) -> Void,
    onPinImage: @escaping (ClipboardHistoryItem, PinnedImageStyle) -> Void,
    onOpenPreferences: @escaping () -> Void
  ) {
    self.store = store
    self.configurationProvider = configurationProvider
    self.onSelect = onSelect
    self.onPinImage = onPinImage
    self.onOpenPreferences = onOpenPreferences
    super.init()
  }

  func show() {
    allRows = store.items
    searchQuery = ""
    selectedKind = nil
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
      contentRect: NSRect(x: 0, y: 0, width: 1120, height: 304),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
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
    activePanelEdge = edge
    activePanelAppearance = appearance

    let searchField = HistorySearchField()
    searchField.placeholderString = "搜索历史"
    searchField.stringValue = searchQuery
    searchField.delegate = self
    searchField.onDefaultAction = { [weak self] in self?.activateSelectedItem() }
    searchField.onFocusNotes = { [weak self] in self?.focusNotes() }
    searchField.onEscape = { [weak self] in
      guard let self else { return }
      if self.searchQuery.isEmpty {
        self.close()
      } else {
        self.updateSearchQuery("")
      }
    }
    activeSearchField = searchField

    let notesContainer = HistoryNotesFocusView()
    notesContainer.onDefaultAction = { [weak self] in self?.activateSelectedItem() }
    notesContainer.onMoveSelection = { [weak self] step in self?.moveSelection(by: step) }
    notesContainer.onFocusSearch = { [weak self] in self?.focusSearch() }
    notesContainer.onBeginSearch = { [weak self] event in self?.beginSearch(with: event) }
    notesContainer.onEscape = { [weak self] in self?.close() }
    notesFocusView = notesContainer

    let root = HistoryShelfView(
      frame: NSRect(origin: .zero, size: panel.frame.size), theme: theme,
      isHorizontal: edge.isHorizontal, searchField: searchField,
      notesContainer: notesContainer, selectionAction: config.selectionAction
    )
    root.autoresizingMask = [.width, .height]
    root.totalCount = allRows.count
    root.onFilterChange = { [weak self] kind in
      guard let self else { return }
      self.selectedKind = kind
      self.reloadResults()
      self.focusNotes()
    }
    root.onOpenPreferences = { [weak self] in
      self?.close()
      self?.onOpenPreferences()
    }
    panel.contentView = root
    shelfView = root
    root.needsLayout = true
    root.layoutSubtreeIfNeeded()
    rebuildNotes(in: notesContainer, edge: edge, theme: theme)
  }

  private func rebuildNotes(in container: NSView, edge: ClipboardPanelEdge, theme: PanelTheme) {
    container.subviews.forEach { $0.removeFromSuperview() }
    shelfView?.resultCount = rows.count
    shelfView?.selectedIndex = selectionState.selectedIndex

    guard !rows.isEmpty else {
      noteViews = []
      let title = allRows.isEmpty ? "还没有复制内容" : "没有匹配的历史"
      let detail = allRows.isEmpty ? "复制文字或图片后，会显示在这里" : "试试其他关键词或切换分类"
      let emptyField = NSTextField(labelWithString: title)
      emptyField.font = .systemFont(ofSize: 14, weight: .medium)
      emptyField.textColor = theme.text
      let detailField = NSTextField(labelWithString: detail)
      detailField.font = .systemFont(ofSize: 11)
      detailField.textColor = theme.secondary
      let stack = NSStackView(views: [emptyField, detailField])
      stack.orientation = .vertical
      stack.alignment = .centerX
      stack.spacing = 8
      stack.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(stack)
      NSLayoutConstraint.activate([
        stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -16),
      ])
      return
    }

    let config = configurationProvider()
    let notes = rows.enumerated().map { index, item in
      HistoryNoteView(
        item: item, index: index, thumbnailURL: store.thumbnailURL(for: item), theme: theme,
        isSelected: selectionState.selectedIndex == index, selectionAction: config.selectionAction,
        onSelect: { [weak self] item in self?.select(item) },
        onActivate: { [weak self] item in self?.activate(item) },
        onPin: item.kind == .image ? { [weak self] item in
          self?.onPinImage(item, PinnedImageStyle(background: theme.paper, accent: PanelTheme.cobalt, border: theme.border))
        } : nil
      )
    }
    let scrollView = EdgeScrollView(axis: edge.isHorizontal ? .horizontal : .vertical)
    scrollView.frame = container.bounds
    scrollView.autoresizingMask = [.width, .height]
    scrollView.drawsBackground = false
    scrollView.contentView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.scrollerStyle = .overlay
    scrollView.hasHorizontalScroller = edge.isHorizontal
    scrollView.hasVerticalScroller = !edge.isHorizontal
    scrollView.autohidesScrollers = true
    scrollView.documentView = HistoryNotesDocumentView(
      notes: notes, isHorizontal: edge.isHorizontal,
      viewportWidth: container.bounds.width, theme: theme
    )
    noteViews = notes
    container.addSubview(scrollView)
    updateSelectionViews(scrollIntoView: false)
  }

  private func panelFrame(for edge: ClipboardPanelEdge) -> NSRect {
    let screen = screenForPanel()
    let visibleFrame = screen.visibleFrame
    let margin: CGFloat = 26

    if edge.isHorizontal {
      let width = min(visibleFrame.width - margin * 2, 1120)
      let height: CGFloat = 304
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

    let width: CGFloat = 304
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
    if activeSearchField?.stringValue != query {
      activeSearchField?.stringValue = query
    }

    reloadResults()

    if focusState.target == .notes {
      focusNotes()
    }
  }

  private func reloadResults() {
    rows = ClipboardSearchFilter.filteredItems(query: searchQuery, items: allRows, kind: selectedKind)
    selectionState = ClipboardHistorySelectionState(itemCount: rows.count)
    guard let notesFocusView else { return }
    rebuildNotes(
      in: notesFocusView,
      edge: activePanelEdge,
      theme: PanelTheme(appearance: activePanelAppearance)
    )
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
    shelfView?.selectedIndex = selectionState.selectedIndex
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
