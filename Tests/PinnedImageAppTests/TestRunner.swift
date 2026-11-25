import AppKit
import ClipboardHistoryCore

// Observe copy commands without replacing the user's clipboard.
@MainActor
enum PasteboardWriter {
  static var images: [NSImage] = []
  static var texts: [String] = []

  static func copy(image: NSImage) { images.append(image) }
  static func copy(text: String) { texts.append(text) }
}

@main
@MainActor
enum PinnedImageAppTests {
  private static var failures = 0
  private static var checks = 0

  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    Task { await runChecks() }
    app.run()
  }

  private static func runChecks() async {
    let app = NSApplication.shared
    guard NSScreen.main != nil else {
      print("FAIL: an active macOS display is required")
      exit(1)
    }

    let manager = PinnedImageWindowManager()
    let first = NSImage(size: NSSize(width: 320, height: 200))
    first.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: first.size).fill()
    ("CLIPSTACK TEST 123" as NSString).draw(at: NSPoint(x: 25, y: 85), withAttributes: [
      .font: NSFont.systemFont(ofSize: 26, weight: .bold), .foregroundColor: NSColor.black,
    ])
    first.unlockFocus()
    let second = NSImage(size: NSSize(width: 200, height: 320))
    manager.show(image: first)
    let firstWindow = app.windows.first { $0.isVisible }!
    manager.show(image: second)
    let secondWindow = app.windows.first { $0.isVisible && $0 !== firstWindow }!

    let copy = key("c", in: firstWindow)
    expect(firstWindow.performKeyEquivalent(with: copy), "pinned window handles Command-C")
    expect(PasteboardWriter.images.last === first, "Command-C copies the addressed pin's original image")
    let shiftedCopy = key("c", modifiers: [.command, .shift], in: firstWindow)
    expect(!firstWindow.performKeyEquivalent(with: shiftedCopy), "pin does not capture Command-Shift-C")

    let imageView = descendants(of: secondWindow.contentView).compactMap { $0 as? NSImageView }.first
    if let menu = imageView?.menu, let index = menu.items.firstIndex(where: { $0.title == "复制图片" }) {
      menu.performActionForItem(at: index)
      expect(PasteboardWriter.images.last === second, "context menu copies the second pin, not the first")
    } else {
      expect(false, "pinned image offers Copy Image in its context menu")
    }
    expect(!firstWindow.styleMask.contains(.titled), "pin has no native title bar")
    firstWindow.contentView?.layoutSubtreeIfNeeded()
    let pin = firstWindow.contentView!
    if let fullImage = descendants(of: pin).compactMap({ $0 as? NSImageView }).first {
      expect(fullImage.frame.equalTo(pin.bounds), "ordinary screenshot fills the pin without an inset")
    }
    expect(firstWindow.level == .floating && !firstWindow.hasShadow, "pin floats without a frame shadow")
    snapshot(pin, name: "pinned-image")
    expect(abs(firstWindow.frame.width / firstWindow.frame.height - first.size.width / first.size.height) < 0.01,
           "initial frame fits the image ratio")
    let beforeResize = firstWindow.frame
    let corner = NSPoint(x: pin.bounds.maxX - 7, y: pin.bounds.minY + 7)
    if let handle = pin.hitTest(corner), handle !== pin {
      handle.mouseDown(with: mouse(.leftMouseDown, at: corner, in: firstWindow))
      let largerCorner = NSPoint(x: corner.x + 48, y: corner.y - 30)
      handle.mouseDragged(with: mouse(.leftMouseDragged, at: largerCorner, in: firstWindow))
      handle.mouseUp(with: mouse(.leftMouseUp, at: corner, in: firstWindow))
      expect(firstWindow.frame.width > beforeResize.width, "dragging the bottom right resizes the pin")
      expect(abs(firstWindow.frame.width / firstWindow.frame.height - 1.6) < 0.01,
             "resizing keeps the screenshot's aspect ratio")
    } else {
      expect(false, "pin has a bottom-right resize handle")
    }

    if let copyButton = button("复制图片", in: pin),
       let ocrButton = button("识别文字", in: pin),
       let closeButton = button("关闭置顶", in: pin) {
      expect(copyButton.isHiddenOrHasHiddenAncestor, "pin starts with its toolbar hidden")
      pin.mouseEntered(with: tracking(.mouseEntered, in: firstWindow))
      expect(!copyButton.isHiddenOrHasHiddenAncestor, "hover shows the toolbar")
      snapshot(pin, name: "pinned-image-hover")
      expect(button("复制图片", in: secondWindow.contentView!)?.isHiddenOrHasHiddenAncestor == true,
             "hovering one pin does not show tools on another")
      copyButton.performClick(nil)
      expect(PasteboardWriter.images.last === first, "toolbar copies its own original image")
      pin.mouseExited(with: tracking(.mouseExited, in: firstWindow))
      expect(copyButton.isHiddenOrHasHiddenAncestor, "leaving the pin hides its toolbar")
      pin.mouseEntered(with: tracking(.mouseEntered, in: firstWindow))
      ocrButton.performClick(nil)
      var result: NSTextView?
      let deadline = Date(timeIntervalSinceNow: 30)
      while Date() < deadline {
        result = app.windows.flatMap { descendants(of: $0.contentView) }
          .compactMap { $0 as? NSTextView }
          .first { $0.string.contains("CLIPSTACK") }
        if result != nil { break }
        try? await Task.sleep(nanoseconds: 100_000_000)
      }
      if let result, let ocrWindow = result.window {
        expect(result.isSelectable, "pin OCR shows selectable text")
        ocrWindow.makeFirstResponder(result)
        result.setSelectedRange((result.string as NSString).range(of: "CLIPSTACK"))
        _ = result.performKeyEquivalent(with: key("c", in: ocrWindow))
        expect(PasteboardWriter.texts.last == "CLIPSTACK", "pin OCR Command-C copies selected text")
      } else {
        let ocrViews = app.windows.flatMap { descendants(of: $0.contentView) }
        print("OCR diagnostics: \(ocrViews.compactMap { ($0 as? NSTextView)?.string })")
        print("OCR status: \(ocrViews.compactMap { ($0 as? NSTextField)?.stringValue })")
        expect(false, "pin OCR recognizes the actual image asynchronously")
      }
      closeButton.performClick(nil)
      expect(!firstWindow.isVisible && secondWindow.isVisible, "closing one pin leaves the other open")
    } else {
      expect(false, "pin offers a three-action hover toolbar")
    }
    if firstWindow.isVisible { firstWindow.close() }
    secondWindow.close()
    PasteboardWriter.texts.removeAll()

    print(failures == 0 ? "PASS: \(checks) AppKit interaction checks" : "FAIL: \(failures) of \(checks) checks")
    exit(failures == 0 ? 0 : 1)
  }

  private static func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
    checks += 1
    if !condition() {
      failures += 1
      print("FAIL: \(description)")
    }
  }

  private static func snapshot(_ view: NSView, name: String) {
    guard CommandLine.arguments.count > 1 else { return }
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
      view.cacheDisplay(in: view.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
    } catch {
      expect(false, "save pin snapshot: \(error)")
    }
  }

  private static func descendants(of view: NSView?) -> [NSView] {
    guard let view else { return [] }
    return [view] + view.subviews.flatMap { descendants(of: $0) }
  }

  private static func button(_ label: String, in view: NSView) -> NSButton? {
    descendants(of: view).compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == label }
  }

  private static func tracking(_ type: NSEvent.EventType, in window: NSWindow) -> NSEvent {
    NSEvent.enterExitEvent(
      with: type, location: NSPoint(x: 40, y: 40), modifierFlags: [], timestamp: 0,
      windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil
    )!
  }

  private static func mouse(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) -> NSEvent {
    NSEvent.mouseEvent(
      with: type, location: point, modifierFlags: [], timestamp: 0,
      windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
    )!
  }

  private static func key(
    _ character: String, modifiers: NSEvent.ModifierFlags = .command, in window: NSWindow
  ) -> NSEvent {
    NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
      windowNumber: window.windowNumber, context: nil, characters: character,
      charactersIgnoringModifiers: character, isARepeat: false, keyCode: 8
    )!
  }
}
