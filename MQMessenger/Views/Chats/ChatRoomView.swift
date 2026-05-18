import SwiftUI

struct ChatRoomView: View {
    let chatId: String
    let chatName: String
    @StateObject private var vm: ChatRoomViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    init(chatId: String, chatName: String) {
        self.chatId = chatId
        self.chatName = chatName
        _vm = StateObject(wrappedValue: ChatRoomViewModel(chatId: chatId))
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesView
            if vm.canPost {
                MessageInputView(vm: vm)
            }
        }
        .background(themeManager.wallpaperGradient().ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                chatHeader
            }
            ToolbarItem(placement: .topBarTrailing) {
                chatMenu
            }
        }
        .task { await vm.loadInitial() }
        .sheet(isPresented: $vm.showChatInfo) {
            if let detail = vm.chatDetail {
                GroupInfoView(chatId: chatId, detail: detail, vm: vm)
            }
        }
        .alert("error".localized, isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var chatHeader: some View {
        Button(action: { vm.showChatInfo = true }) {
            VStack(spacing: 2) {
                Text(chatName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Group {
                    if !vm.typingUserNames.isEmpty {
                        HStack(spacing: 4) {
                            TypingIndicator()
                            Text(vm.typingUserNames.joined(separator: ", "))
                        }
                    } else if let detail = vm.chatDetail {
                        if detail.chat.isPrivate {
                            let other = detail.members.first { $0.id != AuthManager.shared.currentUser?.id }
                            Text(other?.status == "online" ? "online".localized : "offline".localized)
                        } else {
                            Text("\(detail.members.count) \("members".localized)")
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if vm.isLoading {
                        ProgressView()
                            .padding()
                    }

                    ForEach(vm.groupedMessages, id: \.0) { date, msgs in
                        dateHeader(date)

                        ForEach(msgs) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == AuthManager.shared.currentUser?.id,
                                onReply: { vm.startReply(message) },
                                onEdit: { vm.startEdit(message) },
                                onDelete: { Task { await vm.deleteMessage(message.id) } },
                                onReact: { emoji in Task { await vm.reactToMessage(message.id, emoji: emoji) } },
                                onPin: { Task { await vm.pinMessage(message.id) } },
                                onStar: { Task { await vm.starMessage(message.id) } },
                                onCopy: { vm.copyMessage(message) },
                                onForward: {
                                    vm.forwardingMessage = message
                                    vm.showForwardSheet = true
                                }
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                if let lastId = vm.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func dateHeader(_ date: String) -> some View {
        Text(date)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.ultraThinMaterial))
            .padding(.vertical, 8)
    }

    private var chatMenu: some View {
        Menu {
            Button(action: { vm.showChatInfo = true }) {
                Label("info", systemImage: "info.circle")
            }

            if vm.isAdmin {
                Button(action: {}) {
                    Label("add_members".localized, systemImage: "person.badge.plus")
                }
            }

            Divider()

            Button(role: .destructive, action: {
                Task {
                    await vm.leaveChat()
                    dismiss()
                }
            }) {
                Label("leave_group".localized, systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
                .foregroundColor(themeManager.accentColor)
        }
    }
}
