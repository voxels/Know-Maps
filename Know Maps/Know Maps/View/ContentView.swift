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
            SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider).searchable(text: $chatModel.searchText) // Adds a search field.
        } content: {
            PlacesList()
        } detail: {
            MapResultsView()
        }.onAppear {
            Task {
                chatModel.assistiveHostDelegate = chatHost
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
        }
    }
}

#Preview(windowStyle: .automatic) {
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, results: ChatResultViewModel.modelDefaults)
    ContentView(chatModel: chatModel, locationProvider: locationProvider)
}
