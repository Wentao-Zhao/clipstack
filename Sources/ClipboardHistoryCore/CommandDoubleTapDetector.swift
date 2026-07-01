import Foundation

public enum CommandModifier: String, Hashable, Codable, CaseIterable, Sendable {
  case command
  case shift
  case option
  case control
  case function
}

public enum CommandTapEvent: Equatable {
  case flagsChanged(timestamp: TimeInterval, modifiers: Set<CommandModifier>)
  case keyDown(timestamp: TimeInterval, keyCode: UInt16, modifiers: Set<CommandModifier>)

  var timestamp: TimeInterval {
    switch self {
    case .flagsChanged(let timestamp, _):
      timestamp
    case .keyDown(let timestamp, _, _):
      timestamp
    }
  }
}

public enum CommandTapResult: Equatable {
  case none
  case trigger
}

public struct CommandDoubleTapDetector {
  private let maximumInterval: TimeInterval
  private let triggerModifier: CommandModifier?
  private var isTrackingModifierPress = false
  private var lastCompletedTapAt: TimeInterval?

  public init(maximumInterval: TimeInterval = 0.35, triggerModifier: CommandModifier? = .command) {
    self.maximumInterval = maximumInterval
    self.triggerModifier = triggerModifier
  }

  public mutating func handle(_ event: CommandTapEvent) -> CommandTapResult {
    switch event {
    case .flagsChanged(let timestamp, let modifiers):
      return handleFlagsChanged(timestamp: timestamp, modifiers: modifiers)
    case .keyDown:
      reset()
      return .none
    }
  }

  private mutating func handleFlagsChanged(
    timestamp: TimeInterval,
    modifiers: Set<CommandModifier>
  ) -> CommandTapResult {
    guard let triggerModifier else {
      reset()
      return .none
    }

    if modifiers == [triggerModifier] {
      isTrackingModifierPress = true
      return .none
    }

    if modifiers.isEmpty, isTrackingModifierPress {
      isTrackingModifierPress = false

      if let lastCompletedTapAt, timestamp - lastCompletedTapAt <= maximumInterval {
        self.lastCompletedTapAt = nil
        return .trigger
      }

      lastCompletedTapAt = timestamp
      return .none
    }

    reset()
    return .none
  }

  private mutating func reset() {
    isTrackingModifierPress = false
    lastCompletedTapAt = nil
  }
}
