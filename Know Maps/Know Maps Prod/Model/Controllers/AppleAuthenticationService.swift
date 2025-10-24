//
//  SettingsModel.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import Foundation
import Combine
import AuthenticationServices
import Security
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public enum AppleAuthenticationServiceError : Error {
    case failed
}

class AppleAuthenticationService: NSObject, ObservableObject {
    // MARK: - Published Properties
   
    @Published var fullName: String = ""
    @Published var appleUserId: String = ""
    @Published var signInErrorMessage: String = ""
    private var authorizationController: ASAuthorizationController?
    
    public var authCompletion:((Result<ASAuthorization, Error>) -> Void)?
    
    // Singleton instance (optional)
    static let shared = AppleAuthenticationService()
    
    // Constants
    static let tag = "com.knowmaps.security.appleUserId"
    
    @MainActor
    func isSignedIn() -> Bool {
        if let _ = retrieveRefreshToken(), let userId = readFromKeychain(key: "appleUserId") {
            appleUserId = userId
            return true
        }
        return false
    }
    
    // MARK: - Sign In with Apple
    func signIn() {
        Task(priority: .userInitiated) { @MainActor in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            self.prepareSignInRequest(request)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.authorizationController = controller // retain to avoid premature deallocation
            controller.performRequests()
        }
    }
    
