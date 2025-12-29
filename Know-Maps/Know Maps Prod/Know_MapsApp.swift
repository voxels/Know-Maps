//
//  Know_MapsApp.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import SwiftData
import AppIntents
import Segment
import CoreLocation
import AuthenticationServices
import TipKit

@main
struct Know_MapsApp: App {
    @State private var showOnboarding = true
    @State private var showSplashScreen = true
    @State private var showNavigationLocationView = false
    @State private var searchMode: SearchMode = .places
    // Centralized controller and manager
    @State private var cacheManager: CloudCacheManager
    @State private var modelController: DefaultModelController
    private let authenticationModel = AppleAuthenticationService.shared
    
    init() {
        let analytics = SegmentAnalyticsService.shared
        let cloudCache = CloudCacheService(analyticsManager: analytics, modelContext: ModelContext(Know_MapsAppView.sharedModelContainer))
        let cache = CloudCacheManager(cloudCacheService: cloudCache, analyticsManager: analytics)
        
        let assistiveHost = AssistiveChatHostService(
            analyticsManager: analytics,
            messagesDelegate: ChatResultViewModel.shared
        )
        
        let placeSearch = DefaultPlaceSearchService(
            assistiveHostDelegate: assistiveHost,
            placeSearchSession: PlaceSearchSession(),
            personalizedSearchSession: PersonalizedSearchSession(cloudCacheService: cloudCache),
            analyticsManager: analytics
        )
        
        let locationService = DefaultLocationService(locationProvider: LocationProvider.shared)
        let recommenderService = DefaultRecommenderService()
        let inputValidator = DefaultInputValidationServiceV2()
        let resultIndexer = DefaultResultIndexServiceV2()
        
        let model = DefaultModelController(
            assistiveHost: assistiveHost,
            locationService: locationService,
            placeSearchService: placeSearch,
            analyticsManager: analytics,
            recommenderService: recommenderService,
            cacheManager: cache,
            inputValidator: inputValidator,
            resultIndexer: resultIndexer
        )
        
        self._cacheManager = State(wrappedValue: cache)
        self._modelController = State(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup {
            Know_MapsAppView(
                modelController: modelController,
                cacheManager: cacheManager,
                showOnboarding: $showOnboarding,
                showSplashScreen: $showSplashScreen,
                showNavigationLocationView: $showNavigationLocationView,
                searchMode: $searchMode
            )
            .environmentObject(authenticationModel)
            .modelContainer(Know_MapsAppView.sharedModelContainer)
            .onOpenURL { url in
                let link = DeepLinkCoordinator.parse(url)
                modelController.handleDeepLink(link)
            }
        }

#if os(visionOS)
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
#endif
    }
}
