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
    

    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var columnVisibility =
    NavigationSplitViewVisibility.all
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel()
    @State private var selectedItem: String?
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @State private var selectedTab = "Search"
    
    var body: some View {
        GeometryReader() { geo in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                VStack() {
                    NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                        .frame(maxHeight: geo.size.height / 4)
                    SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                }.toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            openWindow(id: "SettingsView")
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
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
            }.onAppear(perform: {
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
            .task {
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
    let cache = CloudCache()
    let settingsModel = SettingsModel(userId: "")
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cache, settingsModel: settingsModel)
    let chatHost = AssistiveChatHost(cache:cache)
    return ContentView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
}
