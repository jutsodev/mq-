import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: String
    var phone: String
    var username: String?
    var displayName: String?
    var avatar: String?
    var bio: String
    var status: String
    var lastSeen: Int?
    var language: String
    var theme: String
    var wallpaper: String
    var fontSize: Int
    var showOnline: Bool
    var showLastSeen: Bool
    var showReadReceipts: Bool
    var showTyping: Bool
    var twoStepEnabled: Bool
    var notificationSound: String
    var notificationVibrate: Bool
    var notificationPreview: Bool
    var createdAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, phone, username, avatar, bio, status, language, theme, wallpaper
        case displayName = "display_name"
        case lastSeen = "last_seen"
        case fontSize = "font_size"
        case showOnline = "show_online"
        case showLastSeen = "show_last_seen"
        case showReadReceipts = "show_read_receipts"
        case showTyping = "show_typing"
        case twoStepEnabled = "two_step_enabled"
        case notificationSound = "notification_sound"
        case notificationVibrate = "notification_vibrate"
        case notificationPreview = "notification_preview"
        case createdAt = "created_at"
    }

    var nameOrPhone: String {
        displayName ?? username ?? phone
    }

    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: "\(APIService.baseURL)\(avatar)")
    }

    var isOnline: Bool {
        status == "online"
    }

    var lastSeenFormatted: String {
        guard let ts = lastSeen else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

struct Contact: Codable, Identifiable {
    let id: String?
    let phone: String
    var username: String?
    var displayName: String?
    var avatar: String?
    var bio: String
    var status: String
    var lastSeen: Int?
    var nickname: String?
    var isFavorite: Bool
    var isBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case id, phone, username, avatar, bio, status, nickname
        case displayName = "display_name"
        case lastSeen = "last_seen"
        case isFavorite = "is_favorite"
        case isBlocked = "is_blocked"
    }

    var nameOrPhone: String {
        nickname ?? displayName ?? username ?? phone
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct UserResponse: Codable {
    let user: User
}

struct UsersResponse: Codable {
    let users: [User]
}

struct ContactsResponse: Codable {
    let contacts: [Contact]
}
