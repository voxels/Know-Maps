//
//  SwiftUIView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI

struct OnboardingView: View {    
    @EnvironmentObject public var settingsModel:AuthenticationManager
    @EnvironmentObject public var featureFlags:FeatureFlags
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    
    @Binding public var selectedTab:String
    @Binding public var showOnboarding:Bool

    var body: some View {
        TabView(selection: $selectedTab,
                content:  {
            OnboardingSignInView(selectedTab: $selectedTab)
                .tag("Sign In")
                .tabItem({
                    Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                })
            OnboardingLocationView(locationProvider: locationProvider, showOnboarding: $showOnboarding, selectedTab: $selectedTab)
                .tag("Location")
                .tabItem({
                    Label("Location", systemImage: "map" )
                })
        })
    }
}
