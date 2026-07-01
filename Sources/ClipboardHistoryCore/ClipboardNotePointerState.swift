import Foundation

public enum ClipboardNotePointerAction: Equatable {
  case none
  case activate
  case pin
}

public struct ClipboardNotePointerState: Equatable {
  private var isTrackingPinButton = false
  private var shouldSuppressNextActivation = false

  public init() {}

  public mutating func pointerDown(onPinButton: Bool) -> ClipboardNotePointerAction {
    guard onPinButton else {
      return .none
    }

    isTrackingPinButton = true
    shouldSuppressNextActivation = true
    return .none
  }

  public mutating func pointerUp(
    insideNote: Bool,
    onPinButton: Bool
  ) -> ClipboardNotePointerAction {
    if isTrackingPinButton {
      isTrackingPinButton = false
      shouldSuppressNextActivation = false
      return onPinButton ? .pin : .none
    }

    if shouldSuppressNextActivation {
      shouldSuppressNextActivation = false
      return .none
    }

    return insideNote && !onPinButton ? .activate : .none
  }

  public mutating func pinButtonActionPerformed() {
    isTrackingPinButton = false
    shouldSuppressNextActivation = true
  }
}
