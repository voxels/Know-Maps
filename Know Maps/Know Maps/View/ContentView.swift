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
    @StateObject public var settingsModel = SettingsModel(userId: "")
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
                            .onSubmit(of: .search, {
                                if chatModel.locationSearchText.isEmpty {
                                    chatModel.resetPlaceModel()
                                    chatModel.selectedCategoryChatResult = nil
                                } else {
                                    Task { @MainActor in
                                        do {
                                            try await chatModel.didSearch(caption:chatModel.locationSearchText)
                                        } catch {
                                            print(error)
                                        }
                                    }
                                }
                            })
                            .onChange(of: chatModel.locationSearchText) { oldValue, newValue in
                                if newValue.isEmpty {
                                    chatModel.resetPlaceModel()
                                    chatModel.selectedCategoryChatResult = nil
                                }
                            }
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
                                if newValue != oldValue, let placeChatResult = chatModel.placeChatResult(for: newValue) {
                                    try await chatModel.didTap(placeChatResult: placeChatResult)
                                }
                            } catch {
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
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    SettingsView(model:settingsModel)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
            }
        }
        .task {
            let getquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                           kSecAttrApplicationTag as String: SettingsModel.tag,
                                           kSecReturnData as String: true]
            
            var item: CFTypeRef?
            let status = SecItemCopyMatching(getquery as CFDictionary, &item)
            guard status == errSecSuccess else {
                settingsModel.userId = ""
                return
            }
            guard let keyData = item as? Data  else {
                settingsModel.userId = ""
                return
            }
            
            settingsModel.keychainId = String(data: keyData, encoding: .utf8) ?? ""
        }
    }
}


#Preview(windowStyle: .automatic) {
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider)
    ContentView(chatModel: chatModel, locationProvider: locationProvider)
}
