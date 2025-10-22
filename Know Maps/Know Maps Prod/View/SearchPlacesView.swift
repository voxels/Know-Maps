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
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<String>
    @ObservedObject public var placeDirectionsChatViewModel:PlaceDirectionsViewModel
    @State private var searchText: String = "" // State for search text
    @State private var showPlaceList = true
    
    var body: some View {
        VStack {
            if modelController.placeResults.isEmpty && modelController.recommendedPlaceResults.isEmpty {
                Text(modelController.fetchMessage)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
        }
#if os(macOS)
        .searchable(text: $searchText, prompt: "Search by place name")
#else
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by place name") // Add searchable
#endif
        .onSubmit(of: .search, {
            if !searchText.isEmpty {
                Task(priority: .userInitiated) {
                    await searchSavedViewModel.search(
                        caption: searchText,
                        selectedDestinationChatResult: modelController.selectedDestinationLocationChatResult,
                        intent: .AutocompletePlaceSearch,
                        filters: searchSavedViewModel.filters,
                        chatModel: chatModel,
                        cacheManager: cacheManager,
                        modelController: modelController
                    )
                }
            }
        })
    }
}

