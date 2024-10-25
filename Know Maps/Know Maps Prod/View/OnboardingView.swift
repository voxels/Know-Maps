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
    
    @Binding  public var selectedTab:String
    @Binding  public var showOnboarding:Bool
    @State public var locationIsAuthorized:Bool = false

    var body: some View {
        TabView(selection: $selectedTab,
                content:  {
            OnboardingSignInView(authService:settingsModel, selectedTab: $selectedTab)
                .tag("Sign In")
                .tabItem({
                    Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                })
            OnboardingLocationView(chatModel: $chatModel, modelController: $modelController, showOnboarding: $showOnboarding, selectedTab:$selectedTab, locationIsAuthorized: $locationIsAuthorized)
                .tag("Location")
                .tabItem({
                    Label("Location", systemImage: "map" )
                })
                .onChange(of: locationIsAuthorized) { oldValue, newValue in
                    if newValue, settingsModel.isSignedIn {
                        showOnboarding = false
                    }
                }
        })
    }
}
