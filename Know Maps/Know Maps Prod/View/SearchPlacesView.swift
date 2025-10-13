//
//  SearchPlacesView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/22/24.
//


import SwiftUI
import TipKit

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
    @Binding public var multiSelection: Set<UUID>
    @State private var searchText: String = "" // State for search text
    
    var body: some View {
        VStack {
            TipView(NavigationLocationMenuIconTip())
            if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: (modelController.filteredLocationResults(cacheManager: cacheManager))) {
                let locationName = locationChatResult.locationName
                Text("\(modelController.placeResults.count) places found near \(locationName)")
                    .padding(.vertical)
            } else {
                Text("Choose a location to search for places")
            }
            Spacer()
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
                        selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult ?? modelController.currentlySelectedLocationResult.id,
                        intent: .AutocompletePlaceSearch,
                        filters: searchSavedViewModel.filters,
                        chatModel: chatModel,
                        cacheManager: cacheManager,
                        modelController: modelController
                    )
                    // After the search completes, push to detail by selecting the first result (iPhone collapses split view)
                    await MainActor.run {
                        if let first = modelController.placeResults.first {
                            modelController.selectedPlaceChatResult = first.id
                        }
                    }
                }
            }
        })
    }
}

