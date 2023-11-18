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
    @State private var selectedCategoryChatResult:ChatResult.ID?
    @State private var selectedPlaceChatResult:ChatResult.ID?
    @State private var isPlaceSelected:Bool = false
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        NavigationSplitView {
            SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, resultId: $selectedCategoryChatResult)
                .searchable(text: $chatModel.searchText)
                .onSubmit(of: .search) {
                    let selectedResult = chatModel.chatResult(title: chatModel.searchText)
                    chatHost.didTap(chatResult: selectedResult)
                }
        } content: {
            PlacesList(chatHost: chatHost, model: chatModel, resultId: $selectedPlaceChatResult)
        } detail: {
            if selectedPlaceChatResult == nil {
                MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
            } else {
                PlaceView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, resultId: $selectedPlaceChatResult)
            }
        }.onAppear {
            Task {
                chatModel.assistiveHostDelegate = chatHost
                chatHost.messagesDelegate = chatModel
                if let location = chatModel.locationProvider.currentLocation() {
                    chatModel.refreshModel(nearLocation: location)
                } else {
                    chatModel.locationProvider.authorize()
                }
            }
        }.onChange(of: locationProvider.lastKnownLocation) { oldValue, newValue in
            if let location = newValue {
                guard let oldLocation = oldValue else {
                    chatModel.refreshModel(nearLocation: location)
                    return
                }
                
                if location.distance(from: oldLocation) > 1000 {
                    chatModel.refreshModel(nearLocation: location)
                }
            }
        }.onChange(of: selectedCategoryChatResult) { oldValue, newValue in
            guard let newValue = newValue else {
                chatModel.resetPlaceModel()
                return
            }
            let chatResult = chatModel.chatResult(for: newValue)
            chatHost.didTap(chatResult: chatResult)
        }
        .onChange(of: chatModel.searchText, { oldValue, newValue in
            if newValue == "" {
                chatModel.resetPlaceModel()
                isPlaceSelected = false
                selectedPlaceChatResult = nil
            }
        })
        .onChange(of: isPlaceSelected) { oldValue, newValue in
            if !isPlaceSelected {
                selectedPlaceChatResult = nil
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    ContentView(chatModel: chatModel, locationProvider: locationProvider)
}
