import ClipboardHistoryCore
import Darwin
import Foundation

@main
struct TestRunner {
  static func main() {
    let recorder = TestRecorder()

    testDefaultConfiguration(recorder)
    testRetentionOptions(recorder)
    testPanelEdgeOptions(recorder)
    testPanelAppearanceOptions(recorder)
    testHistoryPanelFocusState(recorder)
    testActivationShortcutOptions(recorder)
    testSelectionActionOptions(recorder)
    testSearchFilterMatchesTextPreviewAndImageSearchText(recorder)
    testSearchFilterReturnsAllItemsForEmptyQuery(recorder)
    testSearchFilterCombinesKindAndQuery(recorder)
    testContentPresentation(recorder)
    testHistorySearchInputRouting(recorder)
    testKeyboardShortcutMatching(recorder)
    testNotePointerStateActivatesRegularNoteClick(recorder)
    testNotePointerStatePinsWithoutActivatingWhenPinMouseEventsLeak(recorder)
    testNotePointerStateSuppressesLeakedMouseUpAfterPinButtonAction(recorder)
    testHistorySelectionDefaultsToFirstItem(recorder)
    testHistorySelectionClampsToAvailableItems(recorder)
    testHistorySelectionMovesWithinBounds(recorder)
    testTextCaptureLimit(recorder)
    testTextPreviewLimit(recorder)
    testImageCaptureLimit(recorder)
    testExpiredItemsAreRemoved(recorder)
    testCountEvictionUsesLastUsedAt(recorder)
    testMemoryCacheEvictionThresholds(recorder)
    testDoubleCommandTapTriggers(recorder)
    testConfiguredOptionDoubleTapTriggers(recorder)
    testDisabledShortcutDoesNotTrigger(recorder)
    testDoubleCommandTapTimeoutDoesNotTrigger(recorder)
    testCommandCombinationDoesNotTrigger(recorder)
    testRegularKeyCancelsCommandTap(recorder)

    if recorder.failures.isEmpty {
      print("PASS: \(recorder.checkCount) checks")
      exit(0)
    }

    for failure in recorder.failures {
      print("FAIL: \(failure)")
    }
    print("\(recorder.failures.count) failures across \(recorder.checkCount) checks")
    exit(1)
  }

  private static func testSearchFilterCombinesKindAndQuery(_ recorder: TestRecorder) {
    let text = makeItem(id: "text", kind: .text, preview: "合同内容")
    let image = makeItem(id: "image", kind: .image, searchText: "合同截图")
    let items = [text, image]
    recorder.expect(
      ClipboardSearchFilter.filteredItems(query: "合同", items: items, kind: .image).map(\.id) == ["image"],
      "image category combines with OCR search"
    )
    recorder.expect(
      ClipboardSearchFilter.filteredItems(query: "", items: items, kind: .text).map(\.id) == ["text"],
      "text category filters without a search query"
    )
    recorder.expect(
      ClipboardSearchFilter.filteredItems(query: "不存在", items: items, kind: .image).isEmpty,
      "category search can have no results"
    )
  }

