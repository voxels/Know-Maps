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
import AuthenticationServices

@main
struct Know_MapsApp: App {
    @StateObject public var settingsModel = SettingsModel(userId: "")
    @StateObject public var chatHost:AssistiveChatHost = AssistiveChatHost( analytics: Analytics(configuration: Know_MapsApp.config))
    @StateObject public var chatModel:ChatResultViewModel = ChatResultViewModel(locationProvider: LocationProvider(), cloudCache: CloudCache(analytics:Analytics(configuration: Know_MapsApp.config)), featureFlags: FeatureFlags())
    
    
    @State private var showOnboarding:Bool = true
    @State private var showSplashScreen:Bool = true
    @State private var selectedOnboardingTab:String = "Sign In"
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    public let analytics = Analytics(configuration: Know_MapsApp.config)
    
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
                                .padding()
                            Spacer()
                            ProgressView("Refreshing Lists", value: chatModel.cacheFetchProgress)
                                .frame(maxWidth:geometry.size.width / 2)
                                .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                    .onAppear() {
                        settingsModel.authCompletion = { result in
                            if case .success = result {
                                Task {
                                    do {
                                        try await startup(chatModel: chatModel)
                                    } catch {
                                        print(error)
                                        analytics.track(name: "Error during startup", properties: ["error":error.localizedDescription])
                                    }
                                }
                            } else if case .failure = result {
                                print(result)
                                analytics.track(name: "Error during startup", properties: ["error":result])
                            }
                        }
                        
                        let cloudAuth = settingsModel.isAuthorized
                        
                        if cloudAuth {
                            Task {
                                do {
                                    try await startup(chatModel: chatModel)
                                } catch {
                                    print(error)
                                    analytics.track(name: "Error during startup", properties: ["error":error.localizedDescription])
                                }
                            }
                        } else {
                            performExistingAccountSetupFlows()
                        }
                    }
                    
#if os(visionOS) || os(macOS)
                    .frame(minWidth: 1280, minHeight: 720)
#endif
                } else {
                    if showOnboarding {
                        OnboardingView(chatHost: chatHost, chatModel: chatModel, locationProvider: chatModel.locationProvider, selectedTab: $selectedOnboardingTab, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                            .frame(minWidth: 1280, minHeight: 720)
#endif
                            .environmentObject(chatModel.cloudCache)
                            .environmentObject(settingsModel)
                            .environmentObject(chatModel.featureFlags)
                    } else {
                        ContentView(chatHost: chatHost, chatModel: chatModel, locationProvider: chatModel.locationProvider, showOnboarding: $showOnboarding)
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
            SettingsView(chatModel:chatModel, showOnboarding: $showOnboarding)
                .tag("Settings")
                .onChange(of: settingsModel.appleUserId, { oldValue, newValue in
                    
#if os(visionOS) || os(iOS)
                    if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                        analytics.identify(userId: vendorId.uuidString)
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
    
    func performExistingAccountSetupFlows() {
        let requests = [ASAuthorizationAppleIDProvider().createRequest()]
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = settingsModel
        authorizationController.performRequests()
    }
    
    private func startup(chatModel:ChatResultViewModel) async throws{
        do {
            chatModel.assistiveHostDelegate = chatHost
            chatHost.messagesDelegate = chatModel
            let cloudAuth = settingsModel.isAuthorized
            
            if !cloudAuth {
                return
            }
            
            let userRecord = try await chatModel.cloudCache.fetchCloudKitUserRecordID()
            await MainActor.run {
                settingsModel.keychainId = userRecord?.recordName
            }
            
            if !chatModel.cloudCache.hasFsqAccess {
                try await chatModel.retrieveFsqUser()
            }
#if DEBUG
            Purchases.logLevel = .debug
#endif
            Task.detached {
                let purchasesId = await settingsModel.purchasesId
                let revenuecatAPIKey = try await chatModel.cloudCache.apiKey(for: .revenuecat)
                Purchases.configure(withAPIKey: revenuecatAPIKey, appUserID: purchasesId)
                Purchases.shared.delegate = chatModel.featureFlags
                
                await settingsModel.fetchSubscriptionOfferings()
                let customerInfo = try await Purchases.shared.customerInfo()
                await chatModel.featureFlags.updateFlags(with: customerInfo)
            }
            
            let isLocationAuthorized = chatModel.locationProvider.isAuthorized()
            
            if isLocationAuthorized, let location = chatModel.locationProvider.currentLocation() {
                chatModel.currentLocationResult.replaceLocation(with: location, name: "Current Location")
                await MainActor.run {
                    chatModel.selectedDestinationLocationChatResult = chatModel.currentLocationResult.id
                }
            }
            
            Task {
                try await chatHost.organizeCategoryCodeList()
            }
            
            try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
            
            let isOnboarded = !chatModel.cachedTasteResults.isEmpty
            
            if cloudAuth, chatModel.cloudCache.hasFsqAccess, isLocationAuthorized, isOnboarded {
                await MainActor.run {
                    showOnboarding = false
                    showSplashScreen = false
                }
            } else if cloudAuth, chatModel.cloudCache.hasFsqAccess, isLocationAuthorized, !isOnboarded {
                await MainActor.run {
                    selectedOnboardingTab = "Saving"
                    showSplashScreen = false
                }
            } else if cloudAuth, chatModel.cloudCache.hasFsqAccess,
                      !isLocationAuthorized, !isOnboarded {
                await MainActor.run {
                    selectedOnboardingTab = "Location"
                    showSplashScreen = false
                }
            }
        } catch {
            analytics.track(name: "error \(error)")
            print(error)
        }
        await MainActor.run {
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
