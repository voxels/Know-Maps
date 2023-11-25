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
    @StateObject private var chatHost:AssistiveChatHost = AssistiveChatHost()
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel()
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    var body: some View {
        GeometryReader() { geo in
            
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            TabView {
                    NavigationSplitView {
                        VStack() {
                            List(chatModel.filteredLocationResults) { result in
                                Label(result.locationName, systemImage: "mappin")
                                    .onTapGesture {
                                        chatModel.locationSearchText.removeAll()
                                        if let location = result.location {
                                            locationProvider.queryLocation = location
                                            chatModel.resetPlaceModel()
                                            chatModel.locationSearchText.removeAll()
                                            chatModel.searchText = chatModel.locationSearchText
                                        }
                                    }
                            }
                            .searchable(text: $chatModel.locationSearchText)
                                .frame(maxHeight: geo.size.height / 4)
                            SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                                .toolbarBackground(
                                    Color.accentColor, for: .navigationBar, .tabBar)
                                .toolbarColorScheme(
                                    .dark, for: .navigationBar, .tabBar)
                        }
                    } content: {
                        PlacesList(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
                            .toolbarBackground(
                                Color.accentColor, for: .navigationBar, .tabBar)
                            .toolbarColorScheme(
                                .dark, for: .navigationBar, .tabBar)
                    } detail: {
                        if chatModel.filteredPlaceResults.count == 0 && chatModel.selectedPlaceChatResult == nil {
                            MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                                .toolbarBackground(
                                    Color.accentColor, for: .navigationBar, .tabBar)
                                .toolbarColorScheme(
                                    .dark, for: .navigationBar, .tabBar)
                        } else if chatModel.selectedPlaceChatResult == nil {
                            MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                                .toolbarBackground(
                                    Color.accentColor, for: .navigationBar, .tabBar)
                                .toolbarColorScheme(
                                    .dark, for: .navigationBar, .tabBar)
                        } else {
                            PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $chatModel.selectedPlaceChatResult)
                                .toolbarBackground(
                                    Color.accentColor, for: .navigationBar, .tabBar)
                                .toolbarColorScheme(
                                    .dark, for: .navigationBar, .tabBar)
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
                    .onChange(of: chatModel.locationSearchText, { oldValue, newValue in
                        chatModel.searchText = newValue
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
}
}


#Preview(windowStyle: .automatic) {
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider)
    ContentView(chatModel: chatModel, locationProvider: locationProvider)
}
