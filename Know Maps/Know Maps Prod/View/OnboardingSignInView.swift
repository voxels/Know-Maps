//
//  OnboardingSignInView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI
import AuthenticationServices

struct OnboardingSignInView: View {
    @Binding public var selectedTab:String
    @EnvironmentObject public var model:SettingsModel
    @EnvironmentObject public var cloudCache:CloudCache
    @State private var popoverPresented:Bool = false
    @State private var signInErrorMessage:String = "Error"
    
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to Know Maps").bold().padding()
            Image("logo_macOS_512")
                .resizable()
                .scaledToFit()
                .frame(width:100 , height: 100)
            Text("Sign in with your Apple ID to create saved lists. Know Maps keeps your data safe inside Apple's private iCloud storage.")
                .multilineTextAlignment(.leading)
                .padding()
            
            if !model.appleUserId.isEmpty {
                SignInWithAppleButton { request in
                    request.user = model.appleUserId
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
                                selectedTab = "Location"
                            }
                        }
                    case .failure(let error):
                        signInErrorMessage = String(describing: error)
                        print("Authorization failed: " + String(describing: error))
                        popoverPresented.toggle()
                    }
                }
                .frame(maxHeight:44)
                .signInWithAppleButtonStyle(.whiteOutline)
                .popover(isPresented: $popoverPresented, content: {
                    Text(signInErrorMessage).padding()
                })
            } else {
                Button(action: {
                    openSettingsPreferences()
                }, label: {
                    Text("Sign out in device settings")
                })
            }
            Spacer()
        }
    }
#if os(macOS)
public func openSettingsPreferences() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Applications") {
        NSWorkspace.shared.open(url)
    }
}
#else
func openSettingsPreferences() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
#endif
}

#Preview {
    OnboardingSignInView(selectedTab: .constant("Sign In"))
}
