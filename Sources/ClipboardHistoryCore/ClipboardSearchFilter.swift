import Foundation

public enum ClipboardSearchFilter {
  public static func filteredItems(
    query: String,
    items: [ClipboardHistoryItem]
  ) -> [ClipboardHistoryItem] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedQuery.isEmpty else {
      return items
    }

    return items.filter { item in
      searchableText(for: item).range(
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
