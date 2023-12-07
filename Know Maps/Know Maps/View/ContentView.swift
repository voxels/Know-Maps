//
//  ContentView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI
import RealityKit
import Segment

struct ContentView: View {
    
    @State private var searchIsPresented = false
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @StateObject public var chatHost:AssistiveChatHost
    @StateObject public var chatModel:ChatResultViewModel
    @StateObject public var locationProvider:LocationProvider
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel()
    @Environment(\.openWindow) private var openWindow
#if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @State private var selectedTab = "Search"
    
    var body: some View {
        GeometryReader() { geo in
            NavigationSplitView {
                VStack() {
                    Section("Destination") {
                        List(chatModel.filteredDestinationLocationResults, selection:$chatModel.selectedDestinationLocationChatResult) { result in
                            if result.id == chatModel.selectedDestinationLocationChatResult {
                                Label(result.locationName, systemImage: "mappin").tint(.red)
                            } else {
                                Label(result.locationName, systemImage: "mappin").tint(.accent)
                            }
                        }
                    }
                    .autocorrectionDisabled(true)
                    .searchable(text: $chatModel.locationSearchText, isPresented:$searchIsPresented)
                    .onSubmit(of: .search, {
                        if chatModel.locationSearchText.isEmpty, !chatModel.placeResults.isEmpty {
                            chatModel.resetPlaceModel()
                            chatModel.selectedCategoryChatResult = nil
                        } else {
                            Task {
                                do {
                                    try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                                } catch {
                                    chatModel.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        }
                    })
                    .onChange(of: chatModel.selectedDestinationLocationChatResult, { oldValue, newValue in
                        Task {
                            do {
                                try await chatModel.didSearch(caption:chatModel.locationSearchText, selectedDestinationChatResultID:newValue)
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                        
                    })
                    .task {
                        chatModel.selectedDestinationLocationChatResult = chatModel.filteredLocationResults.first?.id
                        
                        Task {
                            do {
                                if let name = try await chatModel.currentLocationName() {
                                    try await chatModel.didSearch(caption:name, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                                }
                            } catch {
                                chatModel.analytics?.track(name: "error \(error)")
                                print(error)
                            }
                        }
                        
                    }
                    
                    Section("Origin") {
                        List(chatModel.filteredSourceLocationResults, selection:$chatModel.selectedSourceLocationChatResult) { result in
                            if result.id == chatModel.selectedSourceLocationChatResult {
                                Label(result.locationName, systemImage: "mappin").tint(.red)
                            } else {
                                Label(result.locationName, systemImage: "mappin").tint(.accent)
                            }
                        }
                    }.task {
                        chatModel.selectedSourceLocationChatResult = chatModel.filteredLocationResults.first?.id
                    }
                    
                    SearchView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
#if os(visionOS)
                        .toolbarBackground(
                            Color.accentColor, for: .navigationBar, .tabBar)
                        .toolbarColorScheme(
                            .dark, for: .navigationBar, .tabBar)
#endif
                    
                }
            } content: {
                PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $chatModel.selectedPlaceChatResult)
#if os(visionOS)
                    .toolbarBackground(
                        Color.accentColor, for: .navigationBar, .tabBar)
                    .toolbarColorScheme(
                        .dark, for: .navigationBar, .tabBar)
#endif
            } detail: {
                if chatModel.filteredPlaceResults.count == 0 && chatModel.selectedPlaceChatResult == nil {
                    MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
#if os(visionOS)
                        .toolbarBackground(
                            Color.accentColor, for: .navigationBar, .tabBar)
                        .toolbarColorScheme(
                            .dark, for: .navigationBar, .tabBar)
#endif
                        .onAppear(perform: {
                            chatModel.analytics?.screen(title: "MapResultsView")
                        })
                    
                } else if chatModel.selectedPlaceChatResult == nil {
                    MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider)
#if os(visionOS)
                        .toolbarBackground(
                            Color.accentColor, for: .navigationBar, .tabBar)
                        .toolbarColorScheme(
                            .dark, for: .navigationBar, .tabBar)
#endif
                        .onAppear(perform: {
                            chatModel.analytics?.screen(title: "MapResultsView")
                        })
                } else {
                    PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $chatModel.selectedPlaceChatResult)
#if os(visionOS)
                        .toolbarBackground(
                            Color.accentColor, for: .navigationBar, .tabBar)
                        .toolbarColorScheme(
                            .dark, for: .navigationBar, .tabBar)
#endif
                        .onAppear(perform: {
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
            .task {
                if chatModel.categoryResults.isEmpty {
                    chatModel.assistiveHostDelegate = chatHost
                    chatHost.messagesDelegate = chatModel
                    await chatModel.categoricalSearchModel()
                }
            }
            .tag("Search")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        openWindow(id: "SettingsView")
                    } label: {
                        Image(systemName: "gear")
                    }

                }
            }
        }.padding()
            
    }
}


#Preview {
    let locationProvider = LocationProvider()
    let cache = CloudCache()
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cache)
    let chatHost = AssistiveChatHost()
    return ContentView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
}
