//
//  ContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import RealityKit
import Segment
import MapKit

struct ContentView: View {
    
    @EnvironmentObject public var cloudCache:CloudCache
    @EnvironmentObject public var settingsModel:SettingsModel
    @EnvironmentObject public var featureFlags:FeatureFlags
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var columnVisibility =
    NavigationSplitViewVisibility.doubleColumn
 
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @State private var selectedItem: String?
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    @Binding public var isOnboarded:Bool
    @Binding public var showOnboarding:Bool

    @State private var selectedTab = "Search"
    @State private var popoverPresented:Bool = false
    @State private var didError = false
    var body: some View {
        GeometryReader() { geo in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                VStack() {
                    NavigationLocationView(columnVisibility: $columnVisibility, chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                        .navigationTitle("Locations")
                }
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
#if os(iOS) || os(visionOS)
                            popoverPresented.toggle()
#else
                            openWindow(id: "SettingsView")
#endif
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
#if os(iOS) || os(visionOS)
                .popover(isPresented: $popoverPresented) {
                    SettingsView(chatModel: chatModel, isOnboarded: $isOnboarded, showOnboarding: $showOnboarding)
                }
#endif
            } content: {
                SearchView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, columnVisibility: $columnVisibility)
                    .navigationTitle("Lists")
            } detail: {
                PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                    .navigationTitle(chatModel.selectedPlaceChatResult != nil ? "" :  "Places")
                    .alert("Unknown Place", isPresented: $didError) {
                        Button(action: {
                            chatModel.selectedPlaceChatResult = nil
                        }, label: {
                            Text("Go Back")
                        })
                    } message: {
                        Text("We don't know much about this place.")
                    }
            }
            .navigationSplitViewStyle(.balanced)
            .onAppear(perform: {
                chatModel.analytics?.screen(title: "NavigationSplitView")
            })
            .onChange(of: selectedItem, { oldValue, newValue in
                Task {
                    try await chatModel.didTapMarker(with: newValue)
                }
            })
            .onChange(of: chatModel.selectedPlaceChatResult, { oldValue, newValue in
                guard let newValue = newValue else {
                    
                    return
                }
                
                let _ = Task { @MainActor in
                    do {
                        if newValue != oldValue, let placeChatResult = chatModel.placeChatResult(for: newValue) {
                            try await chatModel.didTap(placeChatResult: placeChatResult)
                        }
                    } catch {
                        chatModel.analytics?.track(name: "error \(error)")
                        print(error)
                        didError.toggle()
                    }
                }
            })
            .onChange(of: settingsModel.appleUserId, { oldValue, newValue in
                if !newValue.isEmpty {
                    Task { @MainActor in
                        cloudCache.hasPrivateCloudAccess = true
                    }
                }
            })
            .tag("Search")
#if os(visionOS) || os(iOS)
            .toolbarColorScheme(
                .dark, for: .navigationBar, .tabBar)
#endif
        }
    }
}
