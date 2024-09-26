//
//  Know_MapsApp.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import Segment
import RevenueCat
import CoreLocation

@main
struct Know_MapsApp: App {
    @StateObject public var settingsModel = SettingsModel(userId: "")
    @StateObject public var chatHost:AssistiveChatHost = AssistiveChatHost()
    @StateObject public var chatModel:ChatResultViewModel = ChatResultViewModel(locationProvider: LocationProvider(), cloudCache: CloudCache(), featureFlags: FeatureFlags())
    
    @State private var showOnboarding:Bool = true
    @State private var isAuthorized:Bool = false
    @State private var isOnboarded:Bool = false
    @State private var showSplashScreen:Bool = true
    @State private var selectedTab:String = "Sign In"
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    
    public var analytics:Analytics? = Analytics(configuration: Know_MapsApp.config)
    
    
    var body: some Scene {
        WindowGroup(id:"ContentView") {
            if showSplashScreen{
                ZStack {
                    VStack{
                        Text("Welcome to Know Maps").bold().padding()
                        Image("logo_macOS_512")
                            .resizable()
                            .scaledToFit()
                            .frame(width:100 , height: 100)
                        
                        if !chatModel.locationProvider.isAuthorized() {
                            Text("Know Maps requires access to your location. Please allow access to your location in System Preferences.")
                            Button(action: {
                                openLocationPreferences()
                            }, label: {
                                Label("Allow Access", systemImage: "arrow.2.circlepath.circle")
                            })
                        }
                    }
                }
#if os(visionOS) || os(macOS)
                .frame(minWidth: 1280, minHeight: 720)
#endif
                .task {
                    do {
                        try await startup(chatModel: chatModel)
                        try await chatModel.refreshSessions()
                        if !chatModel.cloudCache.hasPrivateCloudAccess {
                            let userRecord = try await chatModel.cloudCache.fetchCloudKitUserRecordID()
                            settingsModel.keychainId = userRecord?.recordName
                            chatModel.cloudCache.hasPrivateCloudAccess =  try await chatModel.retrieveFsqUser()
                            let customerInfo = try await Purchases.shared.customerInfo()
                            chatModel.featureFlags.updateFlags(with: customerInfo)
                        }
                    } catch {
                        analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            } else {
                if showOnboarding {
                    OnboardingView(chatHost: chatHost, chatModel: chatModel, locationProvider: chatModel.locationProvider, selectedTab: $selectedTab, showOnboarding: $showOnboarding, isAuthorized: $isAuthorized, isOnboarded: $isOnboarded)
#if os(visionOS) || os(macOS)
                        .frame(minWidth: 1280, minHeight: 720)
#endif
                        .environmentObject(chatModel.cloudCache)
                        .environmentObject(settingsModel)
                        .environmentObject(chatModel.featureFlags)
                        .task { @MainActor in
                            do {
                                try await chatModel.retrieveFsqUser()
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                            
                            do {
                                try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                } else {
                    ContentView(chatHost: chatHost, chatModel: chatModel, locationProvider: chatModel.locationProvider, isOnboarded: $isOnboarded, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                        .frame(minWidth: 1280, minHeight: 720)                    #endif
                        .environmentObject(chatModel.cloudCache)
                        .environmentObject(settingsModel)
                        .environmentObject(chatModel.featureFlags)
                        .task { @MainActor in
                            do {
                                try await chatModel.retrieveFsqUser()
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                                                        
                            do {
                                try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                var uuid = UUID()
                                var minDistance = Double.greatestFiniteMagnitude
                                for cachedLocation in chatModel.cachedLocationResults {
                                    if let currentLocation = chatModel.locationProvider.currentLocation(), let location = cachedLocation.location {
                                        if location.distance(from: currentLocation) < minDistance {
                                            uuid = cachedLocation.id
                                            minDistance = location.distance(from:currentLocation)
                                        }
                                    }
                                }
                                chatModel.selectedDestinationLocationChatResult = uuid
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                            
                        }
                }
            }
        }.windowResizability(.contentSize)
        
        WindowGroup(id:"SettingsView"){
            SettingsView(chatModel:chatModel, isOnboarded: $isOnboarded, showOnboarding: $showOnboarding)
                .tag("Settings")
                .onChange(of: settingsModel.appleUserId, { oldValue, newValue in
                    
#if os(visionOS) || os(iOS)
                    if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                        analytics?.identify(userId: vendorId.uuidString)
                    }
#endif
#if os(macOS)
                    
#endif
                })
        }
        .environmentObject(chatModel.cloudCache)
        .environmentObject(settingsModel)
        
#if os(visionOS)
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
#endif
    }
    
    @MainActor
    private func startup(chatModel:ChatResultViewModel)async throws{
        do {
            chatModel.assistiveHostDelegate = chatHost
            chatHost.messagesDelegate = chatModel
            chatModel.cloudCache.analytics = analytics
            try? chatHost.organizeCategoryCodeList()
            let userRecord = try await chatModel.cloudCache.fetchCloudKitUserRecordID()
            settingsModel.keychainId = userRecord?.recordName
            chatModel.cloudCache.hasPrivateCloudAccess =  try await chatModel.retrieveFsqUser()
#if DEBUG
            Purchases.logLevel = .debug
#endif
            let purchasesId = settingsModel.purchasesId
            let revenuecatAPIKey = try await chatModel.cloudCache.apiKey(for: .revenuecat)
            Purchases.configure(withAPIKey: revenuecatAPIKey, appUserID: purchasesId)
            Purchases.shared.delegate = chatModel.featureFlags
            let customerInfo = try await Purchases.shared.customerInfo()
            chatModel.featureFlags.updateFlags(with: customerInfo)
            isAuthorized = chatModel.locationProvider.isAuthorized()
            settingsModel.fetchSubscriptionOfferings()
            
            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
            
            isOnboarded = !chatModel.cachedTasteResults.isEmpty
            
            if chatModel.cloudCache.hasPrivateCloudAccess, isAuthorized, isOnboarded {
                showOnboarding = false
                showSplashScreen = false
            } else if chatModel.cloudCache.hasPrivateCloudAccess, isAuthorized, !isOnboarded {
                selectedTab = "Saving"
                showSplashScreen = false
            } else if chatModel.cloudCache.hasPrivateCloudAccess,
                      !isAuthorized, !isOnboarded {
                chatModel.locationProvider.authorize()
                selectedTab = "Saving"
                showSplashScreen = false
            }
        } catch {
            switch error {
            case PersonalizedSearchSessionError.NoTokenFound:
                analytics?.track(name: "error \(error)")
                print(error)
            default:
                settingsModel.keychainId = nil
                chatModel.cloudCache.hasPrivateCloudAccess =  false
                analytics?.track(name: "error \(error)")
                print(error)
            }
            showSplashScreen = false
        }
    }
    
#if os(macOS)
public func openLocationPreferences() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
        NSWorkspace.shared.open(url)
    }
}
#else
func openLocationPreferences() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
#endif
}
