import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginController {
  static func apply(enabled: Bool) {
    do {
      if enabled {
        if SMAppService.mainApp.status != .enabled {
          try SMAppService.mainApp.register()
        }
      } else if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      NSLog("ClipboardHistory launch-at-login error: \(error.localizedDescription)")
    }
  }
}
