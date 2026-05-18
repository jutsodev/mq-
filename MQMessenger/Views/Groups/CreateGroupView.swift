import SwiftUI

struct CreateGroupView: View {
    @EnvironmentObject var chatsVM: ChatsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var selectedMembers: Set<String> = []
    @State private var searchQuery = ""
    @State private var searchResults: [User] = []
    @State private var isCreating = false
    @State private var step = 0

    var body: some View {
        NavigationStack {
            VStack {
                if step == 0 {
                    groupInfoStep
                } else {
                    memberSelectionStep
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("new_group".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == 0 ? "cancel".localized : "Back") {
                        if step == 0 { dismiss() } else { step = 0 }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        if step == 0 {
                            step = 1
                        } else {
                            createGroup()
                        }
                    }) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text(step == 0 ? "continue".localized : "create".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private var groupInfoStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 30))
                        .foregroundColor(themeManager.accentColor)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("group_name".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("group_name".localized, text: $name)
                            .font(.system(size: 16))
                            .glassTextField()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("description".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("description".localized, text: $description, axis: .vertical)
                            .font(.system(size: 16))
                            .lineLimit(3...6)
                            .glassTextField()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: isPublic ? "globe" : "lock.fill")
                            .foregroundColor(themeManager.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isPublic ? "public_group".localized : "private_group".localized)
                                .font(.system(size: 15, weight: .medium))
                        }

                        Spacer()

                        Toggle("", isOn: $isPublic)
                            .labelsHidden()
                            .tint(themeManager.accentColor)
                    }
                    .glassTextField()
                }
                .padding(.horizontal, 16)
                .glassCard()
                .padding(.horizontal, 16)
            }
        }
    }

    private var memberSelectionStep: some View {
        VStack(spacing: 0) {
            GlassSearchBar(text: $searchQuery, placeholder: "search_users".localized)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onChange(of: searchQuery) { _ in searchUsers() }

            if !selectedMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedMembers), id: \.self) { memberId in
                            HStack(spacing: 4) {
                                Text(memberId.prefix(8))
                                    .font(.system(size: 12))
                                Button(action: { selectedMembers.remove(memberId) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            List(searchResults) { user in
                Button(action: {
                    if selectedMembers.contains(user.id) {
                        selectedMembers.remove(user.id)
                    } else {
                        selectedMembers.insert(user.id)
                    }
                }) {
                    HStack(spacing: 12) {
                        AvatarView(name: user.nameOrPhone, avatarURL: user.avatarURL, size: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.nameOrPhone)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)

                            if let username = user.username {
                                Text("@\(username)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if selectedMembers.contains(user.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(themeManager.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func searchUsers() {
        guard !searchQuery.isEmpty else { searchResults = []; return }
        Task {
            do {
                let response = try await APIService.shared.searchUsers(query: searchQuery)
                searchResults = response.users
            } catch {}
        }
    }

    private func createGroup() {
        isCreating = true
        Task {
            if let _ = await chatsVM.createGroup(
                name: name,
                description: description.isEmpty ? nil : description,
                members: Array(selectedMembers),
                isPublic: isPublic
            ) {
                dismiss()
            }
            isCreating = false
        }
    }
}

struct CreateChannelView: View {
    @EnvironmentObject var chatsVM: ChatsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = true
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)

                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 30))
                            .foregroundColor(themeManager.accentColor)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("channel_name".localized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            TextField("channel_name".localized, text: $name)
                                .font(.system(size: 16))
                                .glassTextField()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("description".localized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            TextField("description".localized, text: $description, axis: .vertical)
                                .font(.system(size: 16))
                                .lineLimit(3...6)
                                .glassTextField()
                        }

                        HStack(spacing: 12) {
                            Image(systemName: isPublic ? "globe" : "lock.fill")
                                .foregroundColor(themeManager.accentColor)

                            Text(isPublic ? "public_group".localized : "private_group".localized)
                                .font(.system(size: 15, weight: .medium))

                            Spacer()

                            Toggle("", isOn: $isPublic)
                                .labelsHidden()
                                .tint(themeManager.accentColor)
                        }
                        .glassTextField()
                    }
                    .padding(.horizontal, 16)
                    .glassCard()
                    .padding(.horizontal, 16)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("new_channel".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: createChannel) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("create".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private func createChannel() {
        isCreating = true
        Task {
            if let _ = await chatsVM.createChannel(
                name: name,
                description: description.isEmpty ? nil : description,
                isPublic: isPublic
            ) {
                dismiss()
            }
            isCreating = false
        }
    }
}

struct GroupInfoView: View {
    let chatId: String
    let detail: ChatDetailResponse
    @ObservedObject var vm: ChatRoomViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        AvatarView(
                            name: detail.chat.name ?? "Chat",
                            avatarURL: detail.chat.avatarURL,
                            size: 80
                        )

                        Text(detail.chat.name ?? "Chat")
                            .font(.system(size: 22, weight: .bold))

                        if let desc = detail.chat.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 16) {
                            Text("\(detail.members.count) \("members".localized)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            if detail.chat.isPublic {
                                Label("public_group".localized, systemImage: "globe")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .glassCard()

                    if let link = detail.chat.inviteLink {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(themeManager.accentColor)
                            Text(link)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = link
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .glassCard()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\("members".localized) (\(detail.members.count))")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            if vm.isAdmin {
                                Button("add_members".localized) {}
                                    .font(.system(size: 14))
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }

                        VStack(spacing: 1) {
                            ForEach(detail.members) { member in
                                HStack(spacing: 12) {
                                    AvatarView(name: member.nameOrUsername, avatarURL: nil, size: 40,
                                        showOnlineIndicator: true, isOnline: member.status == "online")

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.nameOrUsername)
                                            .font(.system(size: 15, weight: .medium))

                                        if let role = member.role, role != "member" {
                                            Text(role.localized)
                                                .font(.system(size: 12))
                                                .foregroundColor(themeManager.accentColor)
                                        }
                                    }

                                    Spacer()

                                    OnlineStatusDot(isOnline: member.status == "online", size: 8)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .glassCard()

                    Button(action: {
                        Task {
                            await vm.leaveChat()
                            dismiss()
                        }
                    }) {
                        Label("leave_group".localized, systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(isDestructive: true))
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(themeManager.backgroundColor)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }
}
