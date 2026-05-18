import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: String {
        didSet {
            UserDefaults.standard.set(currentTheme, forKey: "mq_theme")
        }
    }

    @Published var accentColorHex: String {
        didSet {
            UserDefaults.standard.set(accentColorHex, forKey: "mq_accent_color")
        }
    }

    @Published var wallpaperName: String {
        didSet {
            UserDefaults.standard.set(wallpaperName, forKey: "mq_wallpaper")
        }
    }

    @Published var fontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: "mq_font_size")
        }
    }

    @Published var messageCornerRadius: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(messageCornerRadius), forKey: "mq_corner_radius")
        }
    }

    var colorScheme: ColorScheme? {
        switch currentTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var isDark: Bool {
        currentTheme == "dark"
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? .blue
    }

    var bubbleColor: Color {
        accentColor.opacity(0.9)
    }

    var incomingBubbleColor: Color {
        isDark ? Color(.systemGray5) : Color(.systemGray6)
    }

    var backgroundColor: Color {
        isDark ? Color(.systemBackground) : .white
    }

    var cardBackground: Color {
        isDark ? Color(.secondarySystemBackground) : .white
    }

    var glassBackground: some ShapeStyle {
        isDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.thinMaterial)
    }

    static let wallpapers = [
        "default", "gradient_blue", "gradient_purple", "gradient_green",
        "gradient_orange", "gradient_pink", "dark_space", "light_clouds",
    ]

    static let accentColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF2D55",
        "#AF52DE", "#5856D6", "#FF3B30", "#00C7BE",
    ]

    static let themes = ["light", "dark", "system"]

    private init() {
        currentTheme = UserDefaults.standard.string(forKey: "mq_theme") ?? "light"
        accentColorHex = UserDefaults.standard.string(forKey: "mq_accent_color") ?? "#7C5CFC"
        wallpaperName = UserDefaults.standard.string(forKey: "mq_wallpaper") ?? "default"
        fontSize = CGFloat(UserDefaults.standard.double(forKey: "mq_font_size").nonZero ?? 16)
        messageCornerRadius = CGFloat(UserDefaults.standard.double(forKey: "mq_corner_radius").nonZero ?? 18)
    }

    func wallpaperGradient() -> LinearGradient {
        switch wallpaperName {
        case "gradient_blue":
            return LinearGradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gradient_purple":
            return LinearGradient(colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gradient_green":
            return LinearGradient(colors: [.green.opacity(0.3), .mint.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gradient_orange":
            return LinearGradient(colors: [.orange.opacity(0.3), .yellow.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gradient_pink":
            return LinearGradient(colors: [.pink.opacity(0.3), .red.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case "dark_space":
            return LinearGradient(colors: [.black, Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom)
        case "light_clouds":
            return LinearGradient(colors: [.white, .blue.opacity(0.1)],
                startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color(.systemGroupedBackground)],
                startPoint: .top, endPoint: .bottom)
        }
    }
}

extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
