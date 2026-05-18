import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let chatId: String
    let senderId: String
    var senderName: String?
    var senderAvatar: String?
    var senderUsername: String?
    var type: String
    var content: String?
    var format: String?
    var mediaUrl: String?
    var mediaType: String?
    var replyToId: String?
    var forwardedFrom: String?
    var isEdited: Bool
    var isDeleted: Bool
    var isPinned: Bool
    var isStarred: Bool
    var readBy: [String]
    var deliveredTo: [String]
    var reactions: [String: [String]]
    var replyTo: ReplyPreview?
    let createdAt: Int
    var updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, type, content, format, reactions
        case chatId = "chat_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderAvatar = "sender_avatar"
        case senderUsername = "sender_username"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
        case replyToId = "reply_to_id"
        case forwardedFrom = "forwarded_from"
        case isEdited = "is_edited"
        case isDeleted = "is_deleted"
        case isPinned = "is_pinned"
        case isStarred = "is_starred"
        case readBy = "read_by"
        case deliveredTo = "delivered_to"
        case replyTo = "reply_to"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt))
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(timestamp) {
            return LocalizationManager.shared.string(for: "today")
        } else if calendar.isDateInYesterday(timestamp) {
            return LocalizationManager.shared.string(for: "yesterday")
        }
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: timestamp)
    }

    var isMedia: Bool {
        type == "image" || type == "video" || type == "audio" || type == "file"
    }

    var isHTML: Bool {
        format == "html"
    }

    var isSavedMessages: Bool {
        senderId == chatId
    }

    var mediaFullURL: URL? {
        guard let mediaUrl = mediaUrl else { return nil }
        return URL(string: "\(APIService.baseURL)\(mediaUrl)")
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }
}

struct ReplyPreview: Codable, Equatable {
    let id: String
    let content: String?
    let type: String?
    let senderName: String?

    enum CodingKeys: String, CodingKey {
        case id, content, type
        case senderName = "sender_name"
    }
}

struct MessagesResponse: Codable {
    let messages: [Message]
}

struct MessageResponse: Codable {
    let message: Message
}

struct SendMessageData: Codable {
    let chatId: String
    let content: String?
    let type: String
    var format: String?
    var replyToId: String?
    var mediaUrl: String?
    var mediaType: String?

    enum CodingKeys: String, CodingKey {
        case content, type, format
        case chatId = "chat_id"
        case replyToId = "reply_to_id"
        case mediaUrl = "media_url"
        case mediaType = "media_type"
    }
}
