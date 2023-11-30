//
//  ContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Segment

struct ContentView: View {
    
    @State private var searchIsPresented = false
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @StateObject private var chatHost:AssistiveChatHost = AssistiveChatHost()
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel()
    @StateObject public var settingsModel = SettingsModel(userId: "")
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    
    @State private var selectedTab = "Search"
    
    var body: some View {
        GeometryReader() { geo in
            
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                TabView(selection: $selectedTab) {
                    NavigationSplitView {
                        VStack() {
                            List(chatModel.filteredLocationResults) { result in
                                Label(result.locationName, systemImage: "mappin")
                                    .onTapGesture {
                                        if let location = result.location {
                                            locationProvider.queryLocation = location
                                            chatModel.resetPlaceModel()
                                            chatModel.locationSearchText = result.locationName
                                        } else {
                                            chatModel.locationSearchText.removeAll()
                                        }
                                    }
                            }
                            .autocorrectionDisabled(true)
                            .searchable(text: $chatModel.locationSearchText, isPresented:$searchIsPresented)
                            .onSubmit(of: .search, {
                                if chatModel.locationSearchText.isEmpty, !chatModel.placeResults.isEmpty {
                                    chatModel.resetPlaceModel()
                                    chatModel.selectedCategoryChatResult = nil
                                } else if chatModel.locationSearchText.isEmpty, chatModel.placeResults.isEmpty {
                                    print("Submit Empty Search \(chatModel.locationSearchText)")
                                    searchIsPresented = true
                                } else {
                                    Task { @MainActor in
                                        do {
                                            try await chatModel.didSearch(caption:chatModel.locationSearchText)
                                        } catch {
                                            chatModel.analytics?.track(name: "error \(error)")
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
                                .onAppear(perform: {
                                    chatModel.analytics?.screen(title: "MapResultsView")
                                })
                            
                        } else if chatModel.selectedPlaceChatResult == nil {
                            MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
                                .toolbarBackground(
                                    Color.accentColor, for: .navigationBar, .tabBar)
                                .toolbarColorScheme(
                                    .dark, for: .navigationBar, .tabBar)
                                .onAppear(perform: {
                                    chatModel.analytics?.screen(title: "MapResultsView")
                                })
                        } else {
                            PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $chatModel.selectedPlaceChatResult)
                                .toolbarBackground(
                                    Color.accentColor, for: .navigationBar, .tabBar)
                                .toolbarColorScheme(
                                    .dark, for: .navigationBar, .tabBar).onAppear(perform: {
                                        chatModel.analytics?.screen(title: "PlaceView")
                                    })
                        }
                    }.onAppear(perform: {
                        chatModel.analytics?.screen(title: "NavigationSplitView")
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
                    .onChange(of: settingsModel.userId, { oldValue, newValue in
                        if !newValue.isEmpty, let vendorId = UIDevice().identifierForVendor {
                            chatModel.analytics?.identify(userId: vendorId.uuidString)
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
                    .tag("Search")
                    SettingsView(model:settingsModel, selectedTab: $selectedTab)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag("Settings")                    
                        .onAppear(perform: {
                            chatModel.analytics?.screen(title: "SettingsView")
                        })
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
            
            let config = Configuration(writeKey: "igx8ZOr5NLbaBsab5j5juFECMzqulFla")
                // Automatically track Lifecycle events
                .trackApplicationLifecycleEvents(true)
                .flushAt(3)
                .flushInterval(10)

            chatModel.analytics = Analytics(configuration: config)
            chatHost.analytics = chatModel.analytics
        }
    }
}


#Preview(windowStyle: .automatic) {
    let locationProvider = LocationProvider()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider)
    ContentView(chatModel: chatModel, locationProvider: locationProvider)
}