  private static func testContentPresentation(_ recorder: TestRecorder) {
    func presentation(_ text: String) -> ClipboardContentPresentation {
      ClipboardContentPresentation(item: makeItem(id: "preview", kind: .text, preview: text))
    }
    let link = presentation("  https://developer.example.com:8443/docs?q=swift#start \n")
    recorder.expect(link.kind == .link, "whole HTTP URLs receive link presentation")
    recorder.expect(link.title == "developer.example.com:8443", "link title preserves host and port")
    recorder.expect(link.body == "/docs?q=swift#start", "link preview preserves path, query and fragment")
    recorder.expect(link.badge == "HTTPS", "link badge reflects its real scheme")
    recorder.expect(presentation("http://example.com").badge == "HTTP", "HTTP is not mislabeled HTTPS")
    recorder.expect(presentation("访问 https://example.com 查看说明").kind == .text, "URLs inside prose remain text")
    recorder.expect(presentation("javascript:alert(1)").kind == .text, "non-web schemes remain text")
    recorder.expect(presentation("https://").kind == .text, "URLs without a host remain text")
    recorder.expect(presentation("SELECT owner_id, tenant_id FROM users;").kind == .code, "SQL receives code presentation")
    recorder.expect(presentation("select your preferred option").kind == .text, "ordinary prose beginning with select stays text")
    recorder.expect(presentation("{\"enabled\":true}").badge == "JSON", "valid JSON receives a JSON label")
    recorder.expect(presentation("{明天讨论}").kind == .text, "braces around prose do not imply JSON")
    let code = "func hello() {\n  print(\"Hello\")\n}"
    recorder.expect(presentation(code).body == code, "code indentation and line breaks are preserved")
    let text = presentation("检查提交重大风险\n合并前检查数据安全。")
    recorder.expect(text.title == "检查提交重大风险", "first text line is the content title")
    recorder.expect(text.body == "合并前检查数据安全。", "text body does not duplicate the title")
    recorder.expect(presentation("只有一行").body.isEmpty, "single-line text is not repeated")
    recorder.expect(presentation(" \n ").title == "空文本", "blank previews have a useful fallback")
    recorder.expect(
      ClipboardContentPresentation(item: makeItem(id: "image", kind: .image, preview: "SELECT x FROM y;")).kind == .image,
      "image OCR or display text never changes image presentation"
    )
  }

  private static func testDefaultConfiguration(_ recorder: TestRecorder) {
    let config = ClipboardConfiguration.default

    recorder.expect(config.retentionDuration == 6 * 60 * 60, "default retention is 6 hours")
    recorder.expect(config.maxTextItems == 100, "default text item limit is 100")
    recorder.expect(config.maxImageItems == 10, "default image item limit is 10")
    recorder.expect(config.maxTextBytes == 4 * 1024 * 1024, "default text limit is 4 MB")
    recorder.expect(config.maxImageBytes == 5 * 1024 * 1024, "default image limit is 5 MB")
    recorder.expect(config.memoryBudgetBytes == 32 * 1024 * 1024, "default memory budget is 32 MB")
    recorder.expect(config.memoryCleanupTriggerRatio == 0.9, "memory cleanup starts at 90 percent")
    recorder.expect(config.memoryCleanupTargetRatio == 0.6, "memory cleanup targets 60 percent")
    recorder.expect(!config.clearHistoryOnQuit, "clear-on-quit defaults to disabled")
    recorder.expect(config.panelEdge == .bottom, "history panel defaults to the bottom edge")
    recorder.expect(config.panelAppearance == .system, "history panel appearance follows system by default")
    recorder.expect(!config.launchAtLoginEnabled, "launch-at-login defaults to disabled")
    recorder.expect(config.activationShortcut == .doubleCommand, "activation shortcut defaults to double Command")
    recorder.expect(config.customActivationShortcut == nil, "custom activation shortcut defaults to unset")
    recorder.expect(config.selectionAction == .pasteToActiveApp, "selection action defaults to automatic paste")
  }

  private static func testRetentionOptions(_ recorder: TestRecorder) {
    let seconds = ClipboardRetentionOption.allCases.map(\.duration)
    let expected: [TimeInterval] = [
      15 * 60,
      60 * 60,
      3 * 60 * 60,
      6 * 60 * 60,
      12 * 60 * 60,
      24 * 60 * 60,
      7 * 24 * 60 * 60,
      30 * 24 * 60 * 60,
    ]

    recorder.expect(
      seconds == expected,
      "retention options match the configured choices"
    )
  }

  private static func testPanelEdgeOptions(_ recorder: TestRecorder) {
    recorder.expect(
      ClipboardPanelEdge.allCases == [.top, .bottom, .left, .right],
      "panel edge options match the configured screen edges"
    )
    recorder.expect(ClipboardPanelEdge.top.isHorizontal, "top panel edge scrolls horizontally")
    recorder.expect(ClipboardPanelEdge.bottom.isHorizontal, "bottom panel edge scrolls horizontally")
    recorder.expect(!ClipboardPanelEdge.left.isHorizontal, "left panel edge scrolls vertically")
    recorder.expect(!ClipboardPanelEdge.right.isHorizontal, "right panel edge scrolls vertically")
  }

