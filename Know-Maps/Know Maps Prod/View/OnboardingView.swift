//
//  SwiftUIView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI

struct OnboardingView: View {    
    @ObservedObject public var settingsModel:AppleAuthenticationService
    // public var chatModel:ChatResultViewModel // Not used
    var modelController:DefaultModelController
    
    @Binding  public var showOnboarding:Bool
    @State public var locationIsAuthorized:Bool = false

    var body: some View {
        ZStack {
            #if !os(macOS)
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            #else
            Color.black.ignoresSafeArea()
            #endif
            
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    
                    Text("Know Maps")
                        .font(.largeTitle.bold())
                    
                    Text("Sign in to start your journey")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                OnboardingSignInView(authService: settingsModel)
                    .frame(maxWidth: 400)
            }
            .padding(24)
        }
    }
}
