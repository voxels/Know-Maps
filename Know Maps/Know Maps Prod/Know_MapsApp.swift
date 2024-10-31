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
    
    @StateObject public var authenticationModel:AppleAuthenticationService
    @State public var chatModel:ChatResultViewModel
    @State public var searchSavedViewModel:SearchSavedViewModel
    @State public var cacheManager:CloudCacheManager
    @State public var modelController:DefaultModelController
    
    @State private var showReload:Bool = false
    @State private var showOnboarding:Bool = true
    @State private var showSplashScreen:Bool = true

    
    init() {
        let cacheManager = CloudCacheManager.shared
        let authModel = AppleAuthenticationService.shared
        let modelController = DefaultModelController.shared
        let searchSavedViewModel = SearchSavedViewModel()
        let chatModel = ChatResultViewModel.shared
        
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
                            if showReload {
                                Button("Reload") {
                                    Task(priority: .userInitiated) {
                                        await startApp()
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .task(priority:.userInitiated) {                        
                        checkIfSignedInWithApple { signedIn in
                            if signedIn {
                                Task {
                                    await startApp()
                                }
                            } else {
                                authenticationModel.authCompletion = { result in
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
                    }
                    
#if os(visionOS) || os(macOS)
                    .frame(minWidth: 1280, minHeight: 720)
#endif
                } else {
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
                }
            }
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
        await startup()
    }
    
    public func checkIfSignedInWithApple(completion:@escaping (Bool)->Void) {
        
        guard authenticationModel.isSignedIn(), !authenticationModel.appleUserId.isEmpty else {
            completion(false)
            return
        }
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        
        // Retrieve the credential state for the Apple ID credential
        appleIDProvider.getCredentialState(forUserID: authenticationModel.appleUserId) { (credentialState, error) in
            switch credentialState {
            case .authorized:
                completion(true)
            case .revoked, .notFound:
                fallthrough
            default:
                completion(false)
            }
        }
    }
    
    func performExistingAccountSetupFlows() {
        let requests = [ASAuthorizationAppleIDProvider().createRequest()]
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = authenticationModel
        authorizationController.performRequests()
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
//        do {
//            try await loadPurchases()
//        } catch {
//            modelController.analyticsManager.trackError(error: error, additionalInfo:nil)
//        }
        await retrieveUser()
        await loadData()
    }
    
    private func retrieveUser() async {
        // Perform setup tasks
        if !cacheManager.cloudCache.hasFsqAccess {
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
        let cloudAuth = !authenticationModel.appleUserId.isEmpty
        
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
