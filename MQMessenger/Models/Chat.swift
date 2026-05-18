import Foundation

struct Chat: Codable, Identifiable, Equatable {
    let id: String
    var type: String
    var name: String?
    var description: String?
    var avatar: String?
    var ownerId: String?
    var inviteLink: String?
    var isPublic: Bool
    var isMuted: Bool
    var isPinned: Bool
    var unreadCount: Int
    var role: String?
    var memberCount: Int
    var members: [ChatMember]?
    var lastMessage: Message?
    var pinnedMessageId: String?
    var slowMode: Int?
    var membersCanPost: Bool
    let createdAt: Int
    var updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, type, name, description, avatar, members, role
        case ownerId = "owner_id"
        case inviteLink = "invite_link"
        case isPublic = "is_public"
        case isMuted = "is_muted"
        case isPinned = "is_pinned"
        case unreadCount = "unread_count"
        case memberCount = "member_count"
        case lastMessage = "last_message"
        case pinnedMessageId = "pinned_message_id"
        case slowMode = "slow_mode"
        case membersCanPost = "members_can_post"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayName: String {
        name ?? "Chat"
    }

    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: "\(APIService.baseURL)\(avatar)")
    }

    var isGroup: Bool { type == "group" }
    var isChannel: Bool { type == "channel" }
    var isPrivate: Bool { type == "private" }

    var lastMessagePreview: String {
        guard let msg = lastMessage else { return "" }
        if msg.isDeleted { return "🚫" }
        switch msg.type {
        case "image": return "🖼"
        case "video": return "🎬"
        case "audio": return "🎵"
        case "file": return "📎"
        case "voice": return "🎤"
        default: return msg.content ?? ""
        }
    }

    var lastMessageTime: String {
        guard let msg = lastMessage else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(msg.createdAt))
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return LocalizationManager.shared.string(for: "yesterday")
        } else {
            formatter.dateFormat = "dd.MM"
        }
        return formatter.string(from: date)
    }

    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatMember: Codable, Identifiable {
    let id: String
    var displayName: String?
    var username: String?
    var avatar: String?
    var status: String?
    var lastSeen: Int?
    var role: String?

    enum CodingKeys: String, CodingKey {
        case id, username, avatar, status, role
        case displayName = "display_name"
        case lastSeen = "last_seen"
    }

    var nameOrUsername: String {
        displayName ?? username ?? id
    }
}

struct ChatsResponse: Codable {
    let chats: [Chat]
}

struct ChatDetailResponse: Codable {
    let chat: Chat
    let members: [ChatMember]
    let myRole: String?

    enum CodingKeys: String, CodingKey {
        case chat, members
        case myRole = "my_role"
    }
}

struct CreateChatRequest: Codable {
    let type: String
    var name: String?
    var description: String?
    var members: [String]?
    var isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case type, name, description, members
        case isPublic = "is_public"
    }
}

struct CreateChatResponse: Codable {
    let chatId: String
    var existing: Bool?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case existing
    }
}
