import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var vm: ProfileViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 1) {
                    toggleRow(
                        icon: "bell.fill",
                        label: "in_app_notifications".localized,
                        isOn: .constant(true),
                        color: .red
                    )

                    toggleRow(
                        icon: "speaker.wave.2.fill",
                        label: "notification_sound".localized,
                        isOn: Binding(
                            get: { vm.user?.notificationSound != "none" },
                            set: { val in
                                Task { await vm.updateSetting("notification_sound", value: val ? "default" : "none") }
                            }
                        ),
                        color: .blue
                    )

                    toggleRow(
                        icon: "iphone.radiowaves.left.and.right",
                        label: "vibration".localized,
                        isOn: Binding(
                            get: { vm.user?.notificationVibrate ?? true },
                            set: { val in Task { await vm.updateSetting("notification_vibrate", value: val) } }
                        ),
                        color: .purple
                    )

                    toggleRow(
                        icon: "eye.fill",
                        label: "message_preview".localized,
                        isOn: Binding(
                            get: { vm.user?.notificationPreview ?? true },
                            set: { val in Task { await vm.updateSetting("notification_preview", value: val) } }
                        ),
                        color: .green
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .liquidGlass(cornerRadius: 16)

                soundPickerSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(themeManager.backgroundColor)
        .navigationTitle("notification_settings".localized)
    }

    private var soundPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("notification_sound".localized)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                ForEach(soundOptions, id: \.0) { value, label in
                    Button(action: {
                        Task { await vm.updateSetting("notification_sound", value: value) }
                    }) {
                        HStack {
                            Text(label)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)

                            Spacer()

                            if vm.user?.notificationSound == value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .glassCard()
    }

    private func toggleRow(icon: String, label: String, isOn: Binding<Bool>, color: Color) -> some View {
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

    private var soundOptions: [(String, String)] {
        [
            ("default", "Default"),
            ("chime", "Chime"),
            ("bell", "Bell"),
            ("pop", "Pop"),
            ("swoosh", "Swoosh"),
            ("none", "disable".localized),
        ]
    }
}

struct LanguageSettingsView: View {
    @EnvironmentObject var localization: LocalizationManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 1) {
                    ForEach(Array(LocalizationManager.supportedLanguages.keys.sorted()), id: \.self) { code in
                        Button(action: { localization.currentLanguage = code }) {
                            HStack {
                                Text(langFlag(code))
                                    .font(.system(size: 24))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizationManager.supportedLanguages[code] ?? code)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)

                                    Text(code.uppercased())
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if localization.currentLanguage == code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemGroupedBackground))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .liquidGlass(cornerRadius: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(themeManager.backgroundColor)
        .navigationTitle("language".localized)
    }

    private func langFlag(_ code: String) -> String {
        switch code {
        case "ru": return "🇷🇺"
        case "en": return "🇬🇧"
        default: return "🌐"
        }
    }
}
