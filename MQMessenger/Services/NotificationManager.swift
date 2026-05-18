import Foundation
import UserNotifications
import SwiftUI

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var unreadCount: Int = 0
    @Published var hasPermission = false
    var deviceToken: String?

    private init() {
        checkPermission()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.hasPermission = granted
            }
        }
    }

    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }

    func registerDeviceToken(_ token: String) {
        Task {
            do {
                let subscription: [String: Any] = [
                    "endpoint": "apns://\(token)",
                    "keys": ["auth": token, "p256dh": ""]
                ]
                try await APIService.shared.updateProfile(["push_subscription": subscription])
            } catch {
                print("Failed to register push token: \(error)")
            }
        }
    }

    func scheduleLocalNotification(title: String, body: String, data: [String: String] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = data

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling failed: \(error)")
            }
        }
    }

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        if let chatId = userInfo["chat_id"] as? String {
            NotificationCenter.default.post(
                name: .openChat,
                object: nil,
                userInfo: ["chat_id": chatId]
            )
        }
    }

    func updateBadgeCount(_ count: Int) {
        unreadCount = count
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }

    func removeAllDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func removePendingNotifications(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

extension Notification.Name {
    static let openChat = Notification.Name("openChat")
    static let refreshChats = Notification.Name("refreshChats")
    static let refreshNotifications = Notification.Name("refreshNotifications")
}
