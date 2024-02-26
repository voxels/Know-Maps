//
//  Know_MapsApp.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import Segment
import RevenueCat

@main
struct Know_MapsApp: App {
    private var locationProvider = LocationProvider()
    @StateObject public var cloudCache:CloudCache  = CloudCache()
    @StateObject public var settingsModel = SettingsModel(userId: "")
    @StateObject public var chatHost:AssistiveChatHost = AssistiveChatHost()
    @StateObject public var featureFlags = FeatureFlags()
    
    @State private var showOnboarding:Bool = true
    @State private var showSplashScreen:Bool = true
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    
    public var analytics:Analytics? = Analytics(configuration: Know_MapsApp.config)
    
    var body: some Scene {
        
        let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
        WindowGroup(id:"ContentView") {
            if showSplashScreen{
                ZStack {
                    VStack{
                        Text("Welcome to Know Maps").bold().padding()
                        Image(systemName: "map.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width:100 , height: 100)
                    }
                }.frame(minWidth: 1200, minHeight: 1000)
                .task {
                    do{
                        try await startup(chatModel: chatModel)
                    } catch{
                        analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
                .onChange(of: showOnboarding, { oldValue, newValue in
                    Task{
                        if !cloudCache.hasPrivateCloudAccess {
                            let userRecord = try await cloudCache.fetchCloudKitUserRecordID()
                            settingsModel.keychainId = userRecord?.recordName
                            cloudCache.hasPrivateCloudAccess =  try await chatModel.retrieveFsqUser()
                            let customerInfo = try await Purchases.shared.customerInfo()
                            chatModel.featureFlags.updateFlags(with: customerInfo)
                        }
                    }
                })
            } else {
                if showOnboarding{
                    OnboardingView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, showOnboarding: $showOnboarding)
                        .frame(minWidth: 1200, minHeight: 1000)
                        .environmentObject(cloudCache)
                        .environmentObject(settingsModel)
                        .environmentObject(featureFlags)
                } else {
                ContentView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)                        
                        .task {
                            do{
                                let customerInfo = try await Purchases.shared.customerInfo()
                                chatModel.featureFlags.updateFlags(with: customerInfo)
                            } catch {
                                analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                        .frame(minWidth: 1200, minHeight:1000)
                    .environmentObject(cloudCache)
                    .environmentObject(settingsModel)
                    .environmentObject(featureFlags)
                }
            }
        }.windowResizability(.contentSize)
        
        WindowGroup(id:"SettingsView"){
            SettingsView()
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
        .environmentObject(cloudCache)
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
            cloudCache.analytics = analytics
            try? chatHost.organizeCategoryCodeList()
            let userRecord = try await cloudCache.fetchCloudKitUserRecordID()
            settingsModel.keychainId = userRecord?.recordName
            cloudCache.hasPrivateCloudAccess =  try await chatModel.retrieveFsqUser()
            #if DEBUG
            Purchases.logLevel = .debug
            #endif
            let purchasesId = settingsModel.purchasesId
            let revenuecatAPIKey = try await cloudCache.apiKey(for: .revenuecat)
            Purchases.configure(withAPIKey: revenuecatAPIKey, appUserID: purchasesId)
            Purchases.shared.delegate = chatModel.featureFlags
            let customerInfo = try await Purchases.shared.customerInfo()
            chatModel.featureFlags.updateFlags(with: customerInfo)
            if cloudCache.hasPrivateCloudAccess {
                showOnboarding = false
            }
            settingsModel.fetchSubscriptionOfferings()
            showSplashScreen = false
        } catch {
            switch error {
            case PersonalizedSearchSessionError.NoTokenFound:
                analytics?.track(name: "error \(error)")
                print(error)
            default:
                settingsModel.keychainId = nil
                cloudCache.hasPrivateCloudAccess =  false
                analytics?.track(name: "error \(error)")
                print(error)
            }
            showSplashScreen = false
        }
    }
}
