//
//  SwiftUIView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI

struct OnboardingView: View {
    
    @EnvironmentObject public var cloudCache:CloudCache
    @EnvironmentObject public var settingsModel:SettingsModel
    @EnvironmentObject public var featureFlags:FeatureFlags
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    
    @Binding public var selectedTab:String
    @Binding public var showOnboarding:Bool
    @Binding public var isAuthorized:Bool
    @Binding public var isOnboarded:Bool

    var body: some View {
        if selectedTab != "Saving" {
            OnboardingTemplateView(selectedTab: $selectedTab, showOnboarding: $showOnboarding, isOnboarded: $isOnboarded, chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider).tag("Saving")
        } else {
        TabView(selection: $selectedTab,
                content:  {
            OnboardingSignInView(selectedTab: $selectedTab)
                .tag("Sign In")
                .tabItem({
                    Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                })
            OnboardingLocationView(locationProvider: locationProvider, isAuthorized: $isAuthorized, selectedTab: $selectedTab)
                .tag("Location")
                .tabItem({
                    Label("Sign In", systemImage: "map" )
                })
            OnboardingSubscriptionView(selectedTab: $selectedTab, showOnboarding: $showOnboarding)
                .tag("Subscription")
                .tabItem({
                Label("Subscription", systemImage: "cart")
            })
        })
        #if os(iOS) || os(visionOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .scrollDisabled(true)
        #endif
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    let chatHost = AssistiveChatHost()
    OnboardingView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, selectedTab:.constant("Sign In"), showOnboarding: .constant(true), isAuthorized: .constant(false), isOnboarded: .constant(false))
}
