import SwiftUI

struct AvatarView: View {
    let name: String
    let avatarURL: URL?
    var size: CGFloat = 48
    var showOnlineIndicator: Bool = false
    var isOnline: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderView
                    case .empty:
                        placeholderView
                            .overlay(ProgressView().scaleEffect(0.5))
                    @unknown default:
                        placeholderView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                placeholderView
            }

            if showOnlineIndicator && isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .offset(x: 1, y: 1)
            }
        }
    }

    private var placeholderView: some View {
        Circle()
            .fill(gradientForName)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            )
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.count > 1 ? parts[1].first.map(String.init) ?? "" : ""
        return (first + second).uppercased()
    }

    private var gradientForName: LinearGradient {
        let colors = avatarGradientColors
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var avatarGradientColors: [Color] {
        let hash = abs(name.hashValue)
        let gradients: [[Color]] = [
            [.blue, .cyan],
            [.purple, .pink],
            [.orange, .red],
            [.green, .mint],
            [.indigo, .purple],
            [.teal, .blue],
            [.pink, .orange],
            [.cyan, .green],
        ]
        return gradients[hash % gradients.count]
    }
}

struct AvatarGroupView: View {
    let names: [String]
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            ForEach(Array(names.prefix(3).enumerated()), id: \.offset) { index, name in
                AvatarView(name: name, avatarURL: nil, size: size * 0.65)
                    .offset(
                        x: CGFloat(index) * size * 0.2 - size * 0.15,
                        y: index == 1 ? -size * 0.15 : 0
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

struct LargeAvatarView: View {
    let name: String
    let avatarURL: URL?
    var size: CGFloat = 100
    var showEditButton: Bool = false
    var onEdit: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(name: name, avatarURL: avatarURL, size: size)

            if showEditButton {
                Button(action: { onEdit?() }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.15))
                        .foregroundColor(.white)
                        .padding(size * 0.08)
                        .background(
                            Circle()
                                .fill(Color.blue)
                                .shadow(radius: 2)
                        )
                }
                .offset(x: -2, y: -2)
            }
        }
    }
}

struct OnlineStatusDot: View {
    let isOnline: Bool
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(isOnline ? Color.green : Color.gray)
            .frame(width: size, height: size)
    }
}
