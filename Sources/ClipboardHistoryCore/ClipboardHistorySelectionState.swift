public struct ClipboardHistorySelectionState: Equatable {
  public private(set) var itemCount: Int
  public private(set) var selectedIndex: Int?

  public init(itemCount: Int) {
    self.itemCount = max(0, itemCount)
    self.selectedIndex = self.itemCount > 0 ? 0 : nil
  }

  public mutating func updateItemCount(_ itemCount: Int) {
    self.itemCount = max(0, itemCount)

    guard self.itemCount > 0 else {
      selectedIndex = nil
      return
    }

    selectedIndex = min(selectedIndex ?? 0, self.itemCount - 1)
  }

  public mutating func select(_ index: Int) {
    guard itemCount > 0 else {
      selectedIndex = nil
      return
    }

    selectedIndex = min(max(index, 0), itemCount - 1)
  }

  public mutating func moveForward() {
    guard let selectedIndex, itemCount > 0 else {
      return
    }

    self.selectedIndex = min(selectedIndex + 1, itemCount - 1)
  }

  public mutating func moveBackward() {
    guard let selectedIndex, itemCount > 0 else {
      return
    }

    self.selectedIndex = max(selectedIndex - 1, 0)
  }
}
