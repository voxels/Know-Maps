//
//  SwiftUIView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI

struct OnboardingView: View {    
    @ObservedObject public var settingsModel:AppleAuthenticationService
    @Binding public var chatModel:ChatResultViewModel
    @Binding var modelController:DefaultModelController
    
    @Binding  public var showOnboarding:Bool
    @State public var locationIsAuthorized:Bool = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Optional header/title to anchor the layout consistently
                    VStack(spacing: 8) {
                        Text("Welcome to Know Maps")
                            .font(.largeTitle).bold()
                            .multilineTextAlignment(.center)
                        Text("Sign in and enable location to personalize your experience.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    // Content stack with consistent width and alignment
                    VStack(alignment: .center, spacing: 24) {
                        OnboardingSignInView(authService: settingsModel)
                            .frame(maxWidth: .infinity, alignment: .center)

                        OnboardingLocationView(
                            settingsModel: settingsModel,
                            chatModel: $chatModel,
                            modelController: $modelController,
                            showOnboarding: $showOnboarding,
                            locationIsAuthorized: $locationIsAuthorized
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(20)
                    .frame(maxWidth: 600) // readable width on iPad/macOS/visionOS
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .frame(minHeight: proxy.size.height)
            }
            .ignoresSafeArea(edges: .bottom)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.9)
            )
        }
    }
}
