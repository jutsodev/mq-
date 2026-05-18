import Foundation

struct AppNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String
    var title: String?
    var body: String?
    var data: NotificationData
    var isRead: Bool
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, data
        case userId = "user_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt))
    }

    var timeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var icon: String {
        switch type {
        case "message": return "message.fill"
        case "group_invite": return "person.3.fill"
        case "call": return "phone.fill"
        case "mention": return "at"
        case "reaction": return "heart.fill"
        case "contact": return "person.badge.plus"
        default: return "bell.fill"
        }
    }
}

struct NotificationData: Codable {
    var chatId: String?
    var messageId: String?
    var senderId: String?
    var callId: String?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case messageId = "message_id"
        case senderId = "sender_id"
        case callId = "call_id"
    }
}

struct NotificationsResponse: Codable {
    let notifications: [AppNotification]
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case notifications
        case unreadCount = "unread_count"
    }
}

struct Story: Codable, Identifiable {
    let id: String
    let userId: String
    var type: String
    var content: String?
    var mediaUrl: String?
    var bgColor: String
    var viewers: [String]
    var expiresAt: Int?
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id, type, content, viewers
        case userId = "user_id"
        case mediaUrl = "media_url"
        case bgColor = "bg_color"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct CallRecord: Codable, Identifiable {
    let id: String
    let callerId: String
    var receiverId: String?
    var chatId: String?
    var type: String
    var status: String
    var duration: Int
    let startedAt: Int
    var endedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, type, status, duration
        case callerId = "caller_id"
        case receiverId = "receiver_id"
        case chatId = "chat_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }

    var durationFormatted: String {
        let min = duration / 60
        let sec = duration % 60
        return String(format: "%d:%02d", min, sec)
    }
}
