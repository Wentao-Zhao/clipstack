import Foundation

public enum ClipboardSearchFilter {
  public static func filteredItems(
    query: String,
    items: [ClipboardHistoryItem],
    kind: ClipboardItemKind? = nil
  ) -> [ClipboardHistoryItem] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return items.filter { item in
      guard kind == nil || item.kind == kind else { return false }
      return normalizedQuery.isEmpty || searchableText(for: item).range(
        of: normalizedQuery,
        options: [.caseInsensitive, .diacriticInsensitive]
      ) != nil
    }
  }

  private static func searchableText(for item: ClipboardHistoryItem) -> String {
    switch item.kind {
    case .text:
      return item.preview
    case .image:
      return item.searchText ?? ""
    }
  }
}
