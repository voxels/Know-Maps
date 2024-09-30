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
    @State private var selectedOnboardingTab:String = "Sign In"
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    
    public var analytics:Analytics? = Analytics(configuration: Know_MapsApp.config)
    
    var body: some Scene {
        WindowGroup(id:"ContentView") {
            GeometryReader { geometry in
                
            if showSplashScreen{
                HStack(alignment: .center){
                    Spacer()
                    VStack(alignment: .center) {
                        Spacer()
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
                        Spacer()
                        ProgressView("Refreshing Lists", value: chatModel.cacheFetchProgress)
                            .frame(maxWidth:geometry.size.width / 2)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                }

#if os(visionOS) || os(macOS)
                .frame(minWidth: 1280, minHeight: 720)
#endif
                .task {
                    do {
                        try await startup(chatModel: chatModel)
                    } catch {
                        analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
            } else {
                if showOnboarding {
                    OnboardingView(chatHost: chatHost, chatModel: chatModel, locationProvider: chatModel.locationProvider, selectedTab: $selectedOnboardingTab, showOnboarding: $showOnboarding, isAuthorized: $isAuthorized, isOnboarded: $isOnboarded)
#if os(visionOS) || os(macOS)
                        .frame(minWidth: 1280, minHeight: 720)
#endif
                        .environmentObject(chatModel.cloudCache)
                        .environmentObject(settingsModel)
                        .environmentObject(chatModel.featureFlags)
                } else {
                    ContentView(chatHost: chatHost, chatModel: chatModel, locationProvider: chatModel.locationProvider, isOnboarded: $isOnboarded, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                        .frame(minWidth: 1280, minHeight: 720)
#endif
                        .environmentObject(chatModel.cloudCache)
                        .environmentObject(settingsModel)
                        .environmentObject(chatModel.featureFlags)
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
            if !chatModel.cloudCache.hasPrivateCloudAccess {
                let userRecord = try await chatModel.cloudCache.fetchCloudKitUserRecordID()
                settingsModel.keychainId = userRecord?.recordName
                chatModel.cloudCache.hasPrivateCloudAccess =  try await chatModel.retrieveFsqUser()
            }
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
            if isAuthorized, let location = chatModel.locationProvider.currentLocation() {
                let placemarkName = try await chatHost.languageDelegate.lookUpLocation(location: location)?.first?.name ?? "Current Location"
                chatModel.currentLocationResult.replaceLocation(with: location, name: placemarkName)
                chatModel.selectedDestinationLocationChatResult = chatModel.currentLocationResult.id
            }
            
            settingsModel.fetchSubscriptionOfferings()

            try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
            
            isOnboarded = !chatModel.cachedTasteResults.isEmpty
            
            if chatModel.cloudCache.hasPrivateCloudAccess, isAuthorized, isOnboarded {
                showOnboarding = false
                showSplashScreen = false
            } else if chatModel.cloudCache.hasPrivateCloudAccess, isAuthorized, !isOnboarded {
                selectedOnboardingTab = "Saving"
                showSplashScreen = false
            } else if chatModel.cloudCache.hasPrivateCloudAccess,
                      !isAuthorized, !isOnboarded {
                selectedOnboardingTab = "Location"
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
