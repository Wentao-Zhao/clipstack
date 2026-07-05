public enum HistorySearchInputRouting {
  public static func shouldBeginSearch(
    characters: String?,
    keyCode: UInt16,
    modifiers: Set<CommandModifier>
  ) -> Bool {
    guard
      !modifiers.contains(.command),
      !modifiers.contains(.control),
      !modifiers.contains(.function),
      let characters,
      !characters.isEmpty
    else {
      return false
    }

    return characters.unicodeScalars.contains { scalar in
      scalar.value >= 0x20
        && scalar.value != 0x7F
        && !(0xF700...0xF8FF).contains(scalar.value)
    }
  }
}
