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
    
    @State private var selectedTab = 1
    @Binding public var showOnboarding:Bool
    @Binding public var isAuthorized:Bool

    var body: some View {
        TabView(selection: $selectedTab,
                content:  {
            OnboardingSignInView(selectedTab: $selectedTab).tag(1)
            OnboardingLocationView(locationProvider: locationProvider, isAuthorized: $isAuthorized, selectedTab: $selectedTab).tag(2)
            OnboardingSubscriptionView(selectedTab: $selectedTab, showOnboarding: $showOnboarding).tag(3)
        })
        #if os(iOS) || os(visionOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .scrollDisabled(true)
        #endif
    }
}

#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    let chatHost = AssistiveChatHost()
    OnboardingView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, showOnboarding: .constant(true), isAuthorized: .constant(false))
}
