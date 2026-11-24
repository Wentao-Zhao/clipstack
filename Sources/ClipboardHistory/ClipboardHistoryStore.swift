import AppKit
import ClipboardHistoryCore
import Foundation
import ImageIO

@MainActor
final class ClipboardHistoryStore {
  private let fileManager: FileManager
  private let rootURL: URL
  private let itemsURL: URL
  private let thumbnailsURL: URL
  private let indexURL: URL
  private let configurationProvider: () -> ClipboardConfiguration

  private(set) var items: [ClipboardHistoryItem] = []
  var onChange: (() -> Void)?

  init(
    rootURL: URL? = nil,
    fileManager: FileManager = .default,
    configurationProvider: @escaping () -> ClipboardConfiguration
  ) {
    self.fileManager = fileManager
    self.configurationProvider = configurationProvider

    let baseURL = rootURL ?? fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0].appendingPathComponent("ClipboardHistory", isDirectory: true)

    self.rootURL = baseURL
    self.itemsURL = baseURL.appendingPathComponent("items", isDirectory: true)
    self.thumbnailsURL = baseURL.appendingPathComponent("thumbnails", isDirectory: true)
    self.indexURL = baseURL.appendingPathComponent("index.json", isDirectory: false)

    createDirectories()
    loadIndex()
    prune()
  }

  func saveText(_ text: String, now: Date = Date()) {
    guard let data = text.data(using: .utf8) else {
      return
    }

    let config = configurationProvider()
    guard ClipboardCapturePolicy.shouldCaptureText(byteCount: data.count, config: config) else {
      return
    }
    guard !isDuplicate(kind: .text, data: data) else {
      return
    }

    let id = UUID().uuidString
    let relativePath = "items/\(id).txt"
    let destination = rootURL.appendingPathComponent(relativePath, isDirectory: false)

    do {
      try data.write(to: destination, options: .atomic)
      let item = ClipboardHistoryItem(
        id: id,
        kind: .text,
        createdAt: now,
        lastUsedAt: now,
        byteSize: data.count,
        preview: ClipboardCapturePolicy.preview(for: text),
        contentRelativePath: relativePath,
        thumbnailRelativePath: nil
      )
      insert(item)
    } catch {
      presentStorageError(error)
    }
  }

  func saveImageData(_ data: Data, now: Date = Date()) {
    let config = configurationProvider()
    guard ClipboardCapturePolicy.shouldCaptureImage(byteCount: data.count, config: config) else {
      return
    }
    guard !isDuplicate(kind: .image, data: data) else {
      return
    }

    let id = UUID().uuidString
    let relativePath = "items/\(id).png"
    let thumbnailRelativePath = "thumbnails/\(id).png"
    let contentURL = rootURL.appendingPathComponent(relativePath, isDirectory: false)
    let thumbnailURL = rootURL.appendingPathComponent(thumbnailRelativePath, isDirectory: false)

    do {
      try data.write(to: contentURL, options: .atomic)
      try makeThumbnailData(from: data)?.write(to: thumbnailURL, options: .atomic)

      let item = ClipboardHistoryItem(
        id: id,
        kind: .image,
        createdAt: now,
        lastUsedAt: now,
        byteSize: data.count,
        preview: "图片",
        contentRelativePath: relativePath,
        thumbnailRelativePath: thumbnailRelativePath,
        searchText: nil
      )
      insert(item)
      recognizeImageTextIfNeeded(id: id, data: data)
    } catch {
      presentStorageError(error)
    }
  }

  func markUsed(_ item: ClipboardHistoryItem, at date: Date = Date()) {
    guard let index = items.firstIndex(where: { $0.id == item.id }) else {
      return
    }

    items[index].lastUsedAt = date
    sortItems()
    saveIndex()
    onChange?()
  }

  func writeToPasteboard(_ item: ClipboardHistoryItem) -> Bool {
    guard let data = contentData(for: item) else {
      return false
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    switch item.kind {
    case .text:
      guard let text = String(data: data, encoding: .utf8) else {
        return false
      }
      return pasteboard.setString(text, forType: .string)

    case .image:
      guard let image = NSImage(data: data) else {
        return false
      }
      return pasteboard.writeObjects([image])
    }
  }

  func thumbnailURL(for item: ClipboardHistoryItem) -> URL? {
    guard let relativePath = item.thumbnailRelativePath else {
      return nil
    }
    let thumbnailURL = rootURL.appendingPathComponent(relativePath, isDirectory: false)
    let originalURL = rootURL.appendingPathComponent(item.contentRelativePath, isDirectory: false)
    let currentSide = imagePixelSide(at: thumbnailURL) ?? 0
    // Older versions cached small icons. Upgrade only when the original has more detail.
    if currentSide < 480,
       let originalSide = imagePixelSide(at: originalURL),
       currentSide < min(480, originalSide),
       let data = try? Data(contentsOf: originalURL),
       let thumbnail = makeThumbnailData(from: data) {
      try? thumbnail.write(to: thumbnailURL, options: .atomic)
    }
    return thumbnailURL
  }

  func contentData(for item: ClipboardHistoryItem) -> Data? {
    let url = rootURL.appendingPathComponent(item.contentRelativePath, isDirectory: false)
    return try? Data(contentsOf: url)
  }

  private func recognizeImageTextIfNeeded(id: String, data: Data) {
    Task { [weak self] in
      guard let searchText = await ImageTextRecognizer.recognizedSearchText(from: data) else {
        return
      }
      self?.updateSearchText(searchText, for: id)
    }
  }

  private func updateSearchText(_ searchText: String, for id: String) {
    guard
      !searchText.isEmpty,
      let index = items.firstIndex(where: { $0.id == id })
    else {
      return
    }

    items[index].searchText = searchText
    saveIndex()
    onChange?()
  }

  func clearAll() {
    do {
      if fileManager.fileExists(atPath: rootURL.path) {
        try fileManager.removeItem(at: rootURL)
      }
      items = []
      createDirectories()
      saveIndex()
      onChange?()
    } catch {
      presentStorageError(error)
    }
  }

  func prune() {
    let config = configurationProvider()
    let expired = ClipboardEvictionPolicy.pruneExpired(items, now: Date(), config: config)
    deleteFiles(for: expired.removed)

    let counted = ClipboardEvictionPolicy.pruneCounts(expired.remaining, config: config)
    deleteFiles(for: counted.removed)

    items = counted.remaining
    sortItems()
    saveIndex()
    onChange?()
  }

  private func insert(_ item: ClipboardHistoryItem) {
    items.insert(item, at: 0)
    prune()
  }

  private func loadIndex() {
    guard let data = try? Data(contentsOf: indexURL) else {
      items = []
      return
    }

    do {
      items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: data)
      sortItems()
    } catch {
      items = []
    }
  }

  private func saveIndex() {
    do {
      let data = try JSONEncoder().encode(items)
      try data.write(to: indexURL, options: .atomic)
    } catch {
      presentStorageError(error)
    }
  }

  private func createDirectories() {
    do {
      try fileManager.createDirectory(at: itemsURL, withIntermediateDirectories: true)
      try fileManager.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
    } catch {
      presentStorageError(error)
    }
  }

  private func deleteFiles(for removedItems: [ClipboardHistoryItem]) {
    for item in removedItems {
      removeIfExists(rootURL.appendingPathComponent(item.contentRelativePath, isDirectory: false))

      if let thumbnailRelativePath = item.thumbnailRelativePath {
        removeIfExists(rootURL.appendingPathComponent(thumbnailRelativePath, isDirectory: false))
      }
    }
  }

  private func removeIfExists(_ url: URL) {
    guard fileManager.fileExists(atPath: url.path) else {
      return
    }
    try? fileManager.removeItem(at: url)
  }

  private func isDuplicate(kind: ClipboardItemKind, data: Data) -> Bool {
    guard let first = items.first, first.kind == kind else {
      return false
    }
    return contentData(for: first) == data
  }

  private func sortItems() {
    items.sort { lhs, rhs in
      if lhs.lastUsedAt == rhs.lastUsedAt {
        return lhs.createdAt > rhs.createdAt
      }
      return lhs.lastUsedAt > rhs.lastUsedAt
    }
  }

  private func makeThumbnailData(from data: Data) -> Data? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 480,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return NSBitmapImageRep(cgImage: thumbnail).representation(using: .png, properties: [:])
  }

  private func imagePixelSide(at url: URL) -> Int? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
          let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { return nil }
    return max(width.intValue, height.intValue)
  }

  private func presentStorageError(_ error: Error) {
    NSLog("ClipboardHistory storage error: \(error.localizedDescription)")
  }
}
