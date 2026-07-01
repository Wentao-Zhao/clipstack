import Foundation

public enum ClipboardItemKind: String, Codable, Equatable, CaseIterable {
  case text
  case image
}

public struct ClipboardHistoryItem: Codable, Equatable, Identifiable {
  public var id: String
  public var kind: ClipboardItemKind
  public var createdAt: Date
  public var lastUsedAt: Date
  public var byteSize: Int
  public var preview: String
  public var contentRelativePath: String
  public var thumbnailRelativePath: String?
  public var searchText: String?

  public init(
    id: String,
    kind: ClipboardItemKind,
    createdAt: Date,
    lastUsedAt: Date,
    byteSize: Int,
    preview: String,
    contentRelativePath: String,
    thumbnailRelativePath: String?,
    searchText: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.byteSize = byteSize
    self.preview = preview
    self.contentRelativePath = contentRelativePath
    self.thumbnailRelativePath = thumbnailRelativePath
    self.searchText = searchText
  }
}
