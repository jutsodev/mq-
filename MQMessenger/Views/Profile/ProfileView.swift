import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var vm = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileHeaderCard
                    infoSection
                    settingsSection
                    logoutButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("profile".localized)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showEditProfile = true }) {
                        Text("edit".localized)
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(vm: vm)
            }
            .task { await vm.loadProfile() }
        }
    }

    private var profileHeaderCard: some View {
        VStack(spacing: 16) {
            LargeAvatarView(
                name: authManager.currentUser?.nameOrPhone ?? "",
                avatarURL: authManager.currentUser?.avatarURL,
                size: 100,
                showEditButton: true,
                onEdit: { showEditProfile = true }
            )

            VStack(spacing: 4) {
                Text(authManager.currentUser?.nameOrPhone ?? "")
                    .font(.system(size: 24, weight: .bold))

                if let username = authManager.currentUser?.username {
                    Text("@\(username)")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.accentColor)
                }
            }

            if let bio = authManager.currentUser?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var infoSection: some View {
        VStack(spacing: 1) {
            infoRow(icon: "phone.fill", label: "phone".localized,
                value: authManager.currentUser?.phone ?? "")
            infoRow(icon: "person.fill", label: "username".localized,
                value: "@\(authManager.currentUser?.username ?? "")")
            infoRow(icon: "text.quote", label: "bio".localized,
                value: authManager.currentUser?.bio ?? "")
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .liquidGlass(cornerRadius: 16)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeManager.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 15))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var settingsSection: some View {
        VStack(spacing: 1) {
            NavigationLink(destination: PrivacySettingsView(vm: vm)) {
                settingsRow(icon: "lock.fill", label: "privacy_security".localized, color: .blue)
            }

            NavigationLink(destination: ConfidentialityView(vm: vm)) {
                settingsRow(icon: "shield.fill", label: "confidentiality".localized, color: .green)
            }

            NavigationLink(destination: AppearanceSettingsView()) {
                settingsRow(icon: "paintbrush.fill", label: "chat_appearance".localized, color: .purple)
            }

            NavigationLink(destination: NotificationSettingsView(vm: vm)) {
                settingsRow(icon: "bell.fill", label: "notification_settings".localized, color: .red)
            }

            NavigationLink(destination: LanguageSettingsView()) {
                settingsRow(icon: "globe", label: "language".localized, color: .orange)
            }

            settingsRow(icon: "externaldrive.fill", label: "data_storage".localized, color: .cyan)

            HStack {
                settingsRow(icon: "questionmark.circle.fill", label: "help".localized, color: .gray)
            }

            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 28)

                Text("version".localized)
                    .font(.system(size: 15))

                Spacer()

                Text("1.0.0")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .liquidGlass(cornerRadius: 16)
    }

    private func settingsRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var logoutButton: some View {
        Button(action: { authManager.logout() }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("logout".localized)
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(LiquidGlassButtonStyle(isDestructive: true))
    }
}
