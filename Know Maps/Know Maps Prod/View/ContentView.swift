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

public enum ContentDetailView {
    case places
    case lists
}

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
    
    @State private var popoverPresented:Bool = false
    @State private var didError = false
    @State private var contentViewDetail:ContentDetailView = .places
    

    
    
    var body: some View {
        GeometryReader() { geo in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                VStack() {
                    NavigationLocationView(columnVisibility: $columnVisibility, chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                        .navigationTitle("Destination")
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
                SearchView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, columnVisibility: $columnVisibility, contentViewDetail: $contentViewDetail)
                    .navigationTitle("Prompt")
            } detail: {
                switch contentViewDetail {
                case .places:
                    PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                        .navigationTitle("Places")
                        .alert("Unknown Place", isPresented: $didError) {
                            Button(action: {
                                chatModel.selectedPlaceChatResult = nil
                            }, label: {
                                Text("Go Back")
                            })
                        } message: {
                            Text("We don't know much about this place.")
                        }
                case .lists:
                    PromptRankingView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, contentViewDetail: $contentViewDetail)
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
