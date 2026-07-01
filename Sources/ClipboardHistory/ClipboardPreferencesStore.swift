import ClipboardHistoryCore
import Foundation

@MainActor
final class ClipboardPreferencesStore {
  private enum Key {
    static let retentionDuration = "retentionDuration"
    static let maxTextItems = "maxTextItems"
    static let maxImageItems = "maxImageItems"
    static let maxTextBytes = "maxTextBytes"
    static let maxImageBytes = "maxImageBytes"
    static let memoryBudgetBytes = "memoryBudgetBytes"
    static let clearHistoryOnQuit = "clearHistoryOnQuit"
    static let panelEdge = "panelEdge"
    static let panelAppearance = "panelAppearance"
    static let focusSearchOnShow = "focusSearchOnShow"
    static let launchAtLoginEnabled = "launchAtLoginEnabled"
    static let activationShortcut = "activationShortcut"
    static let customActivationShortcut = "customActivationShortcut"
    static let selectionAction = "selectionAction"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var configuration: ClipboardConfiguration {
    get {
      let fallback = ClipboardConfiguration.default
      return ClipboardConfiguration(
        retentionDuration: value(for: Key.retentionDuration, fallback: fallback.retentionDuration),
        maxTextItems: value(for: Key.maxTextItems, fallback: fallback.maxTextItems),
        maxImageItems: value(for: Key.maxImageItems, fallback: fallback.maxImageItems),
        maxTextBytes: value(for: Key.maxTextBytes, fallback: fallback.maxTextBytes),
        maxImageBytes: value(for: Key.maxImageBytes, fallback: fallback.maxImageBytes),
        memoryBudgetBytes: value(for: Key.memoryBudgetBytes, fallback: fallback.memoryBudgetBytes),
        memoryCleanupTriggerRatio: fallback.memoryCleanupTriggerRatio,
        memoryCleanupTargetRatio: fallback.memoryCleanupTargetRatio,
        clearHistoryOnQuit: value(for: Key.clearHistoryOnQuit, fallback: fallback.clearHistoryOnQuit),
        panelEdge: panelEdge(fallback: fallback.panelEdge),
        panelAppearance: panelAppearance(fallback: fallback.panelAppearance),
        focusSearchOnShow: value(for: Key.focusSearchOnShow, fallback: fallback.focusSearchOnShow),
        launchAtLoginEnabled: value(for: Key.launchAtLoginEnabled, fallback: fallback.launchAtLoginEnabled),
        activationShortcut: activationShortcut(fallback: fallback.activationShortcut),
        customActivationShortcut: customActivationShortcut(),
        selectionAction: selectionAction(fallback: fallback.selectionAction)
      )
    }
    set {
      defaults.set(newValue.retentionDuration, forKey: Key.retentionDuration)
      defaults.set(newValue.maxTextItems, forKey: Key.maxTextItems)
      defaults.set(newValue.maxImageItems, forKey: Key.maxImageItems)
      defaults.set(newValue.maxTextBytes, forKey: Key.maxTextBytes)
      defaults.set(newValue.maxImageBytes, forKey: Key.maxImageBytes)
      defaults.set(newValue.memoryBudgetBytes, forKey: Key.memoryBudgetBytes)
      defaults.set(newValue.clearHistoryOnQuit, forKey: Key.clearHistoryOnQuit)
      defaults.set(newValue.panelEdge.rawValue, forKey: Key.panelEdge)
      defaults.set(newValue.panelAppearance.rawValue, forKey: Key.panelAppearance)
      defaults.set(newValue.focusSearchOnShow, forKey: Key.focusSearchOnShow)
      defaults.set(newValue.launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled)
      defaults.set(newValue.activationShortcut.rawValue, forKey: Key.activationShortcut)
      if
        let customActivationShortcut = newValue.customActivationShortcut,
        let data = try? JSONEncoder().encode(customActivationShortcut)
      {
        defaults.set(data, forKey: Key.customActivationShortcut)
      } else {
        defaults.removeObject(forKey: Key.customActivationShortcut)
      }
      defaults.set(newValue.selectionAction.rawValue, forKey: Key.selectionAction)
    }
  }

  private func value<T>(for key: String, fallback: T) -> T {
    guard defaults.object(forKey: key) != nil else {
      return fallback
    }

    return defaults.object(forKey: key) as? T ?? fallback
  }

  private func panelEdge(fallback: ClipboardPanelEdge) -> ClipboardPanelEdge {
    guard let rawValue = defaults.string(forKey: Key.panelEdge) else {
      return fallback
    }

    return ClipboardPanelEdge(rawValue: rawValue) ?? fallback
  }

  private func panelAppearance(fallback: ClipboardPanelAppearance) -> ClipboardPanelAppearance {
    guard let rawValue = defaults.string(forKey: Key.panelAppearance) else {
      return fallback
    }

    return ClipboardPanelAppearance(rawValue: rawValue) ?? fallback
  }

  private func activationShortcut(fallback: ClipboardActivationShortcut) -> ClipboardActivationShortcut {
    guard let rawValue = defaults.string(forKey: Key.activationShortcut) else {
      return fallback
    }

    return ClipboardActivationShortcut(rawValue: rawValue) ?? fallback
  }

  private func customActivationShortcut() -> KeyboardShortcut? {
    guard let data = defaults.data(forKey: Key.customActivationShortcut) else {
      return nil
    }

    let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    return shortcut?.isValid == true ? shortcut : nil
  }

  private func selectionAction(fallback: ClipboardSelectionAction) -> ClipboardSelectionAction {
    guard let rawValue = defaults.string(forKey: Key.selectionAction) else {
      return fallback
    }

    return ClipboardSelectionAction(rawValue: rawValue) ?? fallback
  }
}
