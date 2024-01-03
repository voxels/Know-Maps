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
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    public var analytics:Analytics? = Analytics(configuration: Know_MapsApp.config)
    
    var body: some Scene {
        WindowGroup(id:"ContentView") {
            ContentView(chatHost: AssistiveChatHost(), chatModel: ChatResultViewModel(locationProvider: locationProvider), locationProvider: locationProvider)
                .task {
                    let getquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                   kSecAttrApplicationTag as String: SettingsModel.tag,
                                                   kSecReturnData as String: true]
                    
                    var item: CFTypeRef?
                    let status = SecItemCopyMatching(getquery as CFDictionary, &item)
                    guard status == errSecSuccess else {
                        settingsModel.userId = ""
                        return
                    }
                    guard let keyData = item as? Data  else {
                        settingsModel.userId = ""
                        return
                    }
                    
                    settingsModel.keychainId = String(data: keyData, encoding: .utf8) ?? ""
                }.environmentObject(cloudCache)
                .environmentObject(settingsModel)
        }
        
        WindowGroup(id:"SettingsView"){
            SettingsView()
                .environmentObject(cloudCache)
                .environmentObject(settingsModel)
                .tag("Settings")
                .onChange(of: settingsModel.userId, { oldValue, newValue in
#if os(visionOS) || os(iOS)
                    if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                        analytics?.identify(userId: vendorId.uuidString)
                    }
#endif
#if os(macOS)
                    
#endif
                })
        }
        
#if os(visionOS)
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
#endif
    }
}