  private static func testPanelAppearanceOptions(_ recorder: TestRecorder) {
    recorder.expect(
      ClipboardPanelAppearance.allCases == [.system, .light, .dark],
      "panel appearance options match the configured modes"
    )
    recorder.expect(ClipboardPanelAppearance.system.displayName == "跟随系统", "system appearance option is labeled")
    recorder.expect(ClipboardPanelAppearance.light.displayName == "浅色模式", "light appearance option is labeled")
    recorder.expect(ClipboardPanelAppearance.dark.displayName == "深色模式", "dark appearance option is labeled")
  }

  private static func testHistoryPanelFocusState(_ recorder: TestRecorder) {
    var state = HistoryPanelFocusState()

    recorder.expect(state.target == .notes, "history panel focuses notes when shown")

    state.beginSearchInput()
    recorder.expect(state.target == .search, "typing in notes moves focus to search")

    state.searchQueryDidChange("合同")
    recorder.expect(state.target == .search, "non-empty search keeps search focused")

    state.searchQueryDidChange("")
    recorder.expect(state.target == .notes, "clearing search returns focus to notes")

    state.focusSearch()
    recorder.expect(state.target == .search, "moving up from notes focuses search")

    state.focusNotes()
    recorder.expect(state.target == .notes, "moving down from search focuses notes")
  }

  private static func testActivationShortcutOptions(_ recorder: TestRecorder) {
    recorder.expect(
      ClipboardActivationShortcut.allCases == [.doubleCommand, .doubleOption, .doubleControl, .doubleShift, .customKeyCombo, .disabled],
      "activation shortcuts match the configured choices"
    )
    recorder.expect(ClipboardActivationShortcut.doubleCommand.triggerModifier == .command, "double Command maps to Command modifier")
    recorder.expect(ClipboardActivationShortcut.doubleOption.triggerModifier == .option, "double Option maps to Option modifier")
    recorder.expect(ClipboardActivationShortcut.doubleControl.triggerModifier == .control, "double Control maps to Control modifier")
    recorder.expect(ClipboardActivationShortcut.doubleShift.triggerModifier == .shift, "double Shift maps to Shift modifier")
    recorder.expect(ClipboardActivationShortcut.customKeyCombo.triggerModifier == nil, "custom key combo does not use double-tap modifier")
    recorder.expect(ClipboardActivationShortcut.disabled.triggerModifier == nil, "disabled shortcut has no trigger modifier")
  }

  private static func testSelectionActionOptions(_ recorder: TestRecorder) {
    recorder.expect(
      ClipboardSelectionAction.allCases == [.pasteToActiveApp, .copyToClipboard],
      "selection actions match the configured choices"
    )
    recorder.expect(ClipboardSelectionAction.pasteToActiveApp.displayName == "自动粘贴到当前 App", "automatic paste action is labeled")
    recorder.expect(ClipboardSelectionAction.copyToClipboard.displayName == "仅复制到剪贴板", "copy-only action is labeled")
  }

  private static func testSearchFilterMatchesTextPreviewAndImageSearchText(_ recorder: TestRecorder) {
    let text = makeItem(id: "text", kind: .text, preview: "发票金额 128 元")
    let image = makeItem(id: "image", kind: .image, preview: "图片", searchText: "截图里有合同编号 HT-2026")
    let hiddenImage = makeItem(id: "hidden-image", kind: .image, preview: "图片", searchText: nil)

    recorder.expect(
      ClipboardSearchFilter.filteredItems(query: "金额", items: [text, image, hiddenImage]).map(\.id) == ["text"],
      "search matches text preview"
    )
    recorder.expect(
      ClipboardSearchFilter.filteredItems(query: "ht-2026", items: [text, image, hiddenImage]).map(\.id) == ["image"],
      "search matches OCR text stored on image records"
    )
    recorder.expect(
      ClipboardSearchFilter.filteredItems(query: "图片", items: [text, image, hiddenImage]).isEmpty,
      "image display preview is not searched without OCR text"
    )
  }

