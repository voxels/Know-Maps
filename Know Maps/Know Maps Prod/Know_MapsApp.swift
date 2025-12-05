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
    @State public var chatModel:ChatResultViewModel
    @State public var searchSavedViewModel:SearchSavedViewModel
    @State public var cacheManager:CloudCacheManager
    @State public var modelController:DefaultModelController
    
    @State private var showOnboarding:Bool = true
    @State private var showSplashScreen:Bool = true
    @State private var isStoryrabbitEnabled:Bool = false
    @State private var isStartingApp = false
    @State private var didStartApp = false
    
    @State private var searchMode: SearchMode = .favorites
    @State private var showNavigationLocationView:Bool = false

    init() {
        // Create required services locally first to avoid capturing self
        let cloudCacheService = CloudCacheService(analyticsManager: SegmentAnalyticsService.shared, modelContext: Know_MapsApp.sharedModelContainer.mainContext)
        let cacheManager = CloudCacheManager(cloudCacheService: cloudCacheService)
        let modelController = DefaultModelController(cacheManager: cacheManager)
        let chatModel = ChatResultViewModel.shared
        let searchSavedViewModel = SearchSavedViewModel.shared

        // Assign to stored properties
        self._authenticationModel = StateObject(wrappedValue: AppleAuthenticationService.shared)
        self._chatModel = State(initialValue: chatModel)
        self._searchSavedViewModel = State(initialValue: searchSavedViewModel)
        self._cacheManager = State(initialValue: cacheManager)
        self._modelController = State(initialValue: modelController)

        // After self is fully initialized, schedule dependency registration on the main actor
        Task { @MainActor in
            AppDependencyManager.shared.add(dependency: cacheManager)
            AppDependencyManager.shared.add(dependency: modelController)
            AppDependencyManager.shared.add(dependency: chatModel)
        }

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
#if !os(visionOS) && !os(macOS)
                        .containerBackground(.clear, for: .navigation)
#endif
                        .toolbarBackgroundVisibility(self.showOnboarding ? .visible : .hidden)
                } else {
                    
                ContentView(settingsModel:authenticationModel, chatModel: $chatModel, cacheManager:$cacheManager, modelController:$modelController, searchSavedViewModel: $searchSavedViewModel, showOnboarding: $showOnboarding, showNavigationLocationView: $showNavigationLocationView,searchMode: $searchMode )
#if os(visionOS) || os(macOS)
                    .frame(minWidth: 1280, minHeight: 720)
#endif
                    .sheet(isPresented: $showNavigationLocationView) {
                        filterSheet()
                    }
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
                    .task(priority:.userInitiated) {
                        checkIfSignedInWithApple { signedIn in
                            if signedIn, modelController.locationService.locationProvider.isAuthorized()  {
                                Task {
                                    await startApp()
                                }
                            } else {
                                showSplashScreen = false
                                showOnboarding = true
                            }
                        }
                    }
#if os(visionOS) || os(macOS)
                    .frame(minWidth: 1280, minHeight: 720)
#endif
                }
            }
        }.windowResizability(.contentSize)
        
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
        Task(priority: .userInitiated) { @MainActor in
            let requests = [ASAuthorizationAppleIDProvider().createRequest()]
            let authorizationController = ASAuthorizationController(authorizationRequests: requests)
            authorizationController.delegate = authenticationModel
            authorizationController.presentationContextProvider = authenticationModel
            authorizationController.performRequests()
        }
    }
    
    // Await a valid access token before proceeding with network-dependent startup work
    private func ensureValidAccessToken() async {
        let token = await authenticationModel.getValidAccessTokenAsync()
        if token == nil {
            // Log error when token refresh fails
            print("⚠️ Failed to get valid access token during startup")
            modelController.analyticsManager.trackError(
                error: NSError(domain: "com.knowmaps.auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Token refresh failed during startup"]),
                additionalInfo: nil
            )
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
        await modelController.categoricalSearchModel()
        
        let cacheRefreshTask = Task { @MainActor in
            do {
                try await cacheManager.refreshCache()
                if cacheManager.allCachedResults.isEmpty {
                    try await cacheManager.restoreCache()
                }

                // Update result indexer with fresh cached data after cache refresh
                modelController.resultIndexer.updateIndex(
                    placeResults: modelController.placeResults,
                    recommendedPlaceResults: modelController.recommendedPlaceResults,
                    relatedPlaceResults: modelController.relatedPlaceResults,
                    industryResults: modelController.industryResults,
                    tasteResults: modelController.tasteResults,
                    cachedIndustryResults: cacheManager.cachedIndustryResults,
                    cachedPlaceResults: cacheManager.cachedPlaceResults,
                    cachedTasteResults: cacheManager.cachedTasteResults,
                    cachedDefaultResults: cacheManager.cachedDefaultResults,
                    cachedRecommendationData: cacheManager.cachedRecommendationData
                )
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
    }
    
    @MainActor
    private func ensureLocationAuthorizedAndSetCurrent() async {
        if !modelController.locationService.locationProvider.isAuthorized() {
            await modelController.locationService.locationProvider.requestAuthorizationIfNeeded()
        }
        
        guard modelController.locationService.locationProvider.isAuthorized() else {
            return
        }
        
        modelController.setSelectedLocation(nil)
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
    
    func filterView() -> some View {
        NavigationLocationView(
            searchSavedViewModel: $searchSavedViewModel,
            chatModel: $chatModel,
            cacheManager: $cacheManager,
            modelController: $modelController,
            filters:$searchSavedViewModel.filters
        )
    }
    
    @ViewBuilder
    func filterSheet() -> some View {
#if os(macOS)
        filterView()
            .frame(minWidth: 600, minHeight: 500)
            .presentationSizing(.fitted)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
#else
        filterView()
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
            .presentationCompactAdaptation(.sheet)
#endif
    }
}
