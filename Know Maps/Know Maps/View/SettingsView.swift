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
    @Binding public var selectedTab:String
    
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
                            selectedTab = "Settings"
                            Task {
                                let key =  model.userId.data(using: .utf8)
                                let addquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                               kSecAttrApplicationTag as String: SettingsModel.tag,
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
                .signInWithAppleButtonStyle(.whiteOutline)
        }
        else {
            if let fullName = model.fullName?.trimmingCharacters(in: .whitespaces), !fullName.isEmpty {
                Label("Welcome \(fullName)", systemImage:"apple.logo")
            } else {
                Label("Signed in with Apple ID", systemImage:"apple.logo")
            }
        }
    }
}

#Preview {
    let model = SettingsModel(userId:"")
    return SettingsView(model:model, selectedTab: .constant("Settings"))
}
