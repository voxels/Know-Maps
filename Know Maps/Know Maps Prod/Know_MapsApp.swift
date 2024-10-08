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
    
    static let sharedModelContainer: ModelContainer = {
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
    
    @StateObject public var settingsModel:AppleAuthenticationService
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var searchSavedViewModel:SearchSavedViewModel
    @StateObject public var cacheManager:CloudCacheManager
    @StateObject public var modelController:DefaultModelController
    
    @State private var showOnboarding:Bool = true
    @State private var showSplashScreen:Bool = true
    @State private var selectedOnboardingTab:String = "Sign In"

    
    init() {
        _cacheManager = StateObject(wrappedValue: CloudCacheManager.shared)
        _settingsModel = StateObject(wrappedValue: AppleAuthenticationService(userId: ""))
        _modelController = StateObject(wrappedValue: DefaultModelController.shared)
        _searchSavedViewModel = StateObject(wrappedValue: SearchSavedViewModel())
        _chatModel = StateObject(wrappedValue:ChatResultViewModel.shared)
        
        AppDependencyManager.shared.add(dependency: CloudCacheManager.shared)
        AppDependencyManager.shared.add(dependency: DefaultModelController.shared)
        AppDependencyManager.shared.add(dependency: ChatResultViewModel.shared)
        
        /**
         Call `updateAppShortcutParameters` on `AppShortcutsProvider` so that the system updates the App Shortcut phrases with any changes to
         the app's intent parameters. The app needs to call this function during its launch, in addition to any time the parameter values for
         the shortcut phrases change.
         */
        KnowMapsShortcutsProvider.updateAppShortcutParameters()
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
                            let cacheFetchProgress = max(cacheManager.cacheFetchProgress, 0)
                            ProgressView(value: cacheFetchProgress)
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
                                    modelController.analyticsManager.trackError(error: error, additionalInfo: ["error": error.localizedDescription])
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
                        OnboardingView( chatModel: chatModel, modelController: modelController, selectedTab: $selectedOnboardingTab, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                            .frame(minWidth: 1280, minHeight: 720)
#endif
                            .environmentObject(settingsModel)
                    } else {
                        ContentView(chatModel: chatModel, cacheManager:cacheManager, modelController:modelController, searchSavedViewModel: searchSavedViewModel, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                            .frame(minWidth: 1280, minHeight: 720)
#endif
                            .environmentObject(settingsModel)
                    }
                }
            }
        }.windowResizability(.contentSize)
        
        WindowGroup(id:"SettingsView"){
            SettingsView(chatModel:chatModel, cacheManager: cacheManager, modelController: modelController, showOnboarding: $showOnboarding)
                .tag("Settings")
                .onChange(of: settingsModel.appleUserId, { oldValue, newValue in
                    
#if os(visionOS) || os(iOS)
                    if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                        modelController.analyticsManager.identify(userID: vendorId.uuidString)
                    }
#endif
                })
        }
        .environmentObject(settingsModel)
        .modelContainer(Know_MapsApp.sharedModelContainer)
        
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
//        do {
//            try await loadPurchases()
//        } catch {
//            modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
//        }
        modelController.assistiveHostDelegate.messagesDelegate = chatModel
        await setupChatModel(chatModel)
        await loadData(chatModel)
    }
    
    private func setupChatModel(_ chatModel: ChatResultViewModel) async {
        // Perform setup tasks
        if !cacheManager.cloudCache.hasFsqAccess {
            do {
                try await modelController.placeSearchService.retrieveFsqUser(cacheManager: cacheManager)
                
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
            }
        }
    }
    
    private func loadData(_ chatModel: ChatResultViewModel) async {
        Task {
            do {
                try await modelController.assistiveHostDelegate.organizeCategoryCodeList()
                await modelController.categoricalSearchModel()
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
            }
        }
        
        let cacheRefreshTask = Task {
            do {
                try await cacheManager.refreshCache()
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
            }
        }
        
        do {
            try await withTimeout(seconds: 10) {
                await cacheRefreshTask.value
            }
        } catch {
            cacheRefreshTask.cancel()
            modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
        }
        
        // Handle onboarding logic based on the loaded data
        await self.handleOnboarding(chatModel)
    }
    
    private func handleOnboarding(_ chatModel: ChatResultViewModel) async {
        let cloudAuth = settingsModel.isAuthorized
        
        let isLocationAuthorized = modelController.locationProvider.isAuthorized()
        
        if isLocationAuthorized, let location = modelController.locationProvider.currentLocation() {
            await MainActor.run {
                modelController.currentLocationResult.replaceLocation(with: location, name: "Current Location")
                modelController.selectedDestinationLocationChatResult = modelController.currentLocationResult.id
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
