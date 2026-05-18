import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                Color(red: 0.49, green: 0.36, blue: 0.99)
                    .frame(height: 0)
                    .background(
                        Color(red: 0.49, green: 0.36, blue: 0.99)
                            .frame(height: 200)
                            .offset(y: -100)
                    )
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image("mq-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    VStack(spacing: 6) {
                        Text("welcome".localized)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.primary)

                        Text("welcome_subtitle".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Menu {
                                ForEach(AuthViewModel.countryCodes, id: \.0) { code, label in
                                    Button("\(label) \(code)") {
                                        vm.countryCode = code
                                    }
                                }
                            } label: {
                                Text(vm.countryCode)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.systemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color(.separator), lineWidth: 0.5)
                                            )
                                    )
                            }

                            TextField("enter_phone".localized, text: $vm.phone)
                                .font(.system(size: 17))
                                .keyboardType(.phonePad)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(.separator), lineWidth: 0.5)
                                        )
                                )
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
                                    .fill(Color.red.opacity(0.08))
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
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(vm.isPhoneValid
                                    ? Color(red: 0.49, green: 0.36, blue: 0.99)
                                    : Color.gray)
                        )
                    }
                    .disabled(!vm.isPhoneValid || vm.isLoading)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                )
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
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}
