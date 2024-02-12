//
//  SettingsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject public var model:SettingsModel
    @EnvironmentObject public var cloudCache:CloudCache
    @State private var popoverPresented:Bool = false
    @State private var signInErrorMessage:String = "Error"
    var body: some View {
        if model.appleUserId.isEmpty {
                SignInWithAppleButton { request in
                    if !model.appleUserId.isEmpty {
                        request.user = model.appleUserId
                    }
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        Task { @MainActor in
                            if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                                await MainActor.run {
                                    model.appleUserId = appleIDCredential.user
                                    model.fullName = "\(appleIDCredential.fullName?.givenName ?? "") \(appleIDCredential.fullName?.familyName ?? "")"
                                    cloudCache.hasPrivateCloudAccess = true
                                    #if os(visionOS)
                                    openWindow(id: "ContentView")
                                    #endif
                                }
                                print("Authorization successful.")
                                Task {
                                    let key =  model.appleUserId.data(using: .utf8)
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
                        }
                    case .failure(let error):
                        signInErrorMessage = String(describing: error)
                        print("Authorization failed: " + String(describing: error))
                        popoverPresented.toggle()
                    }
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(maxWidth: 360, maxHeight: 60)
                .popover(isPresented: $popoverPresented, content: {
                    Text(signInErrorMessage).padding()
                })
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
    return SettingsView()
}
