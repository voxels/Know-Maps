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
    @StateObject public var cloudCache:CloudCache = CloudCache()
    @StateObject public var settingsModel = SettingsModel(userId: "")
    static let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
    // Automatically track Lifecycle events
        .trackApplicationLifecycleEvents(true)
        .flushAt(3)
        .flushInterval(10)
    
    public var analytics:Analytics? = Analytics(configuration: Know_MapsApp.config)
    
    var body: some Scene {
        WindowGroup(id:"ContentView") {
            ContentView(chatHost: AssistiveChatHost(cache: cloudCache), chatModel: ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache), locationProvider: locationProvider)
        }
        
        WindowGroup(id:"SettingsView"){
            SettingsView(model:settingsModel)
                .tag("Settings")
                .onChange(of: settingsModel.userId, { oldValue, newValue in
#if os(visionOS)
                    if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                        analytics?.identify(userId: vendorId.uuidString)
                    }
#endif
#if os(macOS)
                    
#endif
                })
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
                }
        }
        
#if os(visionOS)
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
#endif
    }
}
