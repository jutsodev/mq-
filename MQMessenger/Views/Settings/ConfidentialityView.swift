import SwiftUI

struct ConfidentialityView: View {
    @ObservedObject var vm: ProfileViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showPinSetup = false
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var pinStep = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 1) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("two_step_verification".localized)
                                .font(.system(size: 15))
                            Text(vm.user?.twoStepEnabled == true ? "enable".localized : "disable".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { vm.user?.twoStepEnabled ?? false },
                            set: { enabled in
                                if enabled {
                                    showPinSetup = true
                                } else {
                                    Task { await vm.disableTwoStep() }
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(themeManager.accentColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))

                    infoRow(icon: "lock.fill", label: "e2e_encrypted".localized,
                        value: "AES-256", color: .blue)

                    infoRow(icon: "hand.raised.fill", label: "fingerprint_lock".localized,
                        value: "disable".localized, color: .purple)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .liquidGlass(cornerRadius: 16)

                VStack(spacing: 1) {
                    infoRow(icon: "timer", label: "auto_delete".localized,
                        value: "disable".localized, color: .orange)

                    infoRow(icon: "key.fill", label: "encryption".localized,
                        value: "RSA-2048", color: .red)

                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.indigo)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("permissions".localized)
                                .font(.system(size: 15))
                            Text("send_media".localized)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .liquidGlass(cornerRadius: 16)

                infoCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(themeManager.backgroundColor)
        .navigationTitle("confidentiality".localized)
        .sheet(isPresented: $showPinSetup) {
            pinSetupSheet
        }
    }

    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 15))

            Spacer()

            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var infoCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("e2e_encrypted".localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }

    private var pinSetupSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text(pinStep == 0 ? "enter_pin".localized : "confirm_pin".localized)
                    .font(.system(size: 20, weight: .semibold))

                SecureField("pin_code".localized, text: pinStep == 0 ? $pin : $confirmPin)
                    .font(.system(size: 24))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .glassTextField()
                    .frame(maxWidth: 200)

                Button(action: {
                    if pinStep == 0 {
                        if pin.count >= 4 { pinStep = 1 }
                    } else {
                        if pin == confirmPin {
                            Task {
                                await vm.enableTwoStep(pin: pin)
                                showPinSetup = false
                                pin = ""
                                confirmPin = ""
                                pinStep = 0
                            }
                        }
                    }
                }) {
                    Text("continue".localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.blue)
                        )
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("two_step_verification".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) {
                        showPinSetup = false
                        pin = ""
                        confirmPin = ""
                        pinStep = 0
                    }
                }
            }
        }
    }
}
