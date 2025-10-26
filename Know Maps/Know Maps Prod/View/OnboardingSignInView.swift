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
        VStack(alignment: .center, spacing: 16) {
            // App identity
            Image("logo_macOS_512")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Sign in to continue")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                Text("Use your Apple ID to create saved lists. Your data stays private in iCloud.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            // Status row
            Group {
                if !authService.appleUserId.isEmpty {
                    Label {
                        Text("Signed in with Apple ID")
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                    .foregroundStyle(.green)
                    .accessibilityLabel("Signed in with Apple ID")
                } else {
                    Label {
                        Text("Not signed in")
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Not signed in")
                }
            }
            .padding(.top, 4)

            // Action area
            if authService.appleUserId.isEmpty {
                SignInWithAppleButton(.signIn, onRequest: { _ in
                    authService.signIn()
                }, onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        if let provider = authResults.provider as? ASAuthorizationAppleIDProvider {
                            authService.authorizationController(
                                controller: ASAuthorizationController(authorizationRequests: [provider.createRequest()]),
                                didCompleteWithAuthorization: authResults
                            )
                        }
                    case .failure(let error):
                        signInErrorMessage = error.localizedDescription
                        popoverPresented = true
                    }
                })
                .frame(maxWidth: 280, maxHeight: 48)
                .signInWithAppleButtonStyle(.whiteOutline)
                .accessibilityLabel("Sign in with Apple")
                .popover(isPresented: $popoverPresented) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Sign-in failed", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(signInErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            openSettingsPreferences()
                        }
                    }
                    .padding()
                    .presentationCompactAdaptation(.popover)
                }
            } else {
                Button {
                    openSettingsPreferences()
                } label: {
                    Label("Manage Apple ID settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
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
