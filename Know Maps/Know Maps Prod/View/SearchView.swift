//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @Binding public var addItemSection:Int
    @Binding public var showMapsResultViewSheet:Bool
    @Binding public var didError:Bool

    var body: some View {
        SavedListView(searchSavedViewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController, addItemSection: $addItemSection, preferredColumn: $preferredColumn, selectedResult: $modelController.selectedSavedResult)
            .onChange(of: modelController.selectedSavedResult) { oldValue, newValue in
                guard let newValue = newValue, newValue != oldValue else {
                    return
                }
                preferredColumn = .detail
                modelController.isRefreshingPlaces = true
                modelController.fetchMessage = "Fetching places"
                Task(priority:.userInitiated) {
                    
                    await modelController.resetPlaceModel()
                    if let cachedResult = modelController.cachedChatResult(for: newValue, cacheManager: cacheManager) {
                        await chatModel.didTap(chatResult: cachedResult,  selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult ?? modelController.currentLocationResult.id, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                    }
                    await MainActor.run {
                        modelController.isRefreshingPlaces = false
                    }
                }
            }
    }
}

