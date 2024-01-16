//
//  Know_MapsApp.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import Segment

@main
struct Know_MapsApp: App {
    private var locationProvider = LocationProvider()
    @StateObject public var cloudCache:CloudCache  = CloudCache()
    @StateObject public var settingsModel = SettingsModel(userId: "")
    @StateObject public var chatHost:AssistiveChatHost = AssistiveChatHost()
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    public var analytics:Analytics? = Analytics(configuration: Know_MapsApp.config)
    
    var body: some Scene {
        WindowGroup(id:"ContentView") {
            ContentView(chatHost: chatHost, chatModel: ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache), locationProvider: locationProvider)
                .environmentObject(cloudCache)
                .environmentObject(settingsModel)
                .task { @MainActor in
                    do {
                        cloudCache.analytics = analytics
                        try? chatHost.organizeCategoryCodeList()
                        let userRecord = try await cloudCache.fetchCloudKitUserRecordID()
                        settingsModel.keychainId = userRecord?.recordName
                        if let keychainId = settingsModel.keychainId, !keychainId.isEmpty {
                            await MainActor.run {
                                cloudCache.hasPrivateCloudAccess = true
                            }
                        }
                    } catch {
                        analytics?.track(name: "error \(error)")
                        print(error)
                    }
                }
        }
        
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
}
