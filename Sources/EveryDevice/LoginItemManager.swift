import Foundation
import ServiceManagement

enum LoginItemManager {
    private static let legacyLabel = "com.everydevice.xxx"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard !isEnabled else { return }
            try SMAppService.mainApp.register()
        } else if SMAppService.mainApp.status == .enabled
                    || SMAppService.mainApp.status == .requiresApproval {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Removes the LaunchAgent written by the old fallback implementation.
    static func cleanupLegacyFallback() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              ) as? [String: Any],
              plist["Label"] as? String == legacyLabel,
              let arguments = plist["ProgramArguments"] as? [String],
              arguments.contains("--login-item") else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
