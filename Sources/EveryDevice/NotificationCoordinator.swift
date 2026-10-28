import AppKit
import Combine
import EveryDeviceCore
import UserNotifications

final class NotificationCoordinator: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    private let center: UNUserNotificationCenter?

    override init() {
        // UNUserNotificationCenter requires a real app bundle; the snapshot/diagnostic
        // modes run unbundled and must not touch it.
        center = Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
        super.init()
        center?.delegate = self
        refreshStatus()
    }

    func refreshStatus() {
        guard let center else { return }
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.status = settings.authorizationStatus
            }
        }
    }

    func requestPermissionIfNeeded() {
        guard status == .notDetermined else { return }
        requestPermission()
    }

    func requestPermission() {
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshStatus()
            }
        }
    }

    func send(_ event: AlertEvent) {
        guard let center,
              status == .authorized || status == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        content.threadIdentifier = event.kind.rawValue

        let request = UNNotificationRequest(
            identifier: "\(event.kind.rawValue)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
