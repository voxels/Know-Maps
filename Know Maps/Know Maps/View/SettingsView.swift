//
//  SettingsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject public var model:SettingsModel
    private let tag = "com.noisederived.Know-Maps.keys.appleuserid".data(using: .utf8)!

    var body: some View {
        if model.userId.isEmpty {
            SignInWithAppleButton { request in
                if !model.userId.isEmpty {
                    request.user = model.userId
                }
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                switch result {
                case .success(let authResults):
                    if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                        model.userId = appleIDCredential.user
                        model.fullName = "\(appleIDCredential.fullName?.givenName ?? "") \(appleIDCredential.fullName?.familyName ?? "")"
                        print("Authorization successful.")

                        Task {
                            let key =  model.userId.data(using: .utf8)
                            let addquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                           kSecAttrApplicationTag as String: tag,
                                                           kSecValueData as String: key as AnyObject]
                            let status = SecItemAdd(addquery as CFDictionary, nil)
                            guard status == errSecSuccess else {
                                print(status)
                                return
                            }
                            print("Storing Apple ID successful.")
                        }
                    }
                case .failure(let error):
                    print("Authorization failed: " + error.localizedDescription)
                }
            }
            .task {
                
                let getquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                               kSecAttrApplicationTag as String: tag,
                                               kSecReturnData as String: true]
                
                var item: CFTypeRef?
                let status = SecItemCopyMatching(getquery as CFDictionary, &item)
                guard status == errSecSuccess else {
                    model.userId = ""
                    return
                }
                let key = item as! SecKey
                guard let keyData = item as? Data  else {
                    model.userId = ""
                    return
                }
                
                model.keychainId = String(data: keyData, encoding: .utf8) ?? ""
                guard let keychainId = model.keychainId else {
                    return
                }
                
                do {
                    let appleIDProvider = ASAuthorizationAppleIDProvider()

                    let credentialState = try await appleIDProvider.credentialState(forUserID: keychainId)
                    switch credentialState {
                    case .authorized:
                        model.userId = keychainId
                        let request = appleIDProvider.createRequest()
                        request.user = model.userId
                        request.requestedScopes = [.fullName]
                        let controller = ASAuthorizationController(authorizationRequests: [request])
                        controller.delegate = model
                        controller.performRequests()
                    case .revoked:
                        model.userId = ""
                        // The Apple ID credential is revoked.
                        break
                    case .notFound:
                        model.userId = ""
                        // No credential was found, so show the sign-in UI.
                        break
                    default:
                        break
                    }
                } catch {
                    print(error)
                }
            }
        }
        else {
            if let fullName = model.fullName?.trimmingCharacters(in: .whitespaces) {
                Label("Welcome \(fullName)", systemImage:"apple.logo")
            } else {
                Label("Welcome", systemImage:"apple.logo")
            }
        }
    }
}

#Preview {
    let model = SettingsModel(userId:"")
    return SettingsView(model:model)
}
