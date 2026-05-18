import Foundation
import Combine

final class WebSocketService: ObservableObject {
    static let shared = WebSocketService()

    @Published var isConnected = false
    @Published var typingUsers: [String: Set<String>] = [:]

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var token: String?
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?
    private var messageSubject = PassthroughSubject<SocketEvent, Never>()

    var eventPublisher: AnyPublisher<SocketEvent, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    private init() {}

    func connect(token: String) {
        self.token = token
        disconnect()

        guard var components = URLComponents(string: APIService.baseURL) else { return }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/socket.io/"
        components.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "websocket"),
            URLQueryItem(name: "token", value: token),
        ]

        guard let url = components.url else { return }

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        receiveMessage()
        startPingTimer()

        reconnectAttempts = 0
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }

    func disconnect() {
        pingTimer?.invalidate()
        reconnectTimer?.invalidate()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    func send(event: String, data: [String: Any]) {
        guard let webSocket = webSocket else { return }

        let payload: [Any] = [event, data]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let message = "42\(jsonString)"
        webSocket.send(.string(message)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    func sendMessage(chatId: String, content: String?, type: String = "text",
                     replyToId: String? = nil, mediaUrl: String? = nil) {
        var data: [String: Any] = [
            "chat_id": chatId,
            "type": type,
        ]
        if let content = content { data["content"] = content }
        if let replyToId = replyToId { data["reply_to_id"] = replyToId }
        if let mediaUrl = mediaUrl { data["media_url"] = mediaUrl }

        send(event: "message:send", data: data)
    }

    func sendTypingStart(chatId: String) {
        send(event: "typing:start", data: ["chat_id": chatId])
    }

    func sendTypingStop(chatId: String) {
        send(event: "typing:stop", data: ["chat_id": chatId])
    }

    func sendReadReceipt(chatId: String, messageId: String) {
        send(event: "message:read", data: ["chat_id": chatId, "message_id": messageId])
    }

    func editMessage(messageId: String, content: String) {
        send(event: "message:edit", data: ["message_id": messageId, "content": content])
    }

    func deleteMessage(messageId: String) {
        send(event: "message:delete", data: ["message_id": messageId])
    }

    func sendReaction(messageId: String, emoji: String) {
        send(event: "message:reaction", data: ["message_id": messageId, "emoji": emoji])
    }

    func joinChat(chatId: String) {
        send(event: "chat:join", data: ["chat_id": chatId])
    }

    func leaveChat(chatId: String) {
        send(event: "chat:leave", data: ["chat_id": chatId])
    }

    func initiateCall(receiverId: String, type: String = "voice") {
        send(event: "call:initiate", data: ["receiver_id": receiverId, "type": type])
    }

    func acceptCall(callId: String) {
        send(event: "call:accept", data: ["call_id": callId])
    }

    func rejectCall(callId: String) {
        send(event: "call:reject", data: ["call_id": callId])
    }

    func endCall(callId: String) {
        send(event: "call:end", data: ["call_id": callId])
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
                self?.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        if text == "2" {
            webSocket?.send(.string("3")) { _ in }
            return
        }

        if text.hasPrefix("0") {
            return
        }

        guard text.hasPrefix("42") else { return }
        let jsonStr = String(text.dropFirst(2))

        guard let data = jsonStr.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let eventName = array.first as? String else { return }

        let eventData = array.count > 1 ? array[1] as? [String: Any] : nil

        let event = SocketEvent(name: eventName, data: eventData ?? [:])
        DispatchQueue.main.async {
            self.messageSubject.send(event)
            self.handleEventLocally(event)
        }
    }

    private func handleEventLocally(_ event: SocketEvent) {
        switch event.name {
        case "typing:start":
            if let chatId = event.data["chat_id"] as? String,
               let userId = event.data["user_id"] as? String {
                if typingUsers[chatId] == nil { typingUsers[chatId] = Set() }
                typingUsers[chatId]?.insert(userId)

                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.typingUsers[chatId]?.remove(userId)
                }
            }
        case "typing:stop":
            if let chatId = event.data["chat_id"] as? String,
               let userId = event.data["user_id"] as? String {
                typingUsers[chatId]?.remove(userId)
            }
        default:
            break
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.webSocket?.send(.string("2")) { _ in }
            self?.send(event: "presence:ping", data: [:])
        }
    }

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("WebSocket max reconnect attempts reached")
            return
        }
        reconnectTimer?.invalidate()
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2, 30)
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let token = self?.token else { return }
            self?.connect(token: token)
        }
    }
}

struct SocketEvent {
    let name: String
    let data: [String: Any]

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else { return nil }
        return try? JSONDecoder().decode(type, from: jsonData)
    }
}
