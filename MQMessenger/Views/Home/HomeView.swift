import SwiftUI

struct HomeView: View {
    @EnvironmentObject var chatsVM: ChatsViewModel
    @EnvironmentObject var contactsVM: ContactsViewModel
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showSearch = false
    @State private var showNewChat = false
    @State private var greeting: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    greetingHeader
                    storiesSection
                    quickActionsSection

                    if chatsVM.isLoading && chatsVM.chats.isEmpty {
                        ShimmerLoadingList(count: 4)
                            .glassCard(padding: 12)
                    } else {
                        recentChatsSection
                    }

                    contactsPreviewSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
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
            .onAppear { updateGreeting() }
            .refreshable {
                await chatsVM.loadChats()
                await contactsVM.loadContacts()
            }
        }
    }

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text(authManager.currentUser?.nameOrPhone ?? "MQ")
                    .font(.system(size: 22, weight: .bold))
            }

            Spacer()

            AvatarView(
                name: authManager.currentUser?.nameOrPhone ?? "",
                avatarURL: authManager.currentUser?.avatarURL,
                size: 44,
                showOnlineIndicator: true,
                isOnline: true
            )
        }
    }

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "stories".localized)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    Button(action: {}) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [themeManager.accentColor.opacity(0.15), themeManager.accentColor.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)

                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(themeManager.accentColor)
                            }

                            Text("add".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())

                    ForEach(sampleStoryUsers, id: \.self) { name in
                        VStack(spacing: 6) {
                            ZStack {
                                AnimatedGradientBorder(size: 68, lineWidth: 2)
                                AvatarView(name: name, avatarURL: nil, size: 60)
                            }

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
            QuickActionButton(icon: "square.and.pencil", title: "new_chat".localized, color: .blue) {
                chatsVM.showNewChatSheet = true
            }
            QuickActionButton(icon: "person.3.fill", title: "new_group".localized, color: .green) {
                chatsVM.showNewGroupSheet = true
            }
            QuickActionButton(icon: "megaphone.fill", title: "new_channel".localized, color: .purple) {
                chatsVM.showNewChannelSheet = true
            }
            QuickActionButton(icon: "person.badge.plus", title: "contacts".localized, color: .orange) {
                showSearch = true
            }
        }
    }

    private var recentChatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "chats".localized, count: chatsVM.chats.count)

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
                    .buttonStyle(ScaleButtonStyle(scale: 0.98))
                }
            }
        }
        .glassCard()
    }

    private var contactsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "contacts".localized, count: contactsVM.contacts.count)

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

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 {
            greeting = "good_night".localized
        } else if hour < 12 {
            greeting = "good_morning".localized
        } else if hour < 18 {
            greeting = "good_afternoon".localized
        } else {
            greeting = "good_evening".localized
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    var color: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
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
        .buttonStyle(BounceButtonStyle())
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
