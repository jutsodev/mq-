import SwiftUI

struct ChatsListView: View {
    @EnvironmentObject var chatsVM: ChatsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showNewGroup = false
    @State private var showNewChannel = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    GlassSearchBar(text: $chatsVM.searchQuery)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    if chatsVM.isLoading && chatsVM.chats.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if chatsVM.filteredChats.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "message",
                            title: "no_chats".localized,
                            subtitle: chatsVM.searchQuery.isEmpty ? nil : "no_results".localized
                        )
                        Spacer()
                    } else {
                        chatsList
                    }
                }
            }
            .navigationTitle("chats".localized)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { chatsVM.showNewChatSheet = true }) {
                            Label("new_chat".localized, systemImage: "square.and.pencil")
                        }
                        Button(action: { showNewGroup = true }) {
                            Label("new_group".localized, systemImage: "person.3")
                        }
                        Button(action: { showNewChannel = true }) {
                            Label("new_channel".localized, systemImage: "megaphone")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .sheet(isPresented: $chatsVM.showNewChatSheet) {
                NewChatActionSheet().environmentObject(chatsVM)
            }
            .sheet(isPresented: $showNewGroup) {
                CreateGroupView().environmentObject(chatsVM)
            }
            .sheet(isPresented: $showNewChannel) {
                CreateChannelView().environmentObject(chatsVM)
            }
            .refreshable {
                await chatsVM.loadChats()
            }
        }
    }

    private var chatsList: some View {
        List {
            if !chatsVM.pinnedChats.isEmpty {
                Section {
                    ForEach(chatsVM.pinnedChats) { chat in
                        chatNavigationLink(chat)
                    }
                } header: {
                    Label("pin".localized, systemImage: "pin.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                ForEach(chatsVM.unpinnedChats) { chat in
                    chatNavigationLink(chat)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func chatNavigationLink(_ chat: Chat) -> some View {
        NavigationLink(destination: ChatRoomView(chatId: chat.id, chatName: chat.displayName)) {
            ChatRowView(chat: chat)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await chatsVM.deleteChat(chat.id) }
            } label: {
                Label("delete".localized, systemImage: "trash")
            }

            Button {
                Task { await chatsVM.toggleMute(chat.id) }
            } label: {
                Label(
                    chat.isMuted ? "unmute".localized : "mute".localized,
                    systemImage: chat.isMuted ? "bell" : "bell.slash"
                )
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await chatsVM.togglePin(chat.id) }
            } label: {
                Label(
                    chat.isPinned ? "unpin".localized : "pin".localized,
                    systemImage: chat.isPinned ? "pin.slash" : "pin"
                )
            }
            .tint(.blue)

            Button {
                Task { await chatsVM.markRead(chat.id) }
            } label: {
                Label("read".localized, systemImage: "envelope.open")
            }
            .tint(.green)
        }
    }
}

struct ChatRowView: View {
    let chat: Chat
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if chat.isSaved {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.purple, .blue],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                } else if chat.isGroup || chat.isChannel {
                    AvatarView(
                        name: chat.displayName,
                        avatarURL: chat.avatarURL,
                        size: 52
                    )
                    .overlay(
                        Image(systemName: chat.isChannel ? "megaphone.fill" : "person.3.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.blue))
                            .offset(x: 18, y: 18),
                        alignment: .bottomTrailing
                    )
                } else {
                    AvatarView(
                        name: chat.displayName,
                        avatarURL: chat.avatarURL,
                        size: 52,
                        showOnlineIndicator: true,
                        isOnline: chat.members?.first(where: { $0.id != AuthManager.shared.currentUser?.id })?.status == "online"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 4) {
                        if chat.isMuted {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Text(chat.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(chat.lastMessageTime)
                        .font(.system(size: 13))
                        .foregroundColor(chat.unreadCount > 0 ? themeManager.accentColor : .secondary)
                }

                HStack {
                    if let lastMsg = chat.lastMessage {
                        HStack(spacing: 4) {
                            if chat.isGroup || chat.isChannel, let senderName = lastMsg.senderName {
                                Text("\(senderName):")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Text(chat.lastMessagePreview)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if chat.unreadCount > 0 {
                        BadgeView(count: chat.unreadCount, color: chat.isMuted ? .gray : themeManager.accentColor)
                    }

                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
