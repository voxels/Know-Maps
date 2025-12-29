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

@MainActor
public struct Know_MapsAppView : View {
    public static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserCachedRecord.self,
            RecommendationData.self,
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase:.private("iCloud.com.secretatomics.knowmaps.Cache"))
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State public var chatModel:ChatResultViewModel
    @State public var searchSavedViewModel:SearchSavedViewModel
    public var modelController:DefaultModelController
    public var cacheManager:CloudCacheManager
    @EnvironmentObject public var authenticationModel:AppleAuthenticationService
    @Binding public var showOnboarding:Bool
    @Binding public var showSplashScreen:Bool
    @Binding public var showNavigationLocationView:Bool
    @Binding public var searchMode:SearchMode
    
    public init(modelController:DefaultModelController, cacheManager:CloudCacheManager, showOnboarding:Binding<Bool>, showSplashScreen:Binding<Bool>, showNavigationLocationView:Binding<Bool>, searchMode:Binding<SearchMode>) {
        self.modelController = modelController
        self.cacheManager = cacheManager
        _showOnboarding = showOnboarding
        _showSplashScreen = showSplashScreen
        _showNavigationLocationView = showNavigationLocationView
        _searchMode = searchMode
        
        // Create required services locally first to avoid capturing self
        let chatModel = ChatResultViewModel.shared
        let searchSavedViewModel = SearchSavedViewModel.shared
        _ = AppleAuthenticationService.shared
        
        // Assign to stored properties using wrappedValue initializers only
        self._chatModel = State(wrappedValue: chatModel)
        self._searchSavedViewModel = State(wrappedValue: searchSavedViewModel)
        
        // Defer dependency registration to the next run loop to avoid capturing self during init
        DispatchQueue.main.async {
            AppDependencyManager.shared.add(dependency: cacheManager)
            AppDependencyManager.shared.add(dependency: modelController)
            AppDependencyManager.shared.add(dependency: chatModel)
        }
        
        /**
         Call `updateAppShortcutParameters` on `AppShortcutsProvider` so that the system updates the App Shortcut phrases with any changes to
         the app's intent parameters. The app needs to call this function during its launch, in addition to any time the parameter values for
         the shortcut phrases change.
         */
        //        KnowMapsShortcutsProvider.updateAppShortcutParameters()
        do {
            // Configure and load all tips in the app.
            try Tips.configure()
        }
        catch {
            print("Error initializing tips: \(error)")
        }
    }
    
    public var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(settingsModel: authenticationModel, modelController: modelController, showOnboarding: $showOnboarding)
                    .transition(.move(edge: .bottom))
#if !os(visionOS) && !os(macOS)
                    .containerBackground(.clear, for: .navigation)
#endif
            } else {
                MainUI(modelController: modelController, cacheManager: cacheManager)
                    .environmentObject(authenticationModel)
                    .transition(.opacity)
            }
            
            if showSplashScreen {
                Color.clear
                    .onAppear {
                        // Dismiss splash screen quickly for now
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation {
                                showSplashScreen = false
                            }
                        }
                    }
            }
        }
        .task(id: authenticationModel.appleUserId) {
            // As soon as we have a user ID, start populating the model
            if !authenticationModel.appleUserId.isEmpty {
                withAnimation {
                    showOnboarding = false
                }
                do {
                    try await cacheManager.restoreCache()
                    try await cacheManager.refreshCache()
                    print("Model populated for user: \(authenticationModel.appleUserId)")
                } catch {
                    print("Failed to populate model: \(error)")
                }
            } else {
                withAnimation {
                    showOnboarding = true
                }
            }
        }
    }
}
