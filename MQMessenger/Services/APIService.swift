import Foundation

final class APIService {
    static let shared = APIService()
    static var baseURL: String {
        #if DEBUG
        return "http://localhost:4000"
        #else
        return "https://mq-api.example.com"
        #endif
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    private var authToken: String? {
        AuthManager.shared.token
    }

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/api\(path)")!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        var bodyData: Data?
        if let body = body {
            bodyData = try encoder.encode(body)
        }
        let request = makeRequest(path: path, method: method, body: bodyData)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? decoder.decode(ErrorResponse.self, from: data)
            throw APIError.serverError(httpResponse.statusCode, errorBody?.error ?? "unknown")
        }

        return try decoder.decode(T.self, from: data)
    }

    func requestRaw(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        var bodyData: Data?
        if let body = body {
            bodyData = try encoder.encode(body)
        }
        let request = makeRequest(path: path, method: method, body: bodyData)
        let (data, _) = try await session.data(for: request)
        return data
    }

    func login(phone: String) async throws -> AuthResponse {
        struct LoginBody: Encodable { let phone: String }
        return try await request("/auth/login", method: "POST", body: LoginBody(phone: phone))
    }

    func verifyCode(phone: String, code: String) async throws -> AuthResponse {
        struct VerifyBody: Encodable { let phone: String; let code: String }
        return try await request("/auth/verify", method: "POST", body: VerifyBody(phone: phone, code: code))
    }

    func getProfile() async throws -> UserResponse {
        try await request("/users/profile")
    }

    func updateProfile(_ updates: [String: Any]) async throws -> UserResponse {
        let body = try JSONSerialization.data(withJSONObject: updates)
        let request = makeRequest(path: "/users/profile", method: "PUT", body: body)
        let (data, _) = try await session.data(for: request)
        return try decoder.decode(UserResponse.self, from: data)
    }

    func searchUsers(query: String, page: Int = 1) async throws -> UsersResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request("/users/search?q=\(encoded)&page=\(page)")
    }

    func getContacts() async throws -> ContactsResponse {
        try await request("/users/contacts")
    }

    func addContact(contactId: String, nickname: String? = nil) async throws {
        struct Body: Encodable { let contact_id: String; let nickname: String? }
        let _: SimpleResponse = try await request("/users/contacts", method: "POST",
            body: Body(contact_id: contactId, nickname: nickname))
    }

    func deleteContact(contactId: String) async throws {
        let _: SimpleResponse = try await request("/users/contacts/\(contactId)", method: "DELETE")
    }

    func toggleFavorite(contactId: String, isFavorite: Bool) async throws {
        struct Body: Encodable { let is_favorite: Bool }
        let _: SimpleResponse = try await request("/users/contacts/\(contactId)/favorite",
            method: "PUT", body: Body(is_favorite: isFavorite))
    }

    func toggleBlock(contactId: String, isBlocked: Bool) async throws {
        struct Body: Encodable { let is_blocked: Bool }
        let _: SimpleResponse = try await request("/users/contacts/\(contactId)/block",
            method: "PUT", body: Body(is_blocked: isBlocked))
    }

    func getUserProfile(userId: String) async throws -> UserResponse {
        try await request("/users/\(userId)")
    }

    func getChats() async throws -> ChatsResponse {
        try await request("/chats")
    }

    func getChatDetail(chatId: String) async throws -> ChatDetailResponse {
        try await request("/chats/\(chatId)")
    }

    func createChat(request body: CreateChatRequest) async throws -> CreateChatResponse {
        try await request("/chats", method: "POST", body: body)
    }

    func updateChat(chatId: String, updates: [String: Any]) async throws {
        let body = try JSONSerialization.data(withJSONObject: updates)
        let req = makeRequest(path: "/chats/\(chatId)", method: "PUT", body: body)
        let _ = try await session.data(for: req)
    }

    func deleteChat(chatId: String) async throws {
        let _: SimpleResponse = try await request("/chats/\(chatId)", method: "DELETE")
    }

    func addMember(chatId: String, userId: String, role: String = "member") async throws {
        struct Body: Encodable { let user_id: String; let role: String }
        let _: SimpleResponse = try await request("/chats/\(chatId)/members",
            method: "POST", body: Body(user_id: userId, role: role))
    }

    func removeMember(chatId: String, userId: String) async throws {
        let _: SimpleResponse = try await request("/chats/\(chatId)/members/\(userId)", method: "DELETE")
    }

    func updateMemberRole(chatId: String, userId: String, role: String) async throws {
        struct Body: Encodable { let role: String }
        let _: SimpleResponse = try await request("/chats/\(chatId)/members/\(userId)/role",
            method: "PUT", body: Body(role: role))
    }

    func muteChat(chatId: String, isMuted: Bool, mutedUntil: Int? = nil) async throws {
        struct Body: Encodable { let is_muted: Bool; let muted_until: Int? }
        let _: SimpleResponse = try await request("/chats/\(chatId)/mute",
            method: "PUT", body: Body(is_muted: isMuted, muted_until: mutedUntil))
    }

    func pinChat(chatId: String, isPinned: Bool) async throws {
        struct Body: Encodable { let is_pinned: Bool }
        let _: SimpleResponse = try await request("/chats/\(chatId)/pin",
            method: "PUT", body: Body(is_pinned: isPinned))
    }

    func markRead(chatId: String, messageId: String) async throws {
        struct Body: Encodable { let message_id: String }
        let _: SimpleResponse = try await request("/chats/\(chatId)/read",
            method: "PUT", body: Body(message_id: messageId))
    }

    func getMessages(chatId: String, before: Int? = nil, limit: Int = 50) async throws -> MessagesResponse {
        var path = "/chats/\(chatId)/messages?limit=\(limit)"
        if let before = before { path += "&before=\(before)" }
        return try await request(path)
    }

    func sendMessage(chatId: String, content: String?, type: String = "text",
                     replyToId: String? = nil, mediaUrl: String? = nil, mediaType: String? = nil) async throws -> MessageResponse {
        struct Body: Encodable {
            let content: String?
            let type: String
            let reply_to_id: String?
            let media_url: String?
            let media_type: String?
        }
        return try await request("/chats/\(chatId)/messages", method: "POST",
            body: Body(content: content, type: type, reply_to_id: replyToId,
                       media_url: mediaUrl, media_type: mediaType))
    }

    func editMessage(chatId: String, messageId: String, content: String) async throws {
        struct Body: Encodable { let content: String }
        let _: SimpleResponse = try await request("/chats/\(chatId)/messages/\(messageId)",
            method: "PUT", body: Body(content: content))
    }

    func deleteMessage(chatId: String, messageId: String) async throws {
        let _: SimpleResponse = try await request("/chats/\(chatId)/messages/\(messageId)", method: "DELETE")
    }

    func reactToMessage(chatId: String, messageId: String, emoji: String) async throws {
        struct Body: Encodable { let emoji: String }
        let _: SimpleResponse = try await request(
            "/chats/\(chatId)/messages/\(messageId)/reaction", method: "POST", body: Body(emoji: emoji))
    }

    func pinMessage(chatId: String, messageId: String, isPinned: Bool) async throws {
        struct Body: Encodable { let is_pinned: Bool }
        let _: SimpleResponse = try await request(
            "/chats/\(chatId)/messages/\(messageId)/pin", method: "PUT", body: Body(is_pinned: isPinned))
    }

    func starMessage(chatId: String, messageId: String) async throws {
        let _: SimpleResponse = try await request(
            "/chats/\(chatId)/messages/\(messageId)/star", method: "PUT")
    }

    func forwardMessage(chatId: String, messageId: String, targetChatIds: [String]) async throws {
        struct Body: Encodable { let target_chat_ids: [String] }
        let _: SimpleResponse = try await request(
            "/chats/\(chatId)/messages/\(messageId)/forward", method: "POST",
            body: Body(target_chat_ids: targetChatIds))
    }

    func searchMessages(chatId: String, query: String) async throws -> MessagesResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request("/chats/\(chatId)/messages/search?q=\(encoded)")
    }

    func joinByInvite(inviteLink: String) async throws -> CreateChatResponse {
        try await request("/chats/join/\(inviteLink)", method: "POST")
    }

    func getNotifications(page: Int = 1, unreadOnly: Bool = false) async throws -> NotificationsResponse {
        var path = "/notifications?page=\(page)"
        if unreadOnly { path += "&unread_only=true" }
        return try await request(path)
    }

    func markNotificationRead(notificationId: String) async throws {
        let _: SimpleResponse = try await request("/notifications/\(notificationId)/read", method: "PUT")
    }

    func markAllNotificationsRead() async throws {
        let _: SimpleResponse = try await request("/notifications/read-all", method: "PUT")
    }

    func deleteNotification(notificationId: String) async throws {
        let _: SimpleResponse = try await request("/notifications/\(notificationId)", method: "DELETE")
    }

    func clearAllNotifications() async throws {
        let _: SimpleResponse = try await request("/notifications", method: "DELETE")
    }

    func uploadFile(data: Data, filename: String, mimeType: String) async throws -> UploadResponse {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/api/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, _) = try await session.data(for: request)
        return try decoder.decode(UploadResponse.self, from: responseData)
    }

    func uploadAvatar(data: Data, filename: String) async throws -> AvatarUploadResponse {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/api/upload/avatar")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, _) = try await session.data(for: request)
        return try decoder.decode(AvatarUploadResponse.self, from: responseData)
    }

    func enableTwoStep(pin: String) async throws {
        struct Body: Encodable { let enabled: Bool; let pin: String }
        let _: SimpleResponse = try await request("/users/profile/two-step",
            method: "PUT", body: Body(enabled: true, pin: pin))
    }

    func disableTwoStep() async throws {
        struct Body: Encodable { let enabled: Bool; let pin: String? }
        let _: SimpleResponse = try await request("/users/profile/two-step",
            method: "PUT", body: Body(enabled: false, pin: nil))
    }

    func getOnlineUsers() async throws -> OnlineResponse {
        try await request("/online")
    }

    func healthCheck() async throws -> HealthResponse {
        try await request("/health")
    }
}

struct SimpleResponse: Codable {
    var ok: Bool?
    var id: String?
    var error: String?
}

struct ErrorResponse: Codable {
    let error: String
}

struct UploadResponse: Codable {
    let url: String
    let filename: String
    let mimetype: String
    let size: Int
}

struct AvatarUploadResponse: Codable {
    let url: String
}

struct OnlineResponse: Codable {
    let online: [String]
}

struct HealthResponse: Codable {
    let status: String
    let uptime: Double
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Unauthorized"
        case .serverError(let code, let msg): return "Error \(code): \(msg)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}
