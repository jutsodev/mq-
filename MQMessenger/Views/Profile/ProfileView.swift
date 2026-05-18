import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var vm = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileHeaderCard
                    infoSection
                    settingsSection
                    supportSection
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
            .confirmationDialog(
                "logout".localized,
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("logout".localized, role: .destructive) {
                    authManager.logout()
                }
                Button("cancel".localized, role: .cancel) {}
            }
        }
    }

    private var profileHeaderCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.accentColor.opacity(0.2), themeManager.accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 116, height: 116)

                LargeAvatarView(
                    name: authManager.currentUser?.nameOrPhone ?? "",
                    avatarURL: authManager.currentUser?.avatarURL,
                    size: 100,
                    showEditButton: true,
                    onEdit: { showEditProfile = true }
                )
            }

            VStack(spacing: 6) {
                Text(authManager.currentUser?.nameOrPhone ?? "")
                    .font(.system(size: 24, weight: .bold))

                if let username = authManager.currentUser?.username {
                    Text("@\(username)")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.accentColor)
                }

                if let status = authManager.currentUser?.status {
                    HStack(spacing: 4) {
                        PulsingDot(color: status == "online" ? .green : .gray, size: 6)
                        Text(status == "online" ? "online".localized : "offline".localized)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let bio = authManager.currentUser?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var infoSection: some View {
        VStack(spacing: 1) {
            infoRow(icon: "phone.fill", label: "phone".localized,
                value: authManager.currentUser?.phone ?? "", color: .green)
            infoRow(icon: "person.fill", label: "username".localized,
                value: "@\(authManager.currentUser?.username ?? "")", color: .blue)
            infoRow(icon: "text.quote", label: "bio".localized,
                value: authManager.currentUser?.bio ?? "", color: .purple)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .liquidGlass(cornerRadius: 16)
    }

    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.gradient)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 15))
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
            }

            Spacer()

            Button(action: {
                UIPasteboard.general.string = value
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
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
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .liquidGlass(cornerRadius: 16)
    }

    private var supportSection: some View {
        VStack(spacing: 1) {
            settingsRow(icon: "externaldrive.fill", label: "data_storage".localized, color: .cyan)
            settingsRow(icon: "questionmark.circle.fill", label: "help".localized, color: .gray)

            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.secondary.gradient)
                    )

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
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.gradient)
                )

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var logoutButton: some View {
        Button(action: { showLogoutConfirm = true }) {
            HStack(spacing: 8) {
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
