import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.1),
                    Color(red: 0.07, green: 0.05, blue: 0.18),
                    Color(red: 0.1, green: 0.06, blue: 0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Image("mq-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .shadow(color: .purple.opacity(0.4), radius: 20, y: 8)

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
                                            ? [Color(red: 0.49, green: 0.36, blue: 0.99), Color(red: 0.57, green: 0.47, blue: 1.0)]
                                            : [.gray, .gray.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color(red: 0.49, green: 0.36, blue: 0.99).opacity(vm.isPhoneValid ? 0.4 : 0), radius: 12, y: 4)
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
