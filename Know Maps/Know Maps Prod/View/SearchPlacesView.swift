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
        Text("Search for a new location to add your favorite places.")
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
    @Binding public var addItemSection: Int
    @State private var searchText: String = "" // State for search text
    
    var body: some View {
        List(selection: $modelController.selectedPlaceChatResult) {
            TipView(NavigationLocationMenuIconTip())
            if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult, let locationChatResult = modelController.locationChatResult(for: selectedDestinationLocationChatResult, in: (modelController.filteredLocationResults(cacheManager: cacheManager))) {
                let locationName = locationChatResult.locationName
                Text("\(modelController.placeResults.count) places found near \(locationName)")
            } else {
                Text("Choose a location to search for places")
            }
            // Use filtered results here
            ForEach(modelController.filteredPlaceResults, id: \.id) { parent in
                VStack(alignment: .leading) {
                    Text(parent.title)
                        .font(.headline)
                    if let placeResponse = parent.placeResponse     {
                        Text(placeResponse.formattedAddress).font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.sidebar)
#if os(macOS)
        .searchable(text: $searchText, prompt: "Search by place name")
#else
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search by place name") // Add searchable
#endif
        .onSubmit(of: .search, {
            if !searchText.isEmpty{
                Task(priority:.userInitiated) {
                    await searchSavedViewModel.search(caption: searchText, selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult ?? modelController.currentLocationResult.id, intent: .AutocompletePlaceSearch, filters: searchSavedViewModel.filters, chatModel: chatModel, cacheManager: cacheManager, modelController: modelController)
                }
            }
        })
    }
    
    
    func search(intent:AssistiveChatHostService.Intent) {
        if !searchText.isEmpty {
            Task(priority:.userInitiated) {
                await searchSavedViewModel.search(
                    caption: searchText,
                    selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult, intent: intent, filters: searchSavedViewModel.filters,
                    chatModel: chatModel,
                    cacheManager: cacheManager,
                    modelController: modelController
                )
            }
        }
    }
}