  private static func testSearchFilterReturnsAllItemsForEmptyQuery(_ recorder: TestRecorder) {
    let items = [
      makeItem(id: "first", kind: .text),
      makeItem(id: "second", kind: .image, searchText: "截图文字"),
    ]

    recorder.expect(
      ClipboardSearchFilter.filteredItems(query: "  ", items: items).map(\.id) == ["first", "second"],
      "empty search query returns all history items"
    )
  }

  private static func testHistorySearchInputRouting(_ recorder: TestRecorder) {
    recorder.expect(
      HistorySearchInputRouting.shouldBeginSearch(characters: "a", keyCode: 0, modifiers: []),
      "typing a character in history begins search"
    )
    recorder.expect(
      HistorySearchInputRouting.shouldBeginSearch(characters: "A", keyCode: 0, modifiers: [.shift]),
      "shifted text input in history begins search"
    )
    recorder.expect(
      HistorySearchInputRouting.shouldBeginSearch(characters: "你", keyCode: 0, modifiers: []),
      "non-Latin text input in history begins search"
    )
    recorder.expect(
      !HistorySearchInputRouting.shouldBeginSearch(characters: "a", keyCode: 0, modifiers: [.command]),
      "Command shortcuts do not begin search"
    )
    recorder.expect(
      !HistorySearchInputRouting.shouldBeginSearch(characters: "a", keyCode: 0, modifiers: [.control]),
      "Control shortcuts do not begin search"
    )
    recorder.expect(
      !HistorySearchInputRouting.shouldBeginSearch(characters: "\u{F701}", keyCode: 125, modifiers: [.function]),
      "arrow keys do not begin search"
    )
    recorder.expect(
      !HistorySearchInputRouting.shouldBeginSearch(characters: "\u{7F}", keyCode: 51, modifiers: []),
      "delete does not begin search"
    )
  }

  private static func testKeyboardShortcutMatching(_ recorder: TestRecorder) {
    let shortcut = KeyboardShortcut(keyCode: 9, modifiers: [.command, .shift])

    recorder.expect(shortcut.isValid, "custom shortcut with a modifier and key is valid")
    recorder.expect(
      shortcut.matches(keyCode: 9, modifiers: [.shift, .command]),
      "custom shortcut matches same key and modifier set"
    )
    recorder.expect(
      !shortcut.matches(keyCode: 9, modifiers: [.command]),
      "custom shortcut rejects missing modifiers"
    )
    recorder.expect(
      !KeyboardShortcut(keyCode: 9, modifiers: []).isValid,
      "custom shortcut requires at least one modifier"
    )
  }

  private static func testNotePointerStateActivatesRegularNoteClick(_ recorder: TestRecorder) {
    var state = ClipboardNotePointerState()

    recorder.expect(state.pointerDown(onPinButton: false) == .none, "regular note mouse down does not activate immediately")
    recorder.expect(
      state.pointerUp(insideNote: true, onPinButton: false) == .activate,
      "regular note mouse up activates the history item"
    )
    recorder.expect(
      state.pointerUp(insideNote: true, onPinButton: true) == .none,
      "a note mouse up over the pin button does not activate the history item"
    )
  }

  private static func testNotePointerStatePinsWithoutActivatingWhenPinMouseEventsLeak(_ recorder: TestRecorder) {
    var state = ClipboardNotePointerState()

    recorder.expect(state.pointerDown(onPinButton: true) == .none, "pin button mouse down does not activate the note")
    recorder.expect(
      state.pointerUp(insideNote: true, onPinButton: true) == .pin,
      "pin button mouse up pins the image instead of activating the note"
    )
  }

