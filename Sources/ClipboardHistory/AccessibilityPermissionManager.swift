import ApplicationServices
import AppKit

@MainActor
final class AccessibilityPermissionManager {
  var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  func requestAccess() {
    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  func openSystemSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      )
    else {
      return
    }

    NSWorkspace.shared.open(url)
  }
}

