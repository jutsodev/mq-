import SwiftUI

struct PrivacySettingsView: View {
    @ObservedObject var vm: ProfileViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 1) {
                    glassToggleRow(
                        icon: "circle.fill",
                        label: "show_online_status".localized,
                        isOn: Binding(
                            get: { vm.user?.showOnline ?? true },
                            set: { val in Task { await vm.updateSetting("show_online", value: val) } }
                        ),
                        color: .green
                    )

                    glassToggleRow(
                        icon: "clock.fill",
                        label: "show_last_seen".localized,
                        isOn: Binding(
                            get: { vm.user?.showLastSeen ?? true },
                            set: { val in Task { await vm.updateSetting("show_last_seen", value: val) } }
                        ),
                        color: .blue
                    )

                    glassToggleRow(
                        icon: "checkmark.circle.fill",
                        label: "read_receipts".localized,
                        isOn: Binding(
                            get: { vm.user?.showReadReceipts ?? true },
                            set: { val in Task { await vm.updateSetting("show_read_receipts", value: val) } }
                        ),
                        color: .purple
                    )

                    glassToggleRow(
                        icon: "ellipsis.bubble.fill",
                        label: "show_typing".localized,
                        isOn: Binding(
                            get: { vm.user?.showTyping ?? true },
                            set: { val in Task { await vm.updateSetting("show_typing", value: val) } }
                        ),
                        color: .orange
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .liquidGlass(cornerRadius: 16)

                VStack(spacing: 1) {
                    NavigationLink(destination: BlockedUsersView()) {
                        settingsRow(icon: "person.slash.fill", label: "blocked_users".localized, color: .red)
                    }

                    settingsRow(icon: "rectangle.stack.person.crop", label: "active_sessions".localized, color: .cyan)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .liquidGlass(cornerRadius: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(themeManager.backgroundColor)
        .navigationTitle("privacy_security".localized)
    }

    private func glassToggleRow(icon: String, label: String, isOn: Binding<Bool>, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 15))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(themeManager.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
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
}

struct BlockedUsersView: View {
    @StateObject private var contactsVM = ContactsViewModel()

    var body: some View {
        List {
            if contactsVM.blockedContacts.isEmpty {
                EmptyStateView(icon: "person.slash", title: "blocked_users".localized, subtitle: nil)
            } else {
                ForEach(contactsVM.blockedContacts) { contact in
                    HStack(spacing: 12) {
                        AvatarView(name: contact.nameOrPhone, avatarURL: nil, size: 40)
                        Text(contact.nameOrPhone)
                            .font(.system(size: 15))
                        Spacer()
                        Button("unblock".localized) {
                            guard let id = contact.id else { return }
                            Task { await contactsVM.toggleBlock(id) }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle("blocked_users".localized)
        .task { await contactsVM.loadContacts() }
    }
}