  private static func testNotePointerStateSuppressesLeakedMouseUpAfterPinButtonAction(_ recorder: TestRecorder) {
    var state = ClipboardNotePointerState()
    state.pinButtonActionPerformed()

    recorder.expect(
      state.pointerUp(insideNote: true, onPinButton: true) == .none,
      "a leaked note mouse up after a pin button action is swallowed"
    )
    recorder.expect(
      state.pointerUp(insideNote: true, onPinButton: false) == .activate,
      "suppression only applies to the leaked mouse up"
    )
  }

  private static func testHistorySelectionDefaultsToFirstItem(_ recorder: TestRecorder) {
    let populated = ClipboardHistorySelectionState(itemCount: 3)
    let empty = ClipboardHistorySelectionState(itemCount: 0)

    recorder.expect(populated.selectedIndex == 0, "history selection defaults to the first item")
    recorder.expect(empty.selectedIndex == nil, "empty history has no selected item")
  }

  private static func testHistorySelectionClampsToAvailableItems(_ recorder: TestRecorder) {
    var selection = ClipboardHistorySelectionState(itemCount: 3)
    selection.select(10)
    recorder.expect(selection.selectedIndex == 2, "history selection clamps high indexes")

    selection.select(-4)
    recorder.expect(selection.selectedIndex == 0, "history selection clamps low indexes")

    selection.updateItemCount(0)
    recorder.expect(selection.selectedIndex == nil, "history selection clears when all items disappear")
  }

  private static func testHistorySelectionMovesWithinBounds(_ recorder: TestRecorder) {
    var selection = ClipboardHistorySelectionState(itemCount: 3)

    selection.moveBackward()
    recorder.expect(selection.selectedIndex == 0, "history selection stays at the first item when moving backward")

    selection.moveForward()
    selection.moveForward()
    selection.moveForward()
    recorder.expect(selection.selectedIndex == 2, "history selection stays at the last item when moving forward")
  }

  private static func testTextCaptureLimit(_ recorder: TestRecorder) {
    let config = ClipboardConfiguration.default
    let accepted = ClipboardCapturePolicy.shouldCaptureText(byteCount: config.maxTextBytes, config: config)
    let rejected = ClipboardCapturePolicy.shouldCaptureText(byteCount: config.maxTextBytes + 1, config: config)

    recorder.expect(accepted, "text at the configured limit is captured")
    recorder.expect(!rejected, "text above the configured limit is discarded")
    recorder.expect(!ClipboardCapturePolicy.shouldCaptureText(byteCount: 0, config: config), "empty text is discarded")
  }

  private static func testTextPreviewLimit(_ recorder: TestRecorder) {
    let source = String(repeating: "测", count: 600)
    let preview = ClipboardCapturePolicy.preview(for: source)

    recorder.expect(preview.count == 500, "text preview keeps the first 500 characters")
    recorder.expect(preview == String(source.prefix(500)), "text preview preserves prefix content")
  }

  private static func testImageCaptureLimit(_ recorder: TestRecorder) {
    let config = ClipboardConfiguration.default
    let accepted = ClipboardCapturePolicy.shouldCaptureImage(byteCount: config.maxImageBytes, config: config)
    let rejected = ClipboardCapturePolicy.shouldCaptureImage(byteCount: config.maxImageBytes + 1, config: config)

    recorder.expect(accepted, "image at the configured limit is captured")
    recorder.expect(!rejected, "image above the configured limit is discarded")
    recorder.expect(!ClipboardCapturePolicy.shouldCaptureImage(byteCount: 0, config: config), "empty image data is discarded")
  }

  private static func testExpiredItemsAreRemoved(_ recorder: TestRecorder) {
    let now = Date(timeIntervalSince1970: 10_000)
    let config = ClipboardConfiguration.default
    let fresh = makeItem(id: "fresh", kind: .text, createdAt: now.addingTimeInterval(-60), lastUsedAt: now.addingTimeInterval(-60))
    let expired = makeItem(
      id: "expired",
      kind: .text,
      createdAt: now.addingTimeInterval(-(config.retentionDuration + 1)),
      lastUsedAt: now.addingTimeInterval(-(config.retentionDuration + 1))
    )

    let result = ClipboardEvictionPolicy.pruneExpired([expired, fresh], now: now, config: config)

    recorder.expect(result.remaining.map(\.id) == ["fresh"], "expired records are removed")
    recorder.expect(result.removed.map(\.id) == ["expired"], "expired records are reported")
  }

