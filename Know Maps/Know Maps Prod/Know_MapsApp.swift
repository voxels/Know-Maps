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
//import GoogleMobileAds

#if os(iOS)
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    //GADMobileAds.sharedInstance().start(completionHandler: nil)

    return true
  }
}
#endif

@main
struct Know_MapsApp: App {
    
//    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject public var settingsModel:AppleAuthenticationService
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var searchSavedViewModel:SearchSavedViewModel
    @StateObject public var cacheManager:CloudCacheManager
    
    @State private var showOnboarding:Bool = true
    @State private var showSplashScreen:Bool = true
    @State private var selectedOnboardingTab:String = "Sign In"
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    init() {
        let analyticsManager = SegmentAnalyticsService(analytics: Analytics(configuration: Know_MapsApp.config))
         // Safely initialize chatModel first
         let chatModel = ChatResultViewModel(modelController: DefaultModelController(
             locationProvider: LocationProvider(),
             analyticsManager:analyticsManager)
         )
         
         // Now safely initialize searchSavedViewModel using chatModel
         _cacheManager = StateObject(wrappedValue: CloudCacheManager(cloudCache: CloudCacheService(analyticsManager: analyticsManager), analyticsManager: analyticsManager))
         _settingsModel = StateObject(wrappedValue: AppleAuthenticationService(userId: ""))
         _chatModel = StateObject(wrappedValue: chatModel)
         _searchSavedViewModel = StateObject(wrappedValue: SearchSavedViewModel(chatModel: chatModel))
     }
    
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
                            ProgressView(value: cacheManager.cacheFetchProgress)
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
                                                        chatModel.modelController.analyticsManager.trackError(error: error, additionalInfo: ["error": error.localizedDescription])
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
                        OnboardingView( chatModel: chatModel, selectedTab: $selectedOnboardingTab, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                            .frame(minWidth: 1280, minHeight: 720)
#endif
                            .environmentObject(settingsModel)
                    } else {
                        ContentView(chatModel: chatModel, cacheManager:cacheManager, searchSavedViewModel: searchSavedViewModel, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                            .frame(minWidth: 1280, minHeight: 720)
#endif
                            .environmentObject(settingsModel)
                    }
                }
            }
        }.windowResizability(.contentSize)
        
        WindowGroup(id:"SettingsView"){
            SettingsView(chatModel:chatModel, cacheManager: cacheManager, showOnboarding: $showOnboarding)
                .tag("Settings")
                .onChange(of: settingsModel.appleUserId, { oldValue, newValue in
                    
#if os(visionOS) || os(iOS)
                    if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                        chatModel.modelController.analyticsManager.identify(userID: vendorId.uuidString)
                    }
#endif
                })
        }
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
        let revenuecatAPIKey = try await cacheManager.cloudCache.apiKey(for: .revenuecat)
        Purchases.configure(withAPIKey: revenuecatAPIKey, appUserID: purchasesId)
        Purchases.shared.delegate = FeatureFlagService.shared
        
        settingsModel.fetchSubscriptionOfferings()
        let customerInfo = try await Purchases.shared.customerInfo()
        FeatureFlagService.shared.updateFlags(with: customerInfo)
    }
    
    private func startup(chatModel: ChatResultViewModel) async {
        do {
            try await loadPurchases()
        } catch {
            chatModel.modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
        }
        await setupChatModel(chatModel)
        await loadData(chatModel)
    }

    private func setupChatModel(_ chatModel: ChatResultViewModel) async {
        // Perform setup tasks
        if !cacheManager.cloudCache.hasFsqAccess {
            do {
                try await chatModel.modelController.placeSearchService.retrieveFsqUser(cacheManager: cacheManager)

            } catch {
                chatModel.modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
            }
        }
    }

    private func loadData(_ chatModel: ChatResultViewModel) async {
        Task {
            do {
                try await chatModel.modelController.assistiveHostDelegate.organizeCategoryCodeList()
                await chatModel.modelController.categoricalSearchModel()
            } catch {
                chatModel.modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
            }
        }

        let cacheRefreshTask = Task {
            do {
                try await cacheManager.refreshCache()
            } catch {
                chatModel.modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
            }
        }

        do {
            try await withTimeout(seconds: 10) {
                await cacheRefreshTask.value
            }
        } catch {
            cacheRefreshTask.cancel()
            chatModel.modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
        }

        // Handle onboarding logic based on the loaded data
        await self.handleOnboarding(chatModel)
    }

    private func handleOnboarding(_ chatModel: ChatResultViewModel) async {
        let cloudAuth = settingsModel.isAuthorized

        let isLocationAuthorized = chatModel.modelController.locationProvider.isAuthorized()

        if isLocationAuthorized, let location = chatModel.modelController.locationProvider.currentLocation() {
            await MainActor.run {
                chatModel.modelController.currentLocationResult.replaceLocation(with: location, name: "Current Location")
                chatModel.modelController.selectedDestinationLocationChatResult = chatModel.modelController.currentLocationResult.id
            }
        }
                
        await MainActor.run {
            if cloudAuth, cacheManager.cloudCache.hasFsqAccess, isLocationAuthorized {
                showOnboarding = false
            }else if cloudAuth, cacheManager.cloudCache.hasFsqAccess, !isLocationAuthorized {
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
