import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var filteredChats: [Chat] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var selectedChatId: String?
    @Published var showNewChatSheet = false
    @Published var showNewGroupSheet = false
    @Published var showNewChannelSheet = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSearchFilter()
        setupSocketListeners()
    }

    var pinnedChats: [Chat] {
        filteredChats.filter { $0.isPinned }
    }

    var unpinnedChats: [Chat] {
        filteredChats.filter { !$0.isPinned }
    }

    var totalUnreadCount: Int {
        chats.reduce(0) { $0 + $1.unreadCount }
    }

    func loadChats() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.getChats()
            chats = response.chats
            filterChats()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func createPrivateChat(userId: String) async -> String? {
        do {
            let response = try await APIService.shared.createChat(
                request: CreateChatRequest(type: "private", members: [userId]))
            await loadChats()
            return response.chatId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createGroup(name: String, description: String?, members: [String], isPublic: Bool) async -> String? {
        do {
            let response = try await APIService.shared.createChat(
                request: CreateChatRequest(type: "group", name: name, description: description,
                    members: members, isPublic: isPublic))
            await loadChats()
            return response.chatId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createChannel(name: String, description: String?, isPublic: Bool) async -> String? {
        do {
            let response = try await APIService.shared.createChat(
                request: CreateChatRequest(type: "channel", name: name, description: description,
                    isPublic: isPublic))
            await loadChats()
            return response.chatId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteChat(_ chatId: String) async {
        do {
            try await APIService.shared.deleteChat(chatId: chatId)
            chats.removeAll { $0.id == chatId }
            filterChats()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePin(_ chatId: String) async {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return }
        let isPinned = !chats[index].isPinned
        chats[index].isPinned = isPinned
        filterChats()

        do {
            try await APIService.shared.pinChat(chatId: chatId, isPinned: isPinned)
        } catch {
            chats[index].isPinned = !isPinned
            filterChats()
        }
    }

    func toggleMute(_ chatId: String) async {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return }
        let isMuted = !chats[index].isMuted
        chats[index].isMuted = isMuted

        do {
            try await APIService.shared.muteChat(chatId: chatId, isMuted: isMuted)
        } catch {
            chats[index].isMuted = !isMuted
        }
    }

    func markRead(_ chatId: String) async {
        guard let chat = chats.first(where: { $0.id == chatId }),
              let lastMsg = chat.lastMessage else { return }
        do {
            try await APIService.shared.markRead(chatId: chatId, messageId: lastMsg.id)
            if let index = chats.firstIndex(where: { $0.id == chatId }) {
                chats[index].unreadCount = 0
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinByInvite(_ link: String) async -> String? {
        do {
            let response = try await APIService.shared.joinByInvite(inviteLink: link)
            await loadChats()
            return response.chatId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func setupSearchFilter() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterChats()
            }
            .store(in: &cancellables)
    }

    private func filterChats() {
        if searchQuery.isEmpty {
            filteredChats = chats
        } else {
            let query = searchQuery.lowercased()
            filteredChats = chats.filter {
                ($0.name?.lowercased().contains(query) ?? false) ||
                ($0.lastMessage?.content?.lowercased().contains(query) ?? false)
            }
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
            guard let msg: Message = event.decode(Message.self) else { return }
            if let index = chats.firstIndex(where: { $0.id == msg.chatId }) {
                chats[index].lastMessage = msg
                if msg.senderId != AuthManager.shared.currentUser?.id && selectedChatId != msg.chatId {
                    chats[index].unreadCount += 1
                }
                chats[index].updatedAt = msg.createdAt
                sortChats()
                filterChats()
            } else {
                Task { await loadChats() }
            }

        case "message:deleted":
            if let chatId = event.data["chat_id"] as? String {
                Task { await loadChats() }
                _ = chatId
            }

        default:
            break
        }
    }

    private func sortChats() {
        chats.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }
}