  private static func testCountEvictionUsesLastUsedAt(_ recorder: TestRecorder) {
    var config = ClipboardConfiguration.default
    config.maxTextItems = 2
    config.maxImageItems = 1
    let oldText = makeItem(id: "old-text", kind: .text, lastUsedAt: Date(timeIntervalSince1970: 10))
    let usedText = makeItem(id: "used-text", kind: .text, lastUsedAt: Date(timeIntervalSince1970: 30))
    let newText = makeItem(id: "new-text", kind: .text, lastUsedAt: Date(timeIntervalSince1970: 20))
    let oldImage = makeItem(id: "old-image", kind: .image, lastUsedAt: Date(timeIntervalSince1970: 10))
    let newImage = makeItem(id: "new-image", kind: .image, lastUsedAt: Date(timeIntervalSince1970: 20))

    let result = ClipboardEvictionPolicy.pruneCounts(
      [oldText, usedText, newText, oldImage, newImage],
      config: config
    )

    recorder.expect(
      result.remaining.map(\.id) == ["used-text", "new-text", "new-image"],
      "count pruning keeps most recently used records per kind"
    )
    recorder.expect(
      result.removed.map(\.id) == ["old-text", "old-image"],
      "count pruning reports least recently used records"
    )
  }

  private static func testMemoryCacheEvictionThresholds(_ recorder: TestRecorder) {
    let config = ClipboardConfiguration(
      retentionDuration: 6 * 60 * 60,
      maxTextItems: 100,
      maxImageItems: 10,
      maxTextBytes: 4 * 1024 * 1024,
      maxImageBytes: 5 * 1024 * 1024,
      memoryBudgetBytes: 1_000,
      memoryCleanupTriggerRatio: 0.9,
      memoryCleanupTargetRatio: 0.6,
      clearHistoryOnQuit: false
    )
    let entries = [
      ClipboardCacheEntry(id: "old", byteSize: 300, lastUsedAt: Date(timeIntervalSince1970: 10)),
      ClipboardCacheEntry(id: "middle", byteSize: 300, lastUsedAt: Date(timeIntervalSince1970: 20)),
      ClipboardCacheEntry(id: "new", byteSize: 350, lastUsedAt: Date(timeIntervalSince1970: 30)),
    ]

    let overBudget = ClipboardEvictionPolicy.pruneMemoryCache(entries, config: config)
    let underBudget = ClipboardEvictionPolicy.pruneMemoryCache(Array(entries.prefix(2)), config: config)

    recorder.expect(overBudget.remaining.map(\.id) == ["new"], "memory cache pruning reaches the target budget")
    recorder.expect(overBudget.removed.map(\.id) == ["old", "middle"], "memory cache pruning removes least recently used entries")
    recorder.expect(underBudget.removed.isEmpty, "memory cache pruning does not run below the trigger threshold")
  }

  private static func testDoubleCommandTapTriggers(_ recorder: TestRecorder) {
    var detector = CommandDoubleTapDetector(maximumInterval: 0.35)
    let events: [CommandTapEvent] = [
      .flagsChanged(timestamp: 0.00, modifiers: [.command]),
      .flagsChanged(timestamp: 0.05, modifiers: []),
      .flagsChanged(timestamp: 0.20, modifiers: [.command]),
      .flagsChanged(timestamp: 0.25, modifiers: []),
    ]

    let triggered = events.map { detector.handle($0) }.contains(.trigger)

    recorder.expect(triggered, "single-key double Command triggers history")
  }

  private static func testConfiguredOptionDoubleTapTriggers(_ recorder: TestRecorder) {
    var detector = CommandDoubleTapDetector(maximumInterval: 0.35, triggerModifier: .option)
    let events: [CommandTapEvent] = [
      .flagsChanged(timestamp: 0.00, modifiers: [.option]),
      .flagsChanged(timestamp: 0.05, modifiers: []),
      .flagsChanged(timestamp: 0.20, modifiers: [.option]),
      .flagsChanged(timestamp: 0.25, modifiers: []),
    ]

    let triggered = events.map { detector.handle($0) }.contains(.trigger)

    recorder.expect(triggered, "configured single-key double Option triggers history")
  }

