import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatRoomViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var chatDetail: ChatDetailResponse?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var messageText = ""
    @Published var replyingTo: Message?
    @Published var editingMessage: Message?
    @Published var searchQuery = ""
    @Published var searchResults: [Message] = []
    @Published var isSearching = false
    @Published var showChatInfo = false
    @Published var showForwardSheet = false
    @Published var forwardingMessage: Message?
    @Published var showEmojiPicker = false
    @Published var selectedMessages: Set<String> = []
    @Published var isSelecting = false
    @Published var typingUserNames: [String] = []
    @Published var errorMessage: String?

    let chatId: String
    private var cancellables = Set<AnyCancellable>()
    private var hasMoreMessages = true
    private var typingTimer: Timer?

    init(chatId: String) {
        self.chatId = chatId
        setupSocketListeners()
    }

    var members: [ChatMember] {
        chatDetail?.members ?? []
    }

    var myRole: String? {
        chatDetail?.myRole
    }

    var canPost: Bool {
        guard let detail = chatDetail else { return true }
        if detail.chat.type == "channel" && !detail.chat.membersCanPost {
            return myRole == "owner" || myRole == "admin"
        }
        return true
    }

    var isAdmin: Bool {
        myRole == "owner" || myRole == "admin"
    }

    var groupedMessages: [(String, [Message])] {
        let grouped = Dictionary(grouping: messages) { $0.dateFormatted }
        return grouped.sorted { a, b in
            guard let dateA = messages.first(where: { $0.dateFormatted == a.key }),
                  let dateB = messages.first(where: { $0.dateFormatted == b.key }) else { return false }
            return dateA.createdAt < dateB.createdAt
        }
    }

    func loadInitial() async {
        isLoading = true
        do {
            async let messagesTask = APIService.shared.getMessages(chatId: chatId)
            async let detailTask = APIService.shared.getChatDetail(chatId: chatId)

            let (messagesResp, detailResp) = try await (messagesTask, detailTask)
            messages = messagesResp.messages
            chatDetail = detailResp
            isLoading = false

            WebSocketService.shared.joinChat(chatId: chatId)
            markLastAsRead()
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreMessages() async {
        guard hasMoreMessages, !isLoading, let first = messages.first else { return }

        do {
            let response = try await APIService.shared.getMessages(
                chatId: chatId, before: first.createdAt)
            if response.messages.isEmpty {
                hasMoreMessages = false
            } else {
                messages.insert(contentsOf: response.messages, at: 0)
            }
        } catch {}
    }

    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || replyingTo != nil else { return }

        let replyId = replyingTo?.id
        let editMsg = editingMessage
        messageText = ""
        replyingTo = nil
        editingMessage = nil
        isSending = true

        do {
            if let editMsg = editMsg {
                try await APIService.shared.editMessage(chatId: chatId, messageId: editMsg.id, content: text)
                if let index = messages.firstIndex(where: { $0.id == editMsg.id }) {
                    messages[index].content = text
                    messages[index].isEdited = true
                }
            } else {
                let response = try await APIService.shared.sendMessage(
                    chatId: chatId, content: text, replyToId: replyId)
                _ = response.message
            }
            isSending = false
        } catch {
            isSending = false
            errorMessage = error.localizedDescription
        }
    }

    func sendMedia(url: String, type: String, mediaType: String) async {
        do {
            let _ = try await APIService.shared.sendMessage(
                chatId: chatId, content: nil, type: type, mediaUrl: url, mediaType: mediaType)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMessage(_ messageId: String) async {
        do {
            try await APIService.shared.deleteMessage(chatId: chatId, messageId: messageId)
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].isDeleted = true
                messages[index].content = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reactToMessage(_ messageId: String, emoji: String) async {
        do {
            try await APIService.shared.reactToMessage(chatId: chatId, messageId: messageId, emoji: emoji)
        } catch {}
    }

    func pinMessage(_ messageId: String) async {
        do {
            let msg = messages.first(where: { $0.id == messageId })
            let isPinned = !(msg?.isPinned ?? false)
            try await APIService.shared.pinMessage(chatId: chatId, messageId: messageId, isPinned: isPinned)
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].isPinned = isPinned
            }
        } catch {}
    }

    func starMessage(_ messageId: String) async {
        do {
            try await APIService.shared.starMessage(chatId: chatId, messageId: messageId)
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].isStarred.toggle()
            }
        } catch {}
    }

    func forwardMessage(_ messageId: String, to chatIds: [String]) async {
        do {
            try await APIService.shared.forwardMessage(
                chatId: chatId, messageId: messageId, targetChatIds: chatIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startReply(_ message: Message) {
        replyingTo = message
        editingMessage = nil
    }

    func startEdit(_ message: Message) {
        editingMessage = message
        messageText = message.content ?? ""
        replyingTo = nil
    }

    func cancelReplyOrEdit() {
        replyingTo = nil
        editingMessage = nil
        if editingMessage != nil { messageText = "" }
    }

    func copyMessage(_ message: Message) {
        UIPasteboard.general.string = message.content
    }

    func searchMessages(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            let response = try await APIService.shared.searchMessages(chatId: chatId, query: query)
            searchResults = response.messages
        } catch {}
        isSearching = false
    }

    func handleTyping() {
        WebSocketService.shared.sendTypingStart(chatId: chatId)
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            WebSocketService.shared.sendTypingStop(chatId: self.chatId)
        }
    }

    func addMember(_ userId: String) async {
        do {
            try await APIService.shared.addMember(chatId: chatId, userId: userId)
            let detail = try await APIService.shared.getChatDetail(chatId: chatId)
            chatDetail = detail
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeMember(_ userId: String) async {
        do {
            try await APIService.shared.removeMember(chatId: chatId, userId: userId)
            chatDetail?.members.removeAll { $0.id == userId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMemberRole(_ userId: String, role: String) async {
        do {
            try await APIService.shared.updateMemberRole(chatId: chatId, userId: userId, role: role)
        } catch {}
    }

    func leaveChat() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        do {
            try await APIService.shared.removeMember(chatId: chatId, userId: userId)
        } catch {}
    }

    private func markLastAsRead() {
        guard let lastMsg = messages.last else { return }
        WebSocketService.shared.sendReadReceipt(chatId: chatId, messageId: lastMsg.id)
        Task {
            try? await APIService.shared.markRead(chatId: chatId, messageId: lastMsg.id)
        }
    }

    private func setupSocketListeners() {
        WebSocketService.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleSocketEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleSocketEvent(_ event: SocketEvent) {
        switch event.name {
        case "message:new":
            guard let msg: Message = event.decode(Message.self),
                  msg.chatId == chatId else { return }
            if !messages.contains(where: { $0.id == msg.id }) {
                messages.append(msg)
                if msg.senderId != AuthManager.shared.currentUser?.id {
                    markLastAsRead()
                }
            }

        case "message:edited":
            guard let messageId = event.data["message_id"] as? String,
                  let content = event.data["content"] as? String,
                  event.data["chat_id"] as? String == chatId else { return }
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].content = content
                messages[index].isEdited = true
            }

        case "message:deleted":
            guard let messageId = event.data["message_id"] as? String,
                  event.data["chat_id"] as? String == chatId else { return }
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].isDeleted = true
                messages[index].content = nil
            }

        case "message:reaction":
            guard let messageId = event.data["message_id"] as? String,
                  event.data["chat_id"] as? String == chatId,
                  let reactionsRaw = event.data["reactions"] as? [String: [String]] else { return }
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].reactions = reactionsRaw
            }

        case "message:read":
            guard event.data["chat_id"] as? String == chatId,
                  let messageId = event.data["message_id"] as? String,
                  let userId = event.data["user_id"] as? String else { return }
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                if !messages[index].readBy.contains(userId) {
                    messages[index].readBy.append(userId)
                }
            }

        case "typing:start":
            guard event.data["chat_id"] as? String == chatId,
                  let userId = event.data["user_id"] as? String,
                  userId != AuthManager.shared.currentUser?.id else { return }
            let name = members.first(where: { $0.id == userId })?.nameOrUsername ?? userId
            if !typingUserNames.contains(name) {
                typingUserNames.append(name)
            }

        case "typing:stop":
            guard event.data["chat_id"] as? String == chatId,
                  let userId = event.data["user_id"] as? String else { return }
            let name = members.first(where: { $0.id == userId })?.nameOrUsername ?? userId
            typingUserNames.removeAll { $0 == name }

        case "user:status":
            guard let userId = event.data["user_id"] as? String,
                  let status = event.data["status"] as? String else { return }
            if let index = chatDetail?.members.firstIndex(where: { $0.id == userId }) {
                chatDetail?.members[index].status = status
            }

        default:
            break
        }
    }

    deinit {
        typingTimer?.invalidate()
    }
}
