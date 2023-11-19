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
        NavigationSplitView {
            SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedCategoryChatResult)
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
            guard let newValue = newValue else {
                chatModel.resetPlaceModel()
                return
            }
            
            
            let _ = Task {
                if let chatResult = chatModel.chatResult(for: newValue) {
                    await chatHost.didTap(chatResult: chatResult)
                    await MainActor.run {
                        chatModel.searchText = chatResult.title
                    }
                }
            }
        }
        .onChange(of: chatModel.selectedPlaceChatResult, { oldValue, newValue in
            guard newValue != nil else {
                chatModel.resetPlaceModel()
                return
            }
        })
        .task {
            chatModel.assistiveHostDelegate = chatHost
            chatHost.messagesDelegate = chatModel
            if let location = chatModel.locationProvider.currentLocation() {
                await chatModel.refreshModel()
            } else {
                chatModel.locationProvider.authorize()
                await chatModel.refreshModel()
            }
            
            if let selectedCategoryChatResult = chatModel.selectedCategoryChatResult, let chatResult = chatModel.chatResult(for: selectedCategoryChatResult) {
                await chatHost.didTap(chatResult: chatResult)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    ContentView(chatModel: chatModel, locationProvider: locationProvider)
}
