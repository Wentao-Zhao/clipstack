import Foundation

public enum ClipboardRetentionOption: String, CaseIterable, Codable, Equatable {
  case fifteenMinutes
  case oneHour
  case threeHours
  case sixHours
  case twelveHours
  case oneDay
  case sevenDays
  case thirtyDays

  public var duration: TimeInterval {
    switch self {
    case .fifteenMinutes:
      15 * 60
    case .oneHour:
      60 * 60
    case .threeHours:
      3 * 60 * 60
    case .sixHours:
      6 * 60 * 60
    case .twelveHours:
      12 * 60 * 60
    case .oneDay:
      24 * 60 * 60
    case .sevenDays:
      7 * 24 * 60 * 60
    case .thirtyDays:
      30 * 24 * 60 * 60
    }
  }

  public var displayName: String {
    switch self {
    case .fifteenMinutes:
      "15 分钟"
    case .oneHour:
      "1 小时"
    case .threeHours:
      "3 小时"
    case .sixHours:
      "6 小时"
    case .twelveHours:
      "12 小时"
    case .oneDay:
      "24 小时"
    case .sevenDays:
      "7 天"
    case .thirtyDays:
      "30 天"
    }
  }
}

public enum ClipboardPanelEdge: String, CaseIterable, Codable, Equatable {
  case top
  case bottom
  case left
  case right

  public var displayName: String {
    switch self {
    case .top:
      "屏幕上方"
    case .bottom:
      "屏幕下方"
    case .left:
      "屏幕左侧"
    case .right:
      "屏幕右侧"
    }
  }

  public var isHorizontal: Bool {
    self == .top || self == .bottom
  }
}

public enum ClipboardPanelAppearance: String, CaseIterable, Codable, Equatable {
  case system
  case light
  case dark

  public var displayName: String {
    switch self {
    case .system:
      "跟随系统"
    case .light:
      "浅色模式"
    case .dark:
      "深色模式"
    }
  }
}

public enum ClipboardActivationShortcut: String, CaseIterable, Codable, Equatable {
  case doubleCommand
  case doubleOption
  case doubleControl
  case doubleShift
  case customKeyCombo
  case disabled

  public var displayName: String {
    switch self {
    case .doubleCommand:
      "双击 Command"
    case .doubleOption:
      "双击 Option"
    case .doubleControl:
      "双击 Control"
    case .doubleShift:
      "双击 Shift"
    case .customKeyCombo:
      "自定义组合键"
    case .disabled:
      "关闭快捷键"
    }
  }

  public var triggerModifier: CommandModifier? {
    switch self {
    case .doubleCommand:
      .command
    case .doubleOption:
      .option
    case .doubleControl:
      .control
    case .doubleShift:
      .shift
    case .customKeyCombo, .disabled:
      nil
    }
  }
}

public enum ClipboardSelectionAction: String, CaseIterable, Codable, Equatable {
  case pasteToActiveApp
  case copyToClipboard

  public var displayName: String {
    switch self {
    case .pasteToActiveApp:
      "自动粘贴到当前 App"
    case .copyToClipboard:
      "仅复制到剪贴板"
    }
  }
}

public struct ClipboardConfiguration: Codable, Equatable {
  public var retentionDuration: TimeInterval
  public var maxTextItems: Int
  public var maxImageItems: Int
  public var maxTextBytes: Int
  public var maxImageBytes: Int
  public var memoryBudgetBytes: Int
  public var memoryCleanupTriggerRatio: Double
  public var memoryCleanupTargetRatio: Double
  public var clearHistoryOnQuit: Bool
  public var panelEdge: ClipboardPanelEdge
  public var panelAppearance: ClipboardPanelAppearance
  public var launchAtLoginEnabled: Bool
  public var activationShortcut: ClipboardActivationShortcut
  public var customActivationShortcut: KeyboardShortcut?
  public var selectionAction: ClipboardSelectionAction

  public static let `default` = ClipboardConfiguration(
    retentionDuration: ClipboardRetentionOption.sixHours.duration,
    maxTextItems: 100,
    maxImageItems: 10,
    maxTextBytes: 4 * 1024 * 1024,
    maxImageBytes: 5 * 1024 * 1024,
    memoryBudgetBytes: 32 * 1024 * 1024,
    memoryCleanupTriggerRatio: 0.9,
    memoryCleanupTargetRatio: 0.6,
    clearHistoryOnQuit: false,
    panelEdge: .bottom,
    panelAppearance: .system,
    launchAtLoginEnabled: false,
    activationShortcut: .doubleCommand,
    customActivationShortcut: nil,
    selectionAction: .pasteToActiveApp
  )

  public init(
    retentionDuration: TimeInterval,
    maxTextItems: Int,
    maxImageItems: Int,
    maxTextBytes: Int,
    maxImageBytes: Int,
    memoryBudgetBytes: Int,
    memoryCleanupTriggerRatio: Double,
    memoryCleanupTargetRatio: Double,
    clearHistoryOnQuit: Bool,
    panelEdge: ClipboardPanelEdge = .bottom,
    panelAppearance: ClipboardPanelAppearance = .system,
    launchAtLoginEnabled: Bool = false,
    activationShortcut: ClipboardActivationShortcut = .doubleCommand,
    customActivationShortcut: KeyboardShortcut? = nil,
    selectionAction: ClipboardSelectionAction = .pasteToActiveApp
  ) {
    self.retentionDuration = retentionDuration
    self.maxTextItems = max(0, maxTextItems)
    self.maxImageItems = max(0, maxImageItems)
    self.maxTextBytes = max(0, maxTextBytes)
    self.maxImageBytes = max(0, maxImageBytes)
    self.memoryBudgetBytes = max(0, memoryBudgetBytes)
    self.memoryCleanupTriggerRatio = memoryCleanupTriggerRatio
    self.memoryCleanupTargetRatio = memoryCleanupTargetRatio
    self.clearHistoryOnQuit = clearHistoryOnQuit
    self.panelEdge = panelEdge
    self.panelAppearance = panelAppearance
    self.launchAtLoginEnabled = launchAtLoginEnabled
    self.activationShortcut = activationShortcut
    self.customActivationShortcut = customActivationShortcut?.isValid == true ? customActivationShortcut : nil
    self.selectionAction = selectionAction
  }
}
