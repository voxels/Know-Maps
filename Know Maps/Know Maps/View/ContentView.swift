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
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var columnVisibility =
    NavigationSplitViewVisibility.all
    @ObservedObject public var chatHost:AssistiveChatHost
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    @State private var selectedItem: String?
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @State private var selectedTab = "Search"
    @State private var popoverPresented:Bool = false
    
    var body: some View {
        GeometryReader() { geo in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                    VStack() {
                        NavigationLocationView(columnVisibility: $columnVisibility, chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                            .frame(maxHeight: geo.size.height / 4)
                        SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                    }.toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button {
#if os(iOS)
                                popoverPresented.toggle()
#else
                                openWindow(id: "SettingsView")
#endif
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
#if os(iOS)
                    .popover(isPresented: $popoverPresented) {
                        SettingsView()
                    }
#endif
            } content: {
                    PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
            } detail: {
                    if chatModel.filteredPlaceResults.count == 0 && chatModel.selectedPlaceChatResult == nil {
                        MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, selectedMapItem: $selectedItem)
                            .onAppear(perform: {
                                chatModel.analytics?.screen(title: "MapResultsView")
                            })
                        
                    } else if chatModel.selectedPlaceChatResult == nil {
                        MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, selectedMapItem: $selectedItem)
                            .onAppear(perform: {
                                chatModel.analytics?.screen(title: "MapResultsView")
                            })
                    } else {
                        PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $chatModel.selectedPlaceChatResult)
                            .onAppear(perform: {
                                chatModel.analytics?.screen(title: "PlaceView")
                            })
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
                let _ = Task {
                    do {
                        if newValue != oldValue, let placeChatResult = chatModel.placeChatResult(for: newValue) {
                            try await chatModel.didTap(placeChatResult: placeChatResult)
                        }
                    } catch {
                        chatModel.analytics?.track(name: "error \(error)")
                        print(error)
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
            .task { @MainActor in
                chatModel.cloudCache = cloudCache
                do {
                    try await chatModel.retrieveFsqUser()
                } catch {
                    chatModel.analytics?.track(name: "error \(error)")
                    print(error)
                }
                if chatModel.categoryResults.isEmpty {
                    chatModel.assistiveHostDelegate = chatHost
                    chatHost.messagesDelegate = chatModel
                    await chatModel.categoricalSearchModel()
                }
            }
            .tag("Search")
#if os(visionOS) || os(iOS)
            .toolbarColorScheme(
                .dark, for: .navigationBar, .tabBar)
#endif
        }
    }
}


#Preview {
    let locationProvider = LocationProvider()
    let cloudCache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache)
    let chatHost = AssistiveChatHost()
    return ContentView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
}
