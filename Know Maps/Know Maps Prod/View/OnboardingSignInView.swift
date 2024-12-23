//
//  OnboardingSignInView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

//  OnboardingSignInView.swift
//  Know Maps
//  OnboardingSignInView.swift
//  Know Maps

import SwiftUI
import AuthenticationServices

struct OnboardingSignInView: View {
    @ObservedObject var authService: AppleAuthenticationService
    @State private var popoverPresented: Bool = false
    @State private var signInErrorMessage: String = ""
    
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to Know Maps")
                .bold()
                .padding()
            
            Image("logo_macOS_512")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            
            Text("1. Sign in with your Apple ID to create saved lists. Know Maps keeps your data safe inside Apple's private iCloud storage.")
                .multilineTextAlignment(.leading)
                .padding()
            
            if !authService.appleUserId.isEmpty {
                Label("Signed in with Apple ID", systemImage: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(.accent)
            } else {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    authService.signIn()
                }, onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        if let provider = authResults.provider as? ASAuthorizationAppleIDProvider {
                            authService.authorizationController(controller: ASAuthorizationController(authorizationRequests: [provider.createRequest()]), didCompleteWithAuthorization: authResults)
                        }
                    case .failure(let error):
                        // Update error message and present popover
                        signInErrorMessage = error.localizedDescription
                        popoverPresented.toggle()
                    }
                })
                .frame(maxWidth:220, maxHeight: 44)
                .signInWithAppleButtonStyle(.whiteOutline)
                .popover(isPresented: $popoverPresented, content: {
                    Text(signInErrorMessage)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                })
                .padding()
                
                Spacer()
            }
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
