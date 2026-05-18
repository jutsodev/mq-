import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isOwnMessage: Bool
    var onReply: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onReact: (String) -> Void
    var onPin: () -> Void
    var onStar: () -> Void
    var onCopy: () -> Void
    var onForward: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var showActions = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOwnMessage { Spacer(minLength: 60) }

            if !isOwnMessage && message.senderName != nil {
                AvatarView(name: message.senderName ?? "", avatarURL: nil, size: 28)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                if let replyTo = message.replyTo {
                    replyPreview(replyTo)
                }

                if message.isDeleted {
                    deletedBubble
                } else if let content = message.content {
                    textBubble(content)
                } else if message.isMedia, let url = message.mediaFullURL {
                    mediaBubble(url)
                }

                if message.forwardedFrom != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.system(size: 10))
                        Text("forward".localized)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }

                if !message.reactions.isEmpty {
                    reactionsView
                }
            }
            .contextMenu {
                contextMenuItems
            }

            if !isOwnMessage { Spacer(minLength: 60) }
        }
        .padding(.vertical, 1)
    }

    private func replyPreview(_ reply: ReplyPreview) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(themeManager.accentColor)
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.senderName ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.accentColor)

                Text(reply.content ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5).opacity(0.5))
        )
    }

    private var deletedBubble: some View {
        HStack(spacing: 4) {
            Image(systemName: "nosign")
                .font(.system(size: 13))
            Text("deleted_message".localized)
                .font(.system(size: 14, design: .default).italic())
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            BubbleShape(isOwn: isOwnMessage, cornerRadius: themeManager.messageCornerRadius)
                .fill(Color(.systemGray5).opacity(0.5))
        )
    }

    private func textBubble(_ content: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !isOwnMessage, let name = message.senderName,
               message.chatId != "" {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.accentColor)
            }

            Text(content)
                .font(.system(size: themeManager.fontSize))
                .foregroundColor(isOwnMessage ? .white : .primary)
                .textSelection(.enabled)

            HStack(spacing: 4) {
                if message.isEdited {
                    Text("edited".localized)
                        .font(.system(size: 10))
                }

                Text(message.timeFormatted)
                    .font(.system(size: 11))

                if isOwnMessage {
                    messageStatusIcon
                }
            }
            .foregroundColor(isOwnMessage ? .white.opacity(0.7) : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            BubbleShape(isOwn: isOwnMessage, cornerRadius: themeManager.messageCornerRadius)
                .fill(isOwnMessage ? themeManager.bubbleColor : themeManager.incomingBubbleColor)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    private func mediaBubble(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: themeManager.messageCornerRadius))
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                    .frame(width: 160, height: 120)
            case .empty:
                ProgressView()
                    .frame(width: 160, height: 120)
            @unknown default:
                EmptyView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                Text(message.timeFormatted)
                    .font(.system(size: 11))
                if isOwnMessage { messageStatusIcon }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.4)))
            .padding(8)
        }
    }

    private var messageStatusIcon: some View {
        Group {
            if message.readBy.count > 1 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
            } else if !message.deliveredTo.isEmpty {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12))
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 10))
            }
        }
    }

    private var reactionsView: some View {
        HStack(spacing: 4) {
            ForEach(Array(message.reactions.keys.sorted()), id: \.self) { emoji in
                let users = message.reactions[emoji] ?? []
                Button(action: { onReact(emoji) }) {
                    HStack(spacing: 2) {
                        Text(emoji)
                            .font(.system(size: 14))
                        if users.count > 1 {
                            Text("\(users.count)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(users.contains(AuthManager.shared.currentUser?.id ?? "")
                                ? themeManager.accentColor.opacity(0.2)
                                : Color(.systemGray5))
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onReply) {
            Label("reply".localized, systemImage: "arrowshape.turn.up.left")
        }

        Button(action: onCopy) {
            Label("copy".localized, systemImage: "doc.on.doc")
        }

        Button(action: onForward) {
            Label("forward".localized, systemImage: "arrowshape.turn.up.right")
        }

        if isOwnMessage {
            Button(action: onEdit) {
                Label("edit".localized, systemImage: "pencil")
            }
        }

        Button(action: onPin) {
            Label(
                message.isPinned ? "unpin".localized : "pin".localized,
                systemImage: message.isPinned ? "pin.slash" : "pin"
            )
        }

        Button(action: onStar) {
            Label(
                message.isStarred ? "unstar".localized : "star".localized,
                systemImage: message.isStarred ? "star.slash" : "star"
            )
        }

        Menu {
            ForEach(["👍", "❤️", "😂", "😮", "😢", "🔥", "👎"], id: \.self) { emoji in
                Button(emoji) { onReact(emoji) }
            }
        } label: {
            Label("Reaction", systemImage: "face.smiling")
        }

        if isOwnMessage || message.senderId == AuthManager.shared.currentUser?.id {
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("delete".localized, systemImage: "trash")
            }
        }
    }
}

struct BubbleShape: Shape {
    let isOwn: Bool
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        if isOwn {
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r / 2))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - r / 2, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + r / 2, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r / 2),
                control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}
