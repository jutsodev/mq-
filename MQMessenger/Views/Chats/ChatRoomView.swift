import SwiftUI

struct ChatRoomView: View {
    let chatId: String
    let chatName: String
    @StateObject private var vm: ChatRoomViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var showScrollToBottom = false
    @State private var showToast = false
    @State private var toastMessage = ""

    init(chatId: String, chatName: String) {
        self.chatId = chatId
        self.chatName = chatName
        _vm = StateObject(wrappedValue: ChatRoomViewModel(chatId: chatId))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                messagesView
                if vm.canPost {
                    MessageInputView(vm: vm)
                }
            }

            if showScrollToBottom {
                scrollToBottomButton
                    .padding(.bottom, 70)
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.scale.combined(with: .opacity))
            }

            if showToast {
                ToastView(message: toastMessage, icon: "checkmark.circle.fill")
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showToast = false }
                        }
                    }
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
        .sheet(isPresented: $vm.showForwardSheet) {
            ForwardMessageSheet(vm: vm)
        }
        .alert("error".localized, isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var chatHeader: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            vm.showChatInfo = true
        }) {
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
                        .foregroundColor(themeManager.accentColor)
                    } else if let detail = vm.chatDetail {
                        if detail.chat.isPrivate {
                            let other = detail.members.first { $0.id != AuthManager.shared.currentUser?.id }
                            HStack(spacing: 4) {
                                if other?.status == "online" {
                                    PulsingDot(color: .green, size: 6)
                                }
                                Text(other?.status == "online" ? "online".localized : "offline".localized)
                            }
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
                    if vm.hasMoreMessages {
                        Button(action: { Task { await vm.loadMoreMessages() } }) {
                            if vm.isLoading {
                                ProgressView()
                                    .padding()
                            } else {
                                Text("load_more".localized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(themeManager.accentColor)
                                    .padding(.vertical, 12)
                            }
                        }
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
                                onPin: {
                                    Task {
                                        await vm.pinMessage(message.id)
                                        showToastMessage("pin".localized)
                                    }
                                },
                                onStar: { Task { await vm.starMessage(message.id) } },
                                onCopy: {
                                    vm.copyMessage(message)
                                    showToastMessage("copied".localized)
                                },
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

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func dateHeader(_ date: String) -> some View {
        HStack {
            Spacer()
            Text(date)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                )
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var scrollToBottomButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.accentColor)
            }
        }
    }

    private var chatMenu: some View {
        Menu {
            Button(action: { vm.showChatInfo = true }) {
                Label("info".localized, systemImage: "info.circle")
            }

            if vm.isAdmin {
                Button(action: {}) {
                    Label("add_members".localized, systemImage: "person.badge.plus")
                }
            }

            Button(action: {}) {
                Label("search".localized, systemImage: "magnifyingglass")
            }

            Button(action: {}) {
                Label("mute".localized, systemImage: "bell.slash")
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

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.3)) {
            showToast = true
        }
    }
}

struct ForwardMessageSheet: View {
    @ObservedObject var vm: ChatRoomViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Text("forward".localized)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .navigationTitle("forward".localized)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("cancel".localized) { dismiss() }
                    }
                }
        }
    }
}
