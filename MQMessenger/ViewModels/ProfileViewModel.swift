import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var displayName = ""
    @Published var username = ""
    @Published var bio = ""
    @Published var showImagePicker = false
    @Published var selectedImageData: Data?
    @Published var isSaving = false
    @Published var saveSuccess = false

    func loadProfile() async {
        isLoading = true
        do {
            let response = try await APIService.shared.getProfile()
            user = response.user
            displayName = response.user.displayName ?? ""
            username = response.user.username ?? ""
            bio = response.user.bio
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func saveProfile() async {
        isSaving = true
        saveSuccess = false
        var updates: [String: Any] = [:]

        if displayName != (user?.displayName ?? "") { updates["display_name"] = displayName }
        if username != (user?.username ?? "") { updates["username"] = username }
        if bio != user?.bio { updates["bio"] = bio }

        if let imageData = selectedImageData {
            do {
                let uploadResp = try await APIService.shared.uploadAvatar(
                    data: imageData, filename: "avatar.jpg")
                updates["avatar"] = uploadResp.url
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                return
            }
        }

        guard !updates.isEmpty else { isSaving = false; return }

        do {
            try await AuthManager.shared.updateProfile(updates)
            user = AuthManager.shared.currentUser
            isSaving = false
            saveSuccess = true
            selectedImageData = nil
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }

    func updateSetting(_ key: String, value: Any) async {
        do {
            try await AuthManager.shared.updateProfile([key: value])
            user = AuthManager.shared.currentUser
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enableTwoStep(pin: String) async {
        do {
            try await APIService.shared.enableTwoStep(pin: pin)
            user?.twoStepEnabled = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disableTwoStep() async {
        do {
            try await APIService.shared.disableTwoStep()
            user?.twoStepEnabled = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var favoriteContacts: [Contact] {
        contacts.filter { $0.isFavorite }
    }

    var regularContacts: [Contact] {
        contacts.filter { !$0.isFavorite && !$0.isBlocked }
    }

    var blockedContacts: [Contact] {
        contacts.filter { $0.isBlocked }
    }

    func loadContacts() async {
        isLoading = true
        do {
            let response = try await APIService.shared.getContacts()
            contacts = response.contacts
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func addContact(_ userId: String, nickname: String? = nil) async {
        do {
            try await APIService.shared.addContact(contactId: userId, nickname: nickname)
            await loadContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteContact(_ contactId: String) async {
        do {
            try await APIService.shared.deleteContact(contactId: contactId)
            contacts.removeAll { $0.id == contactId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite(_ contactId: String) async {
        guard let index = contacts.firstIndex(where: { $0.id == contactId }) else { return }
        let newValue = !contacts[index].isFavorite
        contacts[index].isFavorite = newValue
        do {
            try await APIService.shared.toggleFavorite(contactId: contactId, isFavorite: newValue)
        } catch {
            contacts[index].isFavorite = !newValue
        }
    }

    func toggleBlock(_ contactId: String) async {
        guard let index = contacts.firstIndex(where: { $0.id == contactId }) else { return }
        let newValue = !contacts[index].isBlocked
        contacts[index].isBlocked = newValue
        do {
            try await APIService.shared.toggleBlock(contactId: contactId, isBlocked: newValue)
        } catch {
            contacts[index].isBlocked = !newValue
        }
    }
}

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSocketListeners()
    }

    func loadNotifications() async {
        isLoading = true
        do {
            let response = try await APIService.shared.getNotifications()
            notifications = response.notifications
            unreadCount = response.unreadCount
            NotificationManager.shared.updateBadgeCount(unreadCount)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func markAsRead(_ notificationId: String) async {
        do {
            try await APIService.shared.markNotificationRead(notificationId: notificationId)
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[index].isRead = true
                unreadCount = max(0, unreadCount - 1)
                NotificationManager.shared.updateBadgeCount(unreadCount)
            }
        } catch {}
    }

    func markAllAsRead() async {
        do {
            try await APIService.shared.markAllNotificationsRead()
            for i in notifications.indices {
                notifications[i].isRead = true
            }
            unreadCount = 0
            NotificationManager.shared.clearBadge()
        } catch {}
    }

    func deleteNotification(_ notificationId: String) async {
        do {
            try await APIService.shared.deleteNotification(notificationId: notificationId)
            let wasUnread = notifications.first(where: { $0.id == notificationId })?.isRead == false
            notifications.removeAll { $0.id == notificationId }
            if wasUnread { unreadCount = max(0, unreadCount - 1) }
        } catch {}
    }

    func clearAll() async {
        do {
            try await APIService.shared.clearAllNotifications()
            notifications.removeAll()
            unreadCount = 0
            NotificationManager.shared.clearBadge()
        } catch {}
    }

    private func setupSocketListeners() {
        WebSocketService.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                if event.name == "notification:new" {
                    self?.unreadCount += 1
                    NotificationManager.shared.updateBadgeCount(self?.unreadCount ?? 0)
                    Task { await self?.loadNotifications() }
                }
            }
            .store(in: &cancellables)
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [User] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        guard !query.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            isSearching = true
            do {
                let response = try await APIService.shared.searchUsers(query: query)
                if !Task.isCancelled {
                    results = response.users
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            isSearching = false
        }
    }
}
