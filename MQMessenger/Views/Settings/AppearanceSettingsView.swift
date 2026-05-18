import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                themeSection
                colorSection
                wallpaperSection
                fontSection
                cornerSection
                previewSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(themeManager.backgroundColor)
        .navigationTitle("chat_appearance".localized)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("theme".localized)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                ForEach(ThemeManager.themes, id: \.self) { theme in
                    Button(action: { themeManager.currentTheme = theme }) {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(theme == "dark" ? Color.black : (theme == "light" ? Color.white : Color(.systemGray4)))
                                    .frame(width: 64, height: 48)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                themeManager.currentTheme == theme
                                                    ? themeManager.accentColor
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )

                                if theme == "system" {
                                    HStack(spacing: 0) {
                                        Color.white.frame(width: 32)
                                        Color.black.frame(width: 32)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .frame(width: 64, height: 48)
                                }
                            }

                            Text(themeLabel(theme))
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.currentTheme == theme ? themeManager.accentColor : .secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .glassCard()
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("bubble_color".localized)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(ThemeManager.accentColors, id: \.self) { hex in
                    Button(action: { themeManager.accentColorHex = hex }) {
                        Circle()
                            .fill(Color(hex: hex) ?? .blue)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(
                                        themeManager.accentColorHex == hex
                                            ? Color.primary
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                                    .padding(2)
                            )
                            .overlay {
                                if themeManager.accentColorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                    }
                }
            }
        }
        .glassCard()
    }

    private var wallpaperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("wallpaper".localized)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemeManager.wallpapers, id: \.self) { name in
                        Button(action: { themeManager.wallpaperName = name }) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(wallpaperPreview(name))
                                .frame(width: 60, height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            themeManager.wallpaperName == name
                                                ? themeManager.accentColor
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("font_size".localized)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Int(themeManager.fontSize))")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            Slider(value: $themeManager.fontSize, in: 12...24, step: 1)
                .tint(themeManager.accentColor)

            HStack {
                Text("Aa")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Aa")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        }
        .glassCard()
    }

    private var cornerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("message_corners".localized)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Int(themeManager.messageCornerRadius))")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            Slider(value: $themeManager.messageCornerRadius, in: 4...24, step: 2)
                .tint(themeManager.accentColor)
        }
        .glassCard()
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Hello!")
                            .font(.system(size: themeManager.fontSize))
                            .foregroundColor(.primary)

                        Text("10:30")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        BubbleShape(isOwn: false, cornerRadius: themeManager.messageCornerRadius)
                            .fill(themeManager.incomingBubbleColor)
                    )

                    Spacer()
                }

                HStack {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Hi there! 👋")
                            .font(.system(size: themeManager.fontSize))
                            .foregroundColor(.white)

                        Text("10:31")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        BubbleShape(isOwn: true, cornerRadius: themeManager.messageCornerRadius)
                            .fill(themeManager.bubbleColor)
                    )
                }
            }
            .padding(12)
            .background(themeManager.wallpaperGradient())
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .glassCard()
    }

    private func themeLabel(_ theme: String) -> String {
        switch theme {
        case "light": return "light".localized
        case "dark": return "dark".localized
        default: return "system".localized
        }
    }

    private func wallpaperPreview(_ name: String) -> LinearGradient {
        switch name {
        case "gradient_blue": return LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)
        case "gradient_purple": return LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)
        case "gradient_green": return LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
        case "gradient_orange": return LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
        case "gradient_pink": return LinearGradient(colors: [.pink, .red], startPoint: .top, endPoint: .bottom)
        case "dark_space": return LinearGradient(colors: [.black, .gray], startPoint: .top, endPoint: .bottom)
        case "light_clouds": return LinearGradient(colors: [.white, .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom)
        default: return LinearGradient(colors: [Color(.systemGray5)], startPoint: .top, endPoint: .bottom)
        }
    }
}
