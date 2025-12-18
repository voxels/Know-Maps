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

public struct OnboardingSignInView: View {
    @ObservedObject public var authService: AppleAuthenticationService
    public var onAuthCompletion: (Result<ASAuthorization, any Error>) -> Void?
    @State private var popoverPresented: Bool = false
    @State private var signInErrorMessage: String = ""
    
    public init(
        authService: AppleAuthenticationService,
        onAuthCompletion: @escaping (Result<ASAuthorization, Error>) -> Void = { _ in }
    ) {
        self.authService = authService
        self.onAuthCompletion = onAuthCompletion
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 16) {
//            // App identity
//            Image("logo_macOS_512")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 80, height: 80)
//                .accessibilityHidden(true)
//
//            VStack(spacing: 6) {
//                Text("Sign in to continue")
//                    .font(.title2).bold()
//                    .multilineTextAlignment(.center)
//                Text("Use your Apple ID to create saved lists. Your data stays private in iCloud.")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//                    .multilineTextAlignment(.center)
//            }
//            .padding(.horizontal)
//
//            // Status row
//            Group {
//                if !authService.appleUserId.isEmpty {
//                    Label {
//                        Text("Signed in with Apple ID")
//                    } icon: {
//                        Image(systemName: "person.crop.circle.badge.checkmark")
//                    }
//                    .foregroundStyle(.green)
//                    .accessibilityLabel("Signed in with Apple ID")
//                } else {
//                    Label {
//                        Text("Not signed in")
//                    } icon: {
//                        Image(systemName: "person.crop.circle")
//                    }
//                    .foregroundStyle(.secondary)
//                    .accessibilityLabel("Not signed in")
//                }
//            }
//            .padding(.top, 4)

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
                    onAuthCompletion(result)
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
    
    // Opens the appropriate Settings/Preferences screen depending on platform
    private func openSettingsPreferences() {
        #if canImport(UIKit)
        // iOS/iPadOS: open the app's settings page
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #elseif canImport(AppKit)
        // macOS: try to open the Apple ID pane in System Settings, fall back to System Settings app
        let appleIDURL = URL(string: "x-apple.systempreferences:com.apple.AppleID-Settings.extension")
        if let url = appleIDURL, NSWorkspace.shared.open(url) {
            return
        }
        // Fallback: open System Settings app
        let systemSettingsPath = "/System/Applications/System Settings.app"
        NSWorkspace.shared.open(URL(fileURLWithPath: systemSettingsPath))
        #endif
    }
}
