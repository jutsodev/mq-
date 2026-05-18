import SwiftUI

struct ContactsView: View {
    @EnvironmentObject var contactsVM: ContactsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSearch = false
    @State private var searchQuery = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassSearchBar(text: $searchQuery, placeholder: "search".localized)
                        .padding(.horizontal, 16)

                    if contactsVM.isLoading {
                        ProgressView()
                            .padding(40)
                    } else if contactsVM.contacts.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "no_contacts".localized,
                            subtitle: nil
                        )
                    } else {
                        if !filteredFavorites.isEmpty {
                            contactSection(title: "favorites".localized, contacts: filteredFavorites)
                        }
                        if !filteredRegular.isEmpty {
                            contactSection(title: "contacts".localized, contacts: filteredRegular)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("contacts".localized)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                UserSearchView()
            }
            .refreshable {
                await contactsVM.loadContacts()
            }
        }
    }

    private var filteredFavorites: [Contact] {
        let fav = contactsVM.favoriteContacts
        if searchQuery.isEmpty { return fav }
        return fav.filter { $0.nameOrPhone.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var filteredRegular: [Contact] {
        let reg = contactsVM.regularContacts
        if searchQuery.isEmpty { return reg }
        return reg.filter { $0.nameOrPhone.localizedCaseInsensitiveContains(searchQuery) }
    }

    private func contactSection(title: String, contacts: [Contact]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            VStack(spacing: 1) {
                ForEach(contacts) { contact in
                    contactRow(contact)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .liquidGlass(cornerRadius: 16)
            .padding(.horizontal, 16)
        }
    }

    private func contactRow(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                name: contact.nameOrPhone,
                avatarURL: nil,
                size: 44,
                showOnlineIndicator: true,
                isOnline: contact.status == "online"
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(contact.nameOrPhone)
                        .font(.system(size: 15, weight: .medium))

                    if contact.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                    }
                }

                Text(contact.bio)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            OnlineStatusDot(isOnline: contact.status == "online", size: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                guard let id = contact.id else { return }
                Task { await contactsVM.deleteContact(id) }
            } label: {
                Label("delete".localized, systemImage: "trash")
            }

            Button {
                guard let id = contact.id else { return }
                Task { await contactsVM.toggleBlock(id) }
            } label: {
                Label("block".localized, systemImage: "hand.raised")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                guard let id = contact.id else { return }
                Task { await contactsVM.toggleFavorite(id) }
            } label: {
                Label(
                    contact.isFavorite ? "unstar".localized : "star".localized,
                    systemImage: contact.isFavorite ? "star.slash" : "star"
                )
            }
            .tint(.yellow)
        }
    }
}

struct UserSearchView: View {
    @StateObject private var vm = SearchViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedUserId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GlassSearchBar(
                    text: $vm.query,
                    placeholder: "search_users".localized,
                    onCommit: { vm.search() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onChange(of: vm.query) { _, _ in vm.search() }

                if vm.isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if vm.results.isEmpty && !vm.query.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "magnifyingglass", title: "no_results".localized, subtitle: nil)
                    Spacer()
                } else {
                    List(vm.results) { user in
                        NavigationLink(destination: UserDetailView(userId: user.id)) {
                            HStack(spacing: 12) {
                                AvatarView(
                                    name: user.nameOrPhone,
                                    avatarURL: user.avatarURL,
                                    size: 48,
                                    showOnlineIndicator: true,
                                    isOnline: user.isOnline
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.nameOrPhone)
                                        .font(.system(size: 16, weight: .medium))

                                    if let username = user.username {
                                        Text("@\(username)")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.accentColor)
                                    }

                                    Text(user.bio)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("search_users".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
            }
        }
    }
}

struct UserDetailView: View {
    let userId: String
    @State private var user: User?
    @State private var isLoading = true
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(60)
            } else if let user = user {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        AvatarView(name: user.nameOrPhone, avatarURL: user.avatarURL, size: 100)

                        Text(user.nameOrPhone)
                            .font(.system(size: 24, weight: .bold))

                        if let username = user.username {
                            Text("@\(username)")
                                .font(.system(size: 16))
                                .foregroundColor(themeManager.accentColor)
                        }

                        HStack(spacing: 4) {
                            OnlineStatusDot(isOnline: user.isOnline)
                            Text(user.isOnline ? "online".localized : "\("last_seen".localized) \(user.lastSeenFormatted)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .glassCard()

                    if !user.bio.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("bio".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(user.bio)
                                .font(.system(size: 15))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    }

                    VStack(spacing: 12) {
                        Button(action: { startChat() }) {
                            Label("new_chat".localized, systemImage: "message.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LiquidGlassButtonStyle())

                        HStack(spacing: 12) {
                            Button(action: { addContact() }) {
                                Label("add_contact".localized, systemImage: "person.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LiquidGlassButtonStyle())

                            Button(action: {}) {
                                Label("voice_call".localized, systemImage: "phone.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LiquidGlassButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .background(themeManager.backgroundColor)
        .task { await loadUser() }
    }

    private func loadUser() async {
        do {
            let response = try await APIService.shared.getUserProfile(userId: userId)
            user = response.user
            isLoading = false
        } catch {
            isLoading = false
        }
    }

    private func startChat() {
        Task {
            let chatsVM = ChatsViewModel()
            if let chatId = await chatsVM.createPrivateChat(userId: userId) {
                NotificationCenter.default.post(
                    name: .openChat,
                    object: nil,
                    userInfo: ["chat_id": chatId]
                )
                dismiss()
            }
        }
    }

    private func addContact() {
        Task {
            try? await APIService.shared.addContact(contactId: userId)
        }
    }
}