  private static func testDisabledShortcutDoesNotTrigger(_ recorder: TestRecorder) {
    var detector = CommandDoubleTapDetector(maximumInterval: 0.35, triggerModifier: nil)
    let events: [CommandTapEvent] = [
      .flagsChanged(timestamp: 0.00, modifiers: [.command]),
      .flagsChanged(timestamp: 0.05, modifiers: []),
      .flagsChanged(timestamp: 0.20, modifiers: [.command]),
      .flagsChanged(timestamp: 0.25, modifiers: []),
    ]

    let triggered = events.map { detector.handle($0) }.contains(.trigger)

    recorder.expect(!triggered, "disabled shortcut never triggers history")
  }

  private static func testDoubleCommandTapTimeoutDoesNotTrigger(_ recorder: TestRecorder) {
    var detector = CommandDoubleTapDetector(maximumInterval: 0.35)
    let events: [CommandTapEvent] = [
      .flagsChanged(timestamp: 0.00, modifiers: [.command]),
      .flagsChanged(timestamp: 0.05, modifiers: []),
      .flagsChanged(timestamp: 0.60, modifiers: [.command]),
      .flagsChanged(timestamp: 0.65, modifiers: []),
    ]

    let triggered = events.map { detector.handle($0) }.contains(.trigger)

    recorder.expect(!triggered, "slow Command taps do not trigger history")
  }

  private static func testCommandCombinationDoesNotTrigger(_ recorder: TestRecorder) {
    var detector = CommandDoubleTapDetector(maximumInterval: 0.35)
    let events: [CommandTapEvent] = [
      .flagsChanged(timestamp: 0.00, modifiers: [.command]),
      .keyDown(timestamp: 0.03, keyCode: 8, modifiers: [.command]),
      .flagsChanged(timestamp: 0.05, modifiers: []),
      .flagsChanged(timestamp: 0.20, modifiers: [.command]),
      .flagsChanged(timestamp: 0.25, modifiers: []),
    ]

    let triggered = events.map { detector.handle($0) }.contains(.trigger)

    recorder.expect(!triggered, "Command key combinations do not trigger history")
  }

  private static func testRegularKeyCancelsCommandTap(_ recorder: TestRecorder) {
    var detector = CommandDoubleTapDetector(maximumInterval: 0.35)
    let events: [CommandTapEvent] = [
      .flagsChanged(timestamp: 0.00, modifiers: [.command]),
      .flagsChanged(timestamp: 0.05, modifiers: []),
      .keyDown(timestamp: 0.06, keyCode: 0, modifiers: []),
      .flagsChanged(timestamp: 0.20, modifiers: [.command]),
      .flagsChanged(timestamp: 0.25, modifiers: []),
    ]

    let triggered = events.map { detector.handle($0) }.contains(.trigger)

    recorder.expect(!triggered, "regular keys cancel a pending Command tap")
  }

  private static func makeItem(
    id: String,
    kind: ClipboardItemKind,
    createdAt: Date = Date(timeIntervalSince1970: 0),
    lastUsedAt: Date = Date(timeIntervalSince1970: 0),
    preview: String? = nil,
    searchText: String? = nil
  ) -> ClipboardHistoryItem {
    ClipboardHistoryItem(
      id: id,
      kind: kind,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt,
      byteSize: 10,
      preview: preview ?? id,
      contentRelativePath: "items/\(id)",
      thumbnailRelativePath: kind == .image ? "thumbnails/\(id).png" : nil,
      searchText: searchText
    )
  }
}

private final class TestRecorder {
  private(set) var failures: [String] = []
  private(set) var checkCount = 0

  func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checkCount += 1
    if !condition() {
      failures.append(message)
    }
  }
}
