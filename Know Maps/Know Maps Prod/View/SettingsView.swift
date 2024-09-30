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
    @State private var isAuthenticated = false
    @ObservedObject public var chatModel:ChatResultViewModel
    @Binding public var showOnboarding:Bool
    var body: some View {
        VStack {
            if isAuthenticated {
                if let fullName = model.fullName?.trimmingCharacters(in: .whitespaces), !fullName.isEmpty {
                    Label("Welcome \(fullName)", systemImage:"apple.logo").padding()
                } else {
                    Label("Signed in with Apple ID", systemImage:"apple.logo").padding()
                }
            } else {
                SignInWithAppleButton { request in
                    if !model.appleUserId.isEmpty {
                        request.user = model.appleUserId
                    }
                    request.requestedScopes = [.fullName]
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
                })
                .padding()
                .task {
                    checkIfSignedInWithApple(completion: { isAuthenticated in
                        Task { @MainActor in
                            self.isAuthenticated = isAuthenticated
                        }
                     })
                }
            }
                
            Button(action:{
                Task {
                    do {
                        try await cloudCache.deleteAllUserCachedGroups()
                        chatModel.removeCachedResults()
                        try await chatModel.refreshCache(cloudCache: cloudCache)
                        await MainActor.run {
                            showOnboarding = true
                        }
                    } catch {
                        print(error)
                    }
                }
            }, label:{
              Text("Delete all of my saved groups")
            }).padding()
        }.padding()
        #if os(macOS)
            .navigationTitle("Settings")
        #else
        .navigationBarTitle("Settings")
        #endif
    }
    
    public func checkIfSignedInWithApple(completion:@escaping (Bool)->Void) {
        guard model.appleUserId.isEmpty else {
            completion(false)
            return
        }
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        
        // Retrieve the credential state for the Apple ID credential
        appleIDProvider.getCredentialState(forUserID: model.appleUserId) { (credentialState, error) in
            switch credentialState {
            case .authorized:
                completion(true)
            case .revoked, .notFound:
                fallthrough
            default:
                completion(false)
            }
        }
    }
}
