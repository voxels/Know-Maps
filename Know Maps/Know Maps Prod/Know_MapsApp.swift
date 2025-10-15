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

#if os(iOS)
//import GoogleMobileAds

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
    
    @StateObject public var authenticationModel:AppleAuthenticationService = AppleAuthenticationService.shared
    @State public var chatModel:ChatResultViewModel = ChatResultViewModel.shared
    @State public var searchSavedViewModel:SearchSavedViewModel = SearchSavedViewModel.shared
    @State public var cacheManager:CloudCacheManager
    @State public var modelController:DefaultModelController
    
    @State private var showReload:Bool = false
    @State private var showOnboarding:Bool = false
    @State private var showSplashScreen:Bool = true
    @State private var isStoryrabbitEnabled:Bool = false
    @State private var isStartingApp = false
    @State private var didStartApp = false
    
    init() {
        let authModel = AppleAuthenticationService.shared
        let searchSavedViewModel = SearchSavedViewModel()
        let chatModel = ChatResultViewModel.shared
        let modelController = DefaultModelController(locationProvider:LocationProvider.shared, analyticsManager: SegmentAnalyticsService.shared, cloudCacheService: CloudCacheService(analyticsManager: SegmentAnalyticsService.shared, modelContext: Know_MapsApp.sharedModelContainer.mainContext), messagesDelegate: chatModel)
        let cacheManager = CloudCacheManager(analyticsManager: modelController.analyticsManager, modelContext: Know_MapsApp.sharedModelContainer.mainContext)
        
        _cacheManager = State(wrappedValue: cacheManager)
        _authenticationModel = StateObject(wrappedValue: authModel)
        _modelController = State(wrappedValue: modelController)
        _searchSavedViewModel = State(wrappedValue: searchSavedViewModel)
        _chatModel = State(wrappedValue: chatModel)
        
        AppDependencyManager.shared.add(dependency: cacheManager)
        AppDependencyManager.shared.add(dependency: modelController)
        AppDependencyManager.shared.add(dependency: chatModel)
        
        /**
         Call `updateAppShortcutParameters` on `AppShortcutsProvider` so that the system updates the App Shortcut phrases with any changes to
         the app's intent parameters. The app needs to call this function during its launch, in addition to any time the parameter values for
         the shortcut phrases change.
         */
        KnowMapsShortcutsProvider.updateAppShortcutParameters()
        do {
            // Configure and load all tips in the app.
            try Tips.configure()
        }
        catch {
            print("Error initializing tips: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup(id:"ContentView") {
            ZStack {
                if showOnboarding {
                    OnboardingView( settingsModel: authenticationModel, chatModel: $chatModel, modelController: $modelController, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                        .frame(minWidth: 1280, minHeight: 720)
#endif
                } else {
                    
                    ContentView(settingsModel:authenticationModel, chatModel: $chatModel, cacheManager:$cacheManager, modelController:$modelController, searchSavedViewModel: $searchSavedViewModel, showOnboarding: $showOnboarding)
#if os(visionOS) || os(macOS)
                        .frame(minWidth: 1280, minHeight: 720)
#endif
                }
                
                if showSplashScreen {
                    ZStack(alignment: .center){
                        Rectangle()
                            .fill(.background)
                            .ignoresSafeArea()
                        VStack(alignment: .center) {
                            Spacer()
                            let text = "Welcome to Know Maps"
                            Text(text).bold().padding()
                            Image("logo_macOS_512")
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .frame(width:100 , height: 100)
                                .padding()
                            Spacer()
                            let cacheFetchProgress = max(cacheManager.cacheFetchProgress, 0)
                            ProgressView(value: cacheFetchProgress) {
                                Text("Login in progress...")
                            }
                            .padding()
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task(priority:.utility) {
                checkIfSignedInWithApple { signedIn in
                    if signedIn, modelController.locationProvider.isAuthorized()  {
                        Task {
                            await startApp()
                        }
                    } else {
                        showSplashScreen = false
                        showOnboarding = true
                    }
                }
            }
#if !os(visionOS) && !os(macOS)
            .containerBackground(.clear, for: .navigation)
#endif
            .toolbarBackgroundVisibility(self.showOnboarding ? .visible : .hidden)
        }.windowResizability(.contentSize)
        
        WindowGroup(id:"SettingsView"){
            SettingsView(model:authenticationModel, chatModel:$chatModel, cacheManager: $cacheManager, modelController: $modelController, showOnboarding: $showOnboarding)
                .tag("Settings")
                .onChange(of: authenticationModel.appleUserId, { oldValue, newValue in
                    
#if os(visionOS) || os(iOS)
                    if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                        modelController.analyticsManager.identify(userID: vendorId.uuidString)
                    }
#endif
                })
        }
        .modelContainer(Know_MapsApp.sharedModelContainer)
        
#if os(visionOS)
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
#endif
    }
    
    private func startApp() async {
        guard !isStartingApp else {
            return
        }
        
        isStartingApp = true
        await startup()
        isStartingApp = false
    }
    
    public func checkIfSignedInWithApple(completion:@escaping (Bool)->Void) {
        guard authenticationModel.isSignedIn(), !authenticationModel.appleUserId.isEmpty else {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        
        // Retrieve the credential state for the Apple ID credential
        appleIDProvider.getCredentialState(forUserID: authenticationModel.appleUserId) { (credentialState, error) in
            switch credentialState {
            case .authorized:
                DispatchQueue.main.async {
                    completion(true)
                }
            case .revoked, .notFound:
                fallthrough
            default:
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    func performExistingAccountSetupFlows() {
        // Kick off authorization work on the main actor but at a utility priority to avoid QoS inversion
        Task(priority: .utility) { @MainActor in
            let requests = [ASAuthorizationAppleIDProvider().createRequest()]
            let authorizationController = ASAuthorizationController(authorizationRequests: requests)
            authorizationController.delegate = authenticationModel
            authorizationController.presentationContextProvider = authenticationModel
            authorizationController.performRequests()
        }
    }
    
    // Await a valid access token before proceeding with network-dependent startup work
    private func ensureValidAccessToken() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            authenticationModel.getValidAccessToken { _ in
                continuation.resume(returning: ())
            }
        }
    }
    
    /*
     private func loadPurchases() async throws {
     let purchasesId =  settingsModel.purchasesId
     let revenuecatAPIKey = try await cacheManager.cloudCache.apiKey(for: .revenuecat)
     Purchases.configure(withAPIKey: revenuecatAPIKey, appUserID: purchasesId)
     Purchases.shared.delegate = FeatureFlagService.shared
     
     settingsModel.fetchSubscriptionOfferings()
     let customerInfo = try await Purchases.shared.customerInfo()
     FeatureFlagService.shared.updateFlags(with: customerInfo)
     }*/
    
    private func startup() async {
        await ensureValidAccessToken()
        //        do {
        //            try await loadPurchases()
        //        } catch {
        //            modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
        //        }
        await retrieveUser()
        await ensureLocationAuthorizedAndSetCurrent()
        await loadData()
        await enter()
    }
    
    @MainActor
    private func enter() async {
        showOnboarding = false
        showSplashScreen = false
    }
    
    private func retrieveUser() async {
        // Perform setup tasks
        if !cacheManager.cloudCacheService.hasFsqAccess {
            do {
                try await modelController.placeSearchService.retrieveFsqUser(cacheManager: cacheManager)
                
            } catch {
                modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
            }
        }
    }
    
    private func loadData() async {
        Task {
            await modelController.categoricalSearchModel()
        }
        
        let cacheRefreshTask = Task { @MainActor in
            do {
                try await cacheManager.refreshCache()
                if cacheManager.allCachedResults.isEmpty {
                    try await cacheManager.restoreCache()
                }
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
            showReload.toggle()
            modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
        }
        
        // Handle onboarding logic based on the loaded data
        await self.handleOnboarding(chatModel)
    }
    
    private func handleOnboarding(_ chatModel: ChatResultViewModel) async {
        if modelController.locationProvider.isAuthorized()  {
            Task { @MainActor in
                do {
                    let location = modelController.locationService.currentLocation()
                    let name = try await modelController.locationService.currentLocationName()
                    modelController.currentlySelectedLocationResult.replaceLocation(with: location, name: name ?? "Current location")
                    modelController.selectedDestinationLocationChatResult = modelController.currentlySelectedLocationResult.id
                }
                catch {
                    modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
                }
            }
        }
        
    }
    
    @MainActor
    private func ensureLocationAuthorizedAndSetCurrent() async {
        if !modelController.locationProvider.isAuthorized() {
            await modelController.locationProvider.requestAuthorizationIfNeeded()
        }
        
        guard modelController.locationProvider.isAuthorized() else {
            return
        }
        
        do {
            let location = modelController.locationService.currentLocation()
            let name = try await modelController.locationService.currentLocationName()
            modelController.currentlySelectedLocationResult.replaceLocation(with: location, name: name ?? "Current location")
            modelController.selectedDestinationLocationChatResult = modelController.currentlySelectedLocationResult.id
        } catch {
            modelController.analyticsManager.trackError(error: error, additionalInfo: ["context": "ensureLocationAuthorizedAndSetCurrent"])
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

