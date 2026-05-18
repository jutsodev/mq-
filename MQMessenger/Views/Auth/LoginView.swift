import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.purple.opacity(0.1),
                    Color.cyan.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .blue.opacity(0.3), radius: 20, y: 8)

                        Text("MQ")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 8) {
                        Text("welcome".localized)
                            .font(.system(size: 28, weight: .bold))

                        Text("welcome_subtitle".localized)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)

                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Menu {
                                ForEach(AuthViewModel.countryCodes, id: \.0) { code, label in
                                    Button("\(label) \(code)") {
                                        vm.countryCode = code
                                    }
                                }
                            } label: {
                                Text(vm.countryCode)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    )
                            }

                            TextField("enter_phone".localized, text: $vm.phone)
                                .font(.system(size: 18))
                                .keyboardType(.phonePad)
                                .glassTextField()
                                .onChange(of: vm.phone) { newValue in
                                    vm.formatPhoneInput(newValue)
                                }
                        }

                        Text("demo_hint".localized)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }

                    Button(action: {
                        Task { await vm.submitPhone() }
                    }) {
                        HStack {
                            if vm.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("continue".localized)
                                    .font(.system(size: 17, weight: .semibold))
                                Image(systemName: "arrow.right")
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: vm.isPhoneValid
                                            ? [.blue, .blue.opacity(0.8)]
                                            : [.gray, .gray.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .blue.opacity(vm.isPhoneValid ? 0.3 : 0), radius: 12, y: 4)
                        )
                    }
                    .disabled(!vm.isPhoneValid || vm.isLoading)
                }
                .padding(.horizontal, 24)
                .glassCard(padding: 24)
                .padding(.horizontal, 16)

                Spacer()

                HStack(spacing: 4) {
                    Button(action: {
                        localization.toggleLanguage()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                            Text(localization.currentLanguage == "ru" ? "English" : "Русский")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}
