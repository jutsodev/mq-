import SwiftUI

struct HomeView: View {
    @EnvironmentObject var chatsVM: ChatsViewModel
    @EnvironmentObject var contactsVM: ContactsViewModel
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showSearch = false
    @State private var showNewChat = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    storiesSection
                    quickActionsSection
                    recentChatsSection
                    contactsPreviewSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("home".localized)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                UserSearchView()
                    .environmentObject(chatsVM)
            }
            .sheet(isPresented: $showNewChat) {
                NewChatActionSheet()
                    .environmentObject(chatsVM)
            }
        }
    }

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("stories".localized)
                .font(.system(size: 18, weight: .semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 64, height: 64)

                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(themeManager.accentColor)
                        }

                        Text("You")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    ForEach(sampleStoryUsers, id: \.self) { name in
                        VStack(spacing: 6) {
                            AvatarView(name: name, avatarURL: nil, size: 64)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                        .padding(-3)
                                )

                            Text(name)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "square.and.pencil", title: "new_chat".localized) {
                chatsVM.showNewChatSheet = true
            }
            QuickActionButton(icon: "person.3.fill", title: "new_group".localized) {
                chatsVM.showNewGroupSheet = true
            }
            QuickActionButton(icon: "megaphone.fill", title: "new_channel".localized) {
                chatsVM.showNewChannelSheet = true
            }
            QuickActionButton(icon: "person.badge.plus", title: "contacts".localized) {
                showSearch = true
            }
        }
    }

    private var recentChatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("chats".localized)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                if !chatsVM.chats.isEmpty {
                    Text("\(chatsVM.chats.count)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            if chatsVM.chats.isEmpty {
                EmptyStateView(
                    icon: "message",
                    title: "no_chats".localized,
                    subtitle: nil
                )
            } else {
                ForEach(chatsVM.chats.prefix(5)) { chat in
                    NavigationLink(destination: ChatRoomView(chatId: chat.id, chatName: chat.displayName)) {
                        ChatRowView(chat: chat)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard()
    }

    private var contactsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("contacts".localized)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("\(contactsVM.contacts.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            if contactsVM.contacts.isEmpty {
                Text("no_contacts".localized)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(contactsVM.contacts.prefix(3)) { contact in
                    HStack(spacing: 12) {
                        AvatarView(
                            name: contact.nameOrPhone,
                            avatarURL: nil,
                            size: 40,
                            showOnlineIndicator: true,
                            isOnline: contact.status == "online"
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.nameOrPhone)
                                .font(.system(size: 15, weight: .medium))

                            Text(contact.bio)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if contact.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .glassCard()
    }

    private var sampleStoryUsers: [String] {
        chatsVM.chats
            .filter { $0.isPrivate }
            .prefix(6)
            .map { $0.displayName }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassCard(padding: 0)
        }
    }
}

struct NewChatActionSheet: View {
    @EnvironmentObject var chatsVM: ChatsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            UserSearchView()
                .environmentObject(chatsVM)
                .navigationTitle("new_chat".localized)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("cancel".localized) { dismiss() }
                    }
                }
        }
    }
}
