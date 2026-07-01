import AppKit
import ClipboardHistoryCore

@MainActor
final class CommandKeyMonitor {
  private var detector = CommandDoubleTapDetector(triggerModifier: .command)
  private var activeShortcut = ClipboardActivationShortcut.doubleCommand
  private var activeCustomShortcut: KeyboardShortcut?
  private var globalMonitor: Any?
  private var localMonitor: Any?
  private let configurationProvider: () -> ClipboardConfiguration
  private let onTrigger: () -> Void

  init(
    configurationProvider: @escaping () -> ClipboardConfiguration,
    onTrigger: @escaping () -> Void
  ) {
    self.configurationProvider = configurationProvider
    self.onTrigger = onTrigger
  }

  func start() {
    stop()
    refreshConfiguration()

    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) {
      [weak self] event in
      Task { @MainActor in
        self?.handle(event)
      }
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) {
      [weak self] event in
      Task { @MainActor in
        self?.handle(event)
      }
      return event
    }
  }

  func stop() {
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
    }
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
    }

    globalMonitor = nil
    localMonitor = nil
  }

  func refreshConfiguration() {
    let config = configurationProvider()
    guard
      config.activationShortcut != activeShortcut ||
      config.customActivationShortcut != activeCustomShortcut
    else {
      return
    }

    activeShortcut = config.activationShortcut
    activeCustomShortcut = config.customActivationShortcut
    detector = CommandDoubleTapDetector(triggerModifier: config.activationShortcut.triggerModifier)
  }

  private func handle(_ event: NSEvent) {
    refreshConfiguration()

    let tapEvent: CommandTapEvent

    switch event.type {
    case .flagsChanged:
      tapEvent = .flagsChanged(timestamp: event.timestamp, modifiers: commandModifiers(from: event))
    case .keyDown:
      let modifiers = commandModifiers(from: event)
      if
        activeShortcut == .customKeyCombo,
        !event.isARepeat,
        activeCustomShortcut?.matches(keyCode: event.keyCode, modifiers: modifiers) == true
      {
        onTrigger()
        return
      }
      tapEvent = .keyDown(
        timestamp: event.timestamp,
        keyCode: event.keyCode,
        modifiers: modifiers
      )
    default:
      return
    }

    if detector.handle(tapEvent) == .trigger {
      onTrigger()
    }
  }

  private func commandModifiers(from event: NSEvent) -> Set<CommandModifier> {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    var modifiers: Set<CommandModifier> = []

    if flags.contains(.command) {
      modifiers.insert(.command)
    }
    if flags.contains(.shift) {
      modifiers.insert(.shift)
    }
    if flags.contains(.option) {
      modifiers.insert(.option)
    }
    if flags.contains(.control) {
      modifiers.insert(.control)
    }
    if flags.contains(.function) {
      modifiers.insert(.function)
    }

    return modifiers
  }
}
