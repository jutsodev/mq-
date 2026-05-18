import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var phone = ""
    @Published var code = ""
    @Published var step: AuthStep = .phone
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var countryCode = "+7"

    enum AuthStep {
        case phone, code
    }

    var fullPhone: String {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        return "\(countryCode)\(cleaned)"
    }

    var isPhoneValid: Bool {
        let digits = phone.replacingOccurrences(of: " ", with: "")
        return digits.count >= 7
    }

    var isCodeValid: Bool {
        code.count >= 4
    }

    func submitPhone() async {
        guard isPhoneValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.login(phone: fullPhone)
            AuthManager.shared.token = response.token
            AuthManager.shared.currentUser = response.user
            AuthManager.shared.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func submitCode() async {
        guard isCodeValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.verifyCode(phone: fullPhone, code: code)
            AuthManager.shared.token = response.token
            AuthManager.shared.currentUser = response.user
            AuthManager.shared.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func formatPhoneInput(_ input: String) {
        let digits = input.filter { $0.isNumber }
        var formatted = ""
        for (i, ch) in digits.enumerated() {
            if i == 3 || i == 6 || i == 8 {
                formatted += " "
            }
            formatted += String(ch)
            if i >= 9 { break }
        }
        phone = formatted
    }

    func goBack() {
        step = .phone
        code = ""
        errorMessage = nil
    }

    static let countryCodes = [
        ("+7", "🇷🇺 RU"),
        ("+1", "🇺🇸 US"),
        ("+44", "🇬🇧 UK"),
        ("+49", "🇩🇪 DE"),
        ("+33", "🇫🇷 FR"),
        ("+380", "🇺🇦 UA"),
        ("+375", "🇧🇾 BY"),
        ("+77", "🇰🇿 KZ"),
        ("+998", "🇺🇿 UZ"),
        ("+86", "🇨🇳 CN"),
        ("+81", "🇯🇵 JP"),
        ("+82", "🇰🇷 KR"),
        ("+91", "🇮🇳 IN"),
        ("+55", "🇧🇷 BR"),
        ("+90", "🇹🇷 TR"),
    ]
}
