import SwiftUI

struct NotificationsListView: View {
    @EnvironmentObject var notificationsVM: NotificationsViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColor.ignoresSafeArea()

                if notificationsVM.isLoading && notificationsVM.notifications.isEmpty {
                    ProgressView()
                } else if notificationsVM.notifications.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "no_notifications".localized,
                        subtitle: nil
                    )
                } else {
                    notificationsList
                }
            }
            .navigationTitle("notifications".localized)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            Task { await notificationsVM.markAllAsRead() }
                        }) {
                            Label("read".localized, systemImage: "envelope.open")
                        }

                        Button(role: .destructive, action: {
                            Task { await notificationsVM.clearAll() }
                        }) {
                            Label("delete".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .refreshable {
                await notificationsVM.loadNotifications()
            }
        }
    }

    private var notificationsList: some View {
        List {
            ForEach(notificationsVM.notifications) { notification in
                notificationRow(notification)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await notificationsVM.deleteNotification(notification.id) }
                        } label: {
                            Label("delete".localized, systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !notification.isRead {
                            Button {
                                Task { await notificationsVM.markAsRead(notification.id) }
                            } label: {
                                Label("read".localized, systemImage: "envelope.open")
                            }
                            .tint(.blue)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(notificationColor(notification.type).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: notification.icon)
                    .font(.system(size: 18))
                    .foregroundColor(notificationColor(notification.type))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title ?? notification.type)
                        .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(notification.timeFormatted)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if let body = notification.body {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if !notification.isRead {
                Circle()
                    .fill(themeManager.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            handleNotificationTap(notification)
        }
    }

    private func notificationColor(_ type: String) -> Color {
        switch type {
        case "message": return .blue
        case "group_invite": return .green
        case "call": return .orange
        case "mention": return .purple
        case "reaction": return .red
        case "contact": return .cyan
        default: return .gray
        }
    }

    private func handleNotificationTap(_ notification: AppNotification) {
        Task {
            if !notification.isRead {
                await notificationsVM.markAsRead(notification.id)
            }
            if let chatId = notification.data.chatId {
                NotificationCenter.default.post(
                    name: .openChat,
                    object: nil,
                    userInfo: ["chat_id": chatId]
                )
            }
        }
    }
}