    func prepareSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    // MARK: - Sign Out
    func signOut() {
        guard let refreshToken = retrieveRefreshToken() else {
            print("No refresh token found.")
            return
        }
        revokeToken(refreshToken: refreshToken) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.fullName = ""
                    self?.appleUserId = ""
                    self?.deleteFromKeychain(key: "accessToken")
                    self?.deleteFromKeychain(key: "refreshToken")
                    self?.deleteFromKeychain(key: "appleUserId")
                    self?.deleteFromKeychain(key: "accessTokenExpiry")
                } else {
                    self?.signInErrorMessage = "Failed to revoke token."
                }
            }
        }
    }
    
    // MARK: - Token Exchange
    func exchangeAuthorizationCode(_ code: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://api-ewrihjjgiq-uc.a.run.app/exchangeAppleToken") else {
            print("Invalid exchange token URL.")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = ["code": code]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Send the request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.signInErrorMessage = "Network error: \(error.localizedDescription)"
                }
                completion(false)
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self?.signInErrorMessage = "No data received from server."
                }
                completion(false)
                return
            }
            let response = String(data: data, encoding: .utf8)
            print(response ?? "data corrupted")

            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                    // Store tokens securely
                    self?.storeTokens(
                        accessToken: tokenResponse.accessToken,
                        refreshToken: tokenResponse.refreshToken,
                        expiresIn: tokenResponse.expiresIn
                    )
                    DispatchQueue.main.async {
                        self?.signInErrorMessage = ""
                    }
                    completion(true)
                
            } catch {
                DispatchQueue.main.async {
                    self?.signInErrorMessage = "Failed to parse token data."
                }
                completion(false)
            }
        }
        task.resume()
    }
    
    // MARK: - Token Revocation
    func revokeToken(refreshToken: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://api-ewrihjjgiq-uc.a.run.app/revokeAppleToken") else {
            print("Invalid revoke token URL.")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.signInErrorMessage = "Network error: \(error.localizedDescription)"
                }
                completion(false)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.signInErrorMessage = "Invalid server response."
                }
                completion(false)
                return
            }
            if (200...299).contains(httpResponse.statusCode) {
                completion(true)
            } else {
                DispatchQueue.main.async {
                    self.signInErrorMessage = "Failed to revoke token. Status code: \(httpResponse.statusCode)"
                }
                completion(false)
            }
        }
        task.resume()
    }
    
    // MARK: - Keychain Management
    // Stores tokens and optional expiry
    private func storeTokens(accessToken: String, refreshToken: String, expiresIn: Int?) {
        saveToKeychain(key: "accessToken", value: accessToken)
        saveToKeychain(key: "refreshToken", value: refreshToken)
        if let expiresIn = expiresIn {
            // Add a small buffer (60s) to avoid using a near-expired token
            let expiry = Date().addingTimeInterval(TimeInterval(max(0, expiresIn - 60)))
            let timestamp = String(expiry.timeIntervalSince1970)
            saveToKeychain(key: "accessTokenExpiry", value: timestamp)
        }
    }

    // Convenience overload when expiry is unknown
    private func storeTokens(accessToken: String, refreshToken: String) {
        storeTokens(accessToken: accessToken, refreshToken: refreshToken, expiresIn: nil)
    }
    
    func retrieveAccessToken() -> String? {
        return readFromKeychain(key: "accessToken")
    }
    
    func retrieveRefreshToken() -> String? {
        return readFromKeychain(key: "refreshToken")
    }
    
    func retrieveAccessTokenExpiry() -> Date? {
        guard let ts = readFromKeychain(key: "accessTokenExpiry"), let seconds = TimeInterval(ts) else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }

    func isAccessTokenValid() -> Bool {
        guard let _ = retrieveAccessToken() else { return false }
        guard let expiry = retrieveAccessTokenExpiry() else { return true } // If no expiry stored, assume valid
        return Date() < expiry
    }

    // MARK: - Token Refresh
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = retrieveRefreshToken() else {
            DispatchQueue.main.async { self.signInErrorMessage = "No refresh token available." }
            completion(false)
            return
        }
        guard let url = URL(string: "https://api-ewrihjjgiq-uc.a.run.app/refreshAppleToken") else {
            print("Invalid refresh token URL.")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { completion(false); return }

            if let error = error {
                DispatchQueue.main.async {
                    self.signInErrorMessage = "Network error: \(error.localizedDescription)"
                }
                completion(false)
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.signInErrorMessage = "No data received from server."
                }
                completion(false)
                return
            }

            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                // Some refresh endpoints may omit refresh_token; keep existing if absent
                let newRefresh = tokenResponse.refreshToken.isEmpty ? refreshToken : tokenResponse.refreshToken
                self.storeTokens(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: newRefresh,
                    expiresIn: tokenResponse.expiresIn
                )
                DispatchQueue.main.async { self.signInErrorMessage = "" }
                completion(true)
            } catch {
                DispatchQueue.main.async {
                    self.signInErrorMessage = "Failed to parse refresh token data."
                }
                completion(false)
            }
        }
        task.resume()
    }

    // Returns a valid access token, refreshing if needed
    func getValidAccessToken(completion: @escaping (String?) -> Void) {
        if isAccessTokenValid(), let token = retrieveAccessToken() {
            completion(token)
            return
        }
        // Try to refresh
        refreshAccessToken { [weak self] success in
            guard let self = self else { completion(nil); return }
            if success, let token = self.retrieveAccessToken() {
                completion(token)
            } else {
                completion(nil)
            }
        }
    }
    
    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete any existing item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.knowmaps.security.apple-signin",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let newQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.knowmaps.security.apple-signin",
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(newQuery as CFDictionary, nil)
    }
    
    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.knowmaps.security.apple-signin",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        return nil
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.knowmaps.security.apple-signin",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Handling Authorization Results
    func handleAuthorization(_ authorization: ASAuthorization, completion: @escaping (Bool) -> Void) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            let userId = appleIDCredential.user
            let givenName = appleIDCredential.fullName?.givenName ?? ""
            let familyName = appleIDCredential.fullName?.familyName ?? ""
            let name = "\(givenName) \(familyName)"
            
            saveToKeychain(key: "appleUserId", value: userId)
            
            DispatchQueue.main.async {
                self.appleUserId = userId
                self.fullName = name
                self.signInErrorMessage = ""
            }
            
            // Exchange authorization code for tokens
            if let authorizationCodeData = appleIDCredential.authorizationCode,
               let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) {
                exchangeAuthorizationCode(authorizationCode) { [self] success in
                    self.authCompletion?(.success(authorization))
                    completion(success)
                }
            } else {
                DispatchQueue.main.async {
                    self.authCompletion?(.failure(AppleAuthenticationServiceError.failed))
                    self.signInErrorMessage = "Invalid authorization code."
                }
                completion(false)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Handling Sign-In Errors
    func handleSignInError(_ error: Error?) {
        
        DispatchQueue.main.async {
            if let error = error as NSError? {
                self.signInErrorMessage = error.localizedDescription
                print("Authorization failed: \(error.localizedDescription)")
            }
            self.signOut()
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleAuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleAuthorization(authorization) { success in
            if success {
                print("Authorization and token exchange successful.")
            } else {
                print("Authorization succeeded but token exchange failed.")
                self.handleSignInError(nil)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        handleSignInError(error)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleAuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(macOS)
        // Prefer the key window, then main window, then any available window; fall back to a new NSWindow if needed.
        if let keyWindow = NSApp?.keyWindow {
            return keyWindow
        }
        if let mainWindow = NSApp?.mainWindow {
            return mainWindow
        }
        if let anyWindow = NSApplication.shared.windows.first {
            return anyWindow
        }
        return NSWindow()
        #else
        // iOS: find the active foreground scene's key window
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            // Prefer an existing key window in the active scene
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            // Fallback: create a temporary window anchored to the active scene
            let tempWindow = UIWindow(windowScene: windowScene)
            // Make it as unobtrusive as possible; no root VC needed for anchor
            tempWindow.isHidden = false
            return tempWindow
        }
        // If no active scene is available, try any connected scene
        if let anyScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            if let anyWindow = anyScene.windows.first {
                return anyWindow
            }
            let tempWindow = UIWindow(windowScene: anyScene)
            tempWindow.isHidden = false
            return tempWindow
        }
        // As a last resort, return a new, hidden window only on platforms where a scene isn't required
        // However, on iOS 26+, UIWindow() is deprecated; avoid constructing without a scene
        // Return a minimal, non-nil anchor by creating a detached window if APIs change.
        // In practice, this path should rarely be hit.
        return ASPresentationAnchor()
        #endif
    }
}

// MARK: - Token Response Struct
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let idToken: String
    let tokenType: String
    let expiresIn: Int

    // Mapping the snake_case keys to camelCase properties
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

