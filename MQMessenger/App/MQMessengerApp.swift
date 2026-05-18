import SwiftUI

@main
struct MQMessengerApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localization = LocalizationManager.shared

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                        .environmentObject(localization)
                        .onAppear {
                            WebSocketService.shared.connect(token: authManager.token ?? "")
                            NotificationManager.shared.requestPermission()
                        }
                } else {
                    LoginView()
                        .environmentObject(authManager)
                        .environmentObject(themeManager)
                        .environmentObject(localization)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        }
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
