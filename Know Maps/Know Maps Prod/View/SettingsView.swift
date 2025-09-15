//
//  SettingsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    @Environment(\.openWindow) private var openWindow
    @ObservedObject public var model:AppleAuthenticationService
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var showOnboarding:Bool
    @State private var popoverPresented:Bool = false
    @State private var signInErrorMessage:String = "Error"
    @State private var isAuthenticated = false

    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                if !model.appleUserId.isEmpty {
                    let fullName = model.fullName.trimmingCharacters(in: .whitespaces)
                    if !fullName.isEmpty {
                        Label("Welcome \(fullName)", systemImage:"apple.logo")
                            .padding(.top, 60)
                    } else {
                        Label("Signed in with Apple ID", systemImage:"apple.logo")
                            .padding(.top, 60)
                    }
                } else {
                    SignInWithAppleButton { request in
                        model.signIn()
                    } onCompletion: { result in
                        switch result {
                        case .success(let authResults):
                            Task {
                                if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                                    await MainActor.run {
                                        model.appleUserId = appleIDCredential.user
                                        model.fullName = "\(appleIDCredential.fullName?.givenName ?? "") \(appleIDCredential.fullName?.familyName ?? "")"
#if os(visionOS)
                                        openWindow(id: "ContentView")
#endif
                                    }
                                    print("Authorization successful.")
                                    Task {
                                        let key =  model.appleUserId.data(using: .utf8)
                                        let addquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                                       kSecAttrApplicationTag as String: AppleAuthenticationService.tag,
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
                            Task {
                                await MainActor.run {
                                    signInErrorMessage = String(describing: error)
                                    print("Authorization failed: " + String(describing: error))
                                    popoverPresented.toggle()
                                }
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(maxHeight:60)
                    .popover(isPresented: $popoverPresented, content: {
                        Text(signInErrorMessage).padding()
                            .presentationCompactAdaptation(.popover)
                    })
                    .padding(.top, 60)
                }
            }
        List() {
            Button {
                print("Sign Out tapped")
                Task {
                    model.signOut()
                    await MainActor.run {
                        showOnboarding = true
                    }
                }
            } label: {
                Label("Sign Out of your Apple ID", systemImage: "person.crop.circle.badge.minus")
            }
            Button(action:{
                print("Delete data tapped")
                Task {
                    do {
                        try await cacheManager.cloudCache.deleteAllUserCachedGroups()
                        try await cacheManager.refreshCache()
                        await MainActor.run {
                            showOnboarding = true
                        }
                    } catch {
                        modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                    }
                }
            }, label:{
              Text("Delete data stored in iCloud.")
            })
            Button {
                print("Delete account tapped")
                Task {
                    do {
                        try await cacheManager.cloudCache.deleteAllUserCachedGroups()
                        try await cacheManager.refreshCache()
                        model.signOut()
                        await MainActor.run {
                            showOnboarding = true
                        }
                    } catch {
                        modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                    }
                }
            } label: {
                Text("Delete the Know Maps iCloud Account")
                    .foregroundStyle(.red)
            }
        }
#if os(macOS) || os(visionOS)
        .buttonStyle(.borderless)
#else
        .buttonStyle(.plain)
#endif
            
        }
        .navigationTitle("Account")
    }
}

