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

public enum AppleAuthenticationServiceError : Error {
    case failed
}

class AppleAuthenticationService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isSignedIn: Bool = false
    @Published var fullName: String = ""
    @Published var appleUserId: String = ""
    @Published var signInErrorMessage: String = ""
    
    public var authCompletion:((Result<ASAuthorization, Error>) -> Void)?
    
    // Singleton instance (optional)
    static let shared = AppleAuthenticationService()
    
    // Constants
    static let tag = "com.knowmaps.security.appleUserId"
    
    // MARK: - Sign In with Apple
    func signIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        prepareSignInRequest(request)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
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
                    self?.isSignedIn = false
                    self?.fullName = ""
                    self?.appleUserId = ""
                    self?.deleteFromKeychain(key: "accessToken")
                    self?.deleteFromKeychain(key: "refreshToken")
                } else {
                    self?.signInErrorMessage = "Failed to revoke token."
                }
            }
        }
    }
    
    // MARK: - Token Exchange
    func exchangeAuthorizationCode(_ code: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://www.no-maps.com/exchangeAppleToken") else {
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
            do {
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                // Store tokens securely
                self?.storeTokens(accessToken: tokenResponse.access_token, refreshToken: tokenResponse.refresh_token)
                DispatchQueue.main.async {
                    self?.isSignedIn = true
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
        guard let url = URL(string: "https://www.no-maps.com/revokeAppleToken") else {
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
    private func storeTokens(accessToken: String, refreshToken: String) {
        saveToKeychain(key: "accessToken", value: accessToken)
        saveToKeychain(key: "refreshToken", value: refreshToken)
    }
    
    func retrieveAccessToken() -> String? {
        return readFromKeychain(key: "accessToken")
    }
    
    func retrieveRefreshToken() -> String? {
        return readFromKeychain(key: "refreshToken")
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
    func handleSignInError(_ error: Error) {
        DispatchQueue.main.async {
            self.signInErrorMessage = error.localizedDescription
        }
        print("Authorization failed: \(error.localizedDescription)")
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
        // Replace with appropriate window for macOS or iOS
        #if os(macOS)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #endif
    }
}

// MARK: - Token Response Struct
struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let id_token: String
    let token_type: String
    let expires_in: Int
}
