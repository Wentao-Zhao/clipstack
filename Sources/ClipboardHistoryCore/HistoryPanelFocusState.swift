public enum HistoryPanelFocusTarget: Equatable {
  case notes
  case search
}

public struct HistoryPanelFocusState: Equatable {
  public private(set) var target: HistoryPanelFocusTarget = .notes

  public init() {}

  public mutating func beginSearchInput() {
    target = .search
  }

  public mutating func searchQueryDidChange(_ query: String) {
    target = query.isEmpty ? .notes : .search
  }

  public mutating func focusSearch() {
    target = .search
  }

  public mutating func focusNotes() {
    target = .notes
  }
}
