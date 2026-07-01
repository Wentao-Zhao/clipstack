public struct KeyboardShortcut: Codable, Equatable, Sendable {
  public var keyCode: UInt16
  public var modifiers: Set<CommandModifier>

  public init(keyCode: UInt16, modifiers: Set<CommandModifier>) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public var isValid: Bool {
    !modifiers.isEmpty
  }

  public func matches(keyCode: UInt16, modifiers: Set<CommandModifier>) -> Bool {
    isValid && self.keyCode == keyCode && self.modifiers == modifiers
  }
}
