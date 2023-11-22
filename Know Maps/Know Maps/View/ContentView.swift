//
//  ContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @State private var chatHost:AssistiveChatHost = AssistiveChatHost()
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        TabView {
            NavigationSplitView {
                SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, categoricalResultId: $chatModel.selectedCategoryChatResult)
            } content: {
                PlacesList(chatHost: chatHost, model: chatModel, resultId: $chatModel.selectedPlaceChatResult)
            } detail: {
                if chatModel.filteredPlaceResults.count == 0 && chatModel.selectedPlaceChatResult == nil {
                    MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                } else if chatModel.selectedPlaceChatResult == nil {
                    MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                } else {
                    PlaceView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                }
            }.onChange(of: chatModel.selectedCategoryChatResult) { oldValue, newValue in
                chatModel.selectedPlaceChatResult = nil
                let _ = Task {
                    if let newValue = newValue, let chatResult = chatModel.chatResult(for: newValue) {
                        await chatHost.didTap(chatResult: chatResult)
                    }
                }
            }
            .onChange(of: chatModel.selectedPlaceChatResult, { oldValue, newValue in
                guard let newValue = newValue else {
                    return
                }
                let _ = Task {
                    do {
                        if let placeChatResult = chatModel.placeChatResult(for: newValue), newValue != oldValue, placeChatResult.title != chatModel.searchText {
                            try await chatModel.didTap(placeChatResult: placeChatResult)
                        }
                    } catch {
                        print(error)
                    }
                }
            })
            .task {
                chatModel.assistiveHostDelegate = chatHost
                chatHost.messagesDelegate = chatModel
                await chatModel.categoricalSearchModel()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview(windowStyle: .automatic) {
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider)
    ContentView(chatModel: chatModel, locationProvider: locationProvider)
}
