import AppKit
import ClipboardHistoryCore

@MainActor
final class PasteboardMonitor {
  private let pasteboard: NSPasteboard
  private let store: ClipboardHistoryStore
  private let configurationProvider: () -> ClipboardConfiguration
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: ClipboardHistoryStore,
    configurationProvider: @escaping () -> ClipboardConfiguration
  ) {
    self.pasteboard = pasteboard
    self.store = store
    self.configurationProvider = configurationProvider
    self.lastChangeCount = pasteboard.changeCount
  }

  func start() {
    stop()
    timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.poll()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  func poll() {
    guard pasteboard.changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = pasteboard.changeCount
    captureCurrentPasteboard()
  }

  private func captureCurrentPasteboard() {
    if containsUnsupportedFilePayload {
      return
    }

    if let text = pasteboard.string(forType: .string) {
      let config = configurationProvider()
      let byteCount = text.data(using: .utf8)?.count ?? 0

      if ClipboardCapturePolicy.shouldCaptureText(byteCount: byteCount, config: config) {
        store.saveText(text)
      }
      return
    }

    if let imageData = currentImageData() {
      let config = configurationProvider()

      if ClipboardCapturePolicy.shouldCaptureImage(byteCount: imageData.count, config: config) {
        store.saveImageData(imageData)
      }
    }
  }

  private var containsUnsupportedFilePayload: Bool {
    guard let types = pasteboard.types else {
      return false
    }

    return types.contains(.fileURL) || types.contains(NSPasteboard.PasteboardType("public.file-url"))
  }

  private func currentImageData() -> Data? {
    if let pngData = pasteboard.data(forType: .png) {
      return pngData
    }

    if
      let tiffData = pasteboard.data(forType: .tiff),
      let image = NSImage(data: tiffData)
    {
      return pngData(from: image)
    }

    guard let image = NSImage(pasteboard: pasteboard) else {
      return nil
    }

    return pngData(from: image)
  }

  private func pngData(from image: NSImage) -> Data? {
    guard
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData)
    else {
      return nil
    }

    return bitmap.representation(using: .png, properties: [:])
  }
}

