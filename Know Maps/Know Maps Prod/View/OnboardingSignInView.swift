//
//  OnboardingSignInView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI
import AuthenticationServices

struct OnboardingSignInView: View {
    @Binding public var selectedTab:Int
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
                            selectedTab = 2
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
            Spacer()
        }
    }
}

#Preview {
    OnboardingSignInView(selectedTab: .constant(1))
}
