import Foundation
import SwiftUI

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var token: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tokenKey = "mq_auth_token"
    private let userKey = "mq_current_user"

    private init() {
        loadSavedSession()
    }

    func login(phone: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        do {
            let response = try await APIService.shared.login(phone: phone)
            await MainActor.run {
                token = response.token
                currentUser = response.user
                isAuthenticated = true
                isLoading = false
                saveSession()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func verifyCode(phone: String, code: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        do {
            let response = try await APIService.shared.verifyCode(phone: phone, code: code)
            await MainActor.run {
                token = response.token
                currentUser = response.user
                isAuthenticated = true
                isLoading = false
                saveSession()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func refreshProfile() async {
        do {
            let response = try await APIService.shared.getProfile()
            await MainActor.run {
                currentUser = response.user
                saveSession()
            }
        } catch {
            print("Profile refresh failed: \(error)")
        }
    }

    func updateProfile(_ updates: [String: Any]) async throws {
        let response = try await APIService.shared.updateProfile(updates)
        await MainActor.run {
            currentUser = response.user
            saveSession()
        }
    }

    func logout() {
        WebSocketService.shared.disconnect()
        token = nil
        currentUser = nil
        isAuthenticated = false
        clearSession()
    }

    private func saveSession() {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let user = currentUser, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func loadSavedSession() {
        token = UserDefaults.standard.string(forKey: tokenKey)
        if let data = UserDefaults.standard.data(forKey: userKey) {
            currentUser = try? JSONDecoder().decode(User.self, from: data)
        }
        isAuthenticated = token != nil && currentUser != nil
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}
