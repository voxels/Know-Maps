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
    @State public var didConfirmOnboarding:Bool = false

    var body: some View {
        VStack(alignment: .center, content:  {
            OnboardingSignInView(authService:settingsModel)
            OnboardingLocationView(settingsModel: settingsModel, chatModel: $chatModel, modelController: $modelController, showOnboarding: $showOnboarding, locationIsAuthorized: $locationIsAuthorized)
                .onChange(of: showOnboarding) { oldValue, newValue in
                    if newValue {
                        didConfirmOnboarding = true
                    }
                }
        })
        .onAppear() {
            let auth = settingsModel.isSignedIn()
            if locationIsAuthorized && auth {
                showOnboarding = false
            }
        }
    }
}
