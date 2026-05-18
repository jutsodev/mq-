import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var chatsVM = ChatsViewModel()
    @StateObject private var notificationsVM = NotificationsViewModel()
    @StateObject private var contactsVM = ContactsViewModel()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .environmentObject(chatsVM)
                .environmentObject(contactsVM)
                .tabItem {
                    Label("home".localized, systemImage: "house.fill")
                }
                .tag(0)

            ChatsListView()
                .environmentObject(chatsVM)
                .tabItem {
                    Label("chats".localized, systemImage: "message.fill")
                }
                .badge(chatsVM.totalUnreadCount)
                .tag(1)

            NotificationsListView()
                .environmentObject(notificationsVM)
                .tabItem {
                    Label("notifications".localized, systemImage: "bell.fill")
                }
                .badge(notificationsVM.unreadCount)
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("profile".localized, systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(themeManager.accentColor)
        .onAppear {
            Task {
                await chatsVM.loadChats()
                await notificationsVM.loadNotifications()
                await contactsVM.loadContacts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChat)) { notification in
            if let chatId = notification.userInfo?["chat_id"] as? String {
                chatsVM.selectedChatId = chatId
                selectedTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshChats)) { _ in
            Task { await chatsVM.loadChats() }
        }
    }
}
