//
//  SearchPlacesView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/22/24.
//


import SwiftUI
import TipKit
import Combine

struct NavigationLocationMenuIconTip: Tip {
    var title: Text {
        Text("Location Menu")
    }
    
    
    var message: Text? {
        Text("Search for a new place by name or address.")
    }
    
    
    var image: Image? {
        Image(systemName: "location.magnifyingglass")
    }
}

struct SearchPlacesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<String>
    @ObservedObject public var placeDirectionsChatViewModel:PlaceDirectionsViewModel
    @State private var searchText: String = "" // State for search text
    @State private var showPlaceList = true
    
    var body: some View {
            // Compact mode:
            // - Always show the list so user can select a place.
            // - If it's empty, still show the "fetchMessage" placeholder text.
            if modelController.placeResults.isEmpty &&
                modelController.recommendedPlaceResults.isEmpty {
                VStack {
                    Text(modelController.fetchMessage)
                        .foregroundStyle(.secondary)
                        .padding(.bottom)
                }
#if os(macOS)
                .searchable(text: $searchText, prompt: "Search by place name")
#else
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by place name") // Add searchable
#endif
                .onSubmit(of: .search, {
                    if !searchText.isEmpty {
                        Task {
                            let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: searchText, filters: searchSavedViewModel.filters)
                            
                            let intent = AssistiveChatHostIntent(caption: searchText, intent: .Search, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [], selectedDestinationLocation: modelController.selectedDestinationLocationChatResult, placeDetailsResponses: nil, queryParameters:queryParameters)
                            do {
                                try await modelController.searchIntent(intent: intent)
                            } catch {
                                modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                            }
                        }
                    }
                })
            } else {
                searchPlaceList()
            }
    }
    
    @ViewBuilder
    func searchPlaceView() -> some View {
        if let selectedResult = modelController.selectedPlaceChatResultFsqId, let placeChatResult = modelController.placeChatResult(with: selectedResult) {
            PlaceView(
                searchSavedViewModel: $searchSavedViewModel,
                chatModel: $chatModel,
                cacheManager: $cacheManager,
                modelController: $modelController,
                placeDirectionsViewModel: placeDirectionsChatViewModel,
                selectedResult: placeChatResult
            )
            .navigationTitle(placeChatResult.title)
        }
    }
    
    @ViewBuilder
    func searchPlaceList() -> some View {
        Group {
            PlacesList(
                searchSavedViewModel: $searchSavedViewModel,
                chatModel: $chatModel,
                cacheManager: $cacheManager,
                modelController: $modelController
            )
#if os(macOS)
            .searchable(text: $searchText, prompt: "Search by place name")
#else
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by place name") // Add searchable
#endif
            .onSubmit(of: .search, {
                if !searchText.isEmpty {
                    
                    Task {
                        let queryParameters = try await modelController.assistiveHostDelegate.defaultParameters(for: searchText, filters: searchSavedViewModel.filters)
                        
                        let intent = AssistiveChatHostIntent(caption: searchText, intent: .Search, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [], selectedDestinationLocation: modelController.selectedDestinationLocationChatResult, placeDetailsResponses: nil, queryParameters:queryParameters)
                        do {
                            try await modelController.searchIntent(intent: intent)
                        } catch {
                            modelController.analyticsManager.trackError(error: error, additionalInfo: nil)
                        }
                    }
                }
            })
        }
    }
}

