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
    @StateObject public var chatHost:AssistiveChatHost = AssistiveChatHost()
    @StateObject public var chatModel:ChatResultViewModel = ChatResultViewModel(locationProvider: LocationProvider(), cloudCache: CloudCache(), featureFlags: FeatureFlags())
    public var analytics: Analytics = Analytics(configuration: Know_MapsApp.config)
    
    @State private var showOnboarding:Bool = true
    @State private var showSplashScreen:Bool = true
    @State private var selectedOnboardingTab:String = "Sign In"
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
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
                            ProgressView(value: chatModel.cacheFetchProgress)
                                .frame(maxWidth:geometry.size.width / 2)
                                .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                    .task {
                                            if settingsModel.isAuthorized {
                                                Task {
                                                    await startApp()
                                                }
                                            } else {
                                                settingsModel.authCompletion = { result in
                                                    if case .success = result {
                                                        Task {
                                                            await startApp()
                                                        }
                                                    } else if case .failure(let error) = result {
                                                        print(error)
                                                        chatModel.analytics?.track(name: "Error during startup", properties: ["error": error.localizedDescription])
                                                    }
                                                }
                                                
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
    
    private func startApp() async {
        await startup(chatModel: chatModel)
    }
    
    func performExistingAccountSetupFlows() {
        let requests = [ASAuthorizationAppleIDProvider().createRequest()]
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = settingsModel
        authorizationController.performRequests()
    }
    
    private func loadPurchases() async throws {
        let purchasesId =  settingsModel.purchasesId
        let revenuecatAPIKey = try await chatModel.cloudCache.apiKey(for: .revenuecat)
        Purchases.configure(withAPIKey: revenuecatAPIKey, appUserID: purchasesId)
        Purchases.shared.delegate = chatModel.featureFlags
        
        settingsModel.fetchSubscriptionOfferings()
        let customerInfo = try await Purchases.shared.customerInfo()
        chatModel.featureFlags.updateFlags(with: customerInfo)
    }
    
    private func startup(chatModel: ChatResultViewModel) async {
        chatModel.cloudCache.analytics = chatModel.analytics
        chatHost.analytics = chatModel.analytics
        chatModel.assistiveHostDelegate = chatHost
        chatHost.messagesDelegate = chatModel

        do {
            try await loadPurchases()
        } catch {
            print(error)
            chatModel.analytics?.track(name: "Error loading purchases", properties: ["error": error.localizedDescription])
        }
        await setupChatModel(chatModel)
        await loadData(chatModel)
    }

    private func setupChatModel(_ chatModel: ChatResultViewModel) async {
        // Perform setup tasks
        if !chatModel.cloudCache.hasFsqAccess {
            do {
                try await chatModel.retrieveFsqUser()

            } catch {
                print(error)
                chatModel.analytics?.track(name: "Error retrieving Foursquare user", properties: ["error": error.localizedDescription])
            }
        }
    }

    private func loadData(_ chatModel: ChatResultViewModel) async {
        Task {
            do {
                try await chatHost.organizeCategoryCodeList()
                await chatModel.categoricalSearchModel()
            } catch {
                print(error)
                chatModel.analytics?.track(name: "categorical_search_error")
            }
        }

        let cacheRefreshTask = Task {
            do {
                try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
            } catch {
                print(error)
                chatModel.analytics?.track(name: "cache_refresh_error", properties: ["error": error.localizedDescription])
            }
        }

        do {
            try await withTimeout(seconds: 10) {
                await cacheRefreshTask.value
            }
        } catch {
            cacheRefreshTask.cancel()
            chatModel.analytics?.track(name: "cache_refresh_timeout")
            print("Cache refresh timed out: \(error)")
        }

        // Handle onboarding logic based on the loaded data
        await self.handleOnboarding(chatModel)
    }

    private func handleOnboarding(_ chatModel: ChatResultViewModel) async {
        let cloudAuth = settingsModel.isAuthorized

        let isLocationAuthorized = chatModel.locationProvider.isAuthorized()

        if isLocationAuthorized, let location = chatModel.locationProvider.currentLocation() {
            await MainActor.run {
                chatModel.currentLocationResult.replaceLocation(with: location, name: "Current Location")
                chatModel.selectedDestinationLocationChatResult = chatModel.currentLocationResult.id
            }
        }
        
        let isOnboarded = !chatModel.cachedTasteResults.isEmpty || !chatModel.cachedPlaceResults.isEmpty || !chatModel.cachedCategoryResults.isEmpty
        
        await MainActor.run {
            if cloudAuth, chatModel.cloudCache.hasFsqAccess, isLocationAuthorized, isOnboarded {
                showOnboarding = false
            } else if cloudAuth, chatModel.cloudCache.hasFsqAccess, isLocationAuthorized, !isOnboarded {
                selectedOnboardingTab = "Saving"
            } else if cloudAuth, chatModel.cloudCache.hasFsqAccess, !isLocationAuthorized, !isOnboarded {
                selectedOnboardingTab = "Location"
            }
            
            showSplashScreen = false
        }
    }

    func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TaskTimeout", code: 1, userInfo: nil)
            }
            if let result = try await group.next() {
                group.cancelAll()
                return result
            } else {
                throw NSError(domain: "TaskTimeout", code: 1, userInfo: nil)
            }
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
