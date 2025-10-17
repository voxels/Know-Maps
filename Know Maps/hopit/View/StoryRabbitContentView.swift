//
//  StoryRabbitContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/23/25.
//

import SwiftUI
import AVKit


struct StoryRabbitContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @ObservedObject var settingsModel:AppleAuthenticationService
    @Binding var chatModel:ChatResultViewModel
    @Binding var cacheManager:CloudCacheManager
    @Binding var modelController:DefaultModelController
    @Binding var searchSavedViewModel:SearchSavedViewModel
    @Binding  public var showOnboarding:Bool
    
    @State public var lastMultiSelection = Set<String>()
    @State public var multiSelection = Set<String>()
    // State to hold the reference to the active search task
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            TabView {
                StoryRabbitMapView(chatModel: $chatModel, cacheManager: $cacheManager, modelController: $modelController, searchSavedViewModel: $searchSavedViewModel)
                    .tabItem {
                        Label("Explore", systemImage: "globe.americas")
                    }
                StoryRabbitSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
            .onAppear(perform: {
                modelController.analyticsManager.track(event:"StoryRabbitContentView",properties: nil )
            })
        }
    }
}
