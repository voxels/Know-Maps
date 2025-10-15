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
    @Binding public var searchMode:SearchMode
    @Binding public var showMapsResultViewSheet:Bool
    @Binding public var didError:Bool
    

    var body: some View {
        SavedListView(searchSavedViewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController, section:$modelController.section,  preferredColumn: $preferredColumn, selectedResult: $modelController.selectedSavedResult, searchMode: $searchMode)
            .onChange(of: modelController.selectedSavedResult) { oldValue, newValue in
                guard let newValue = newValue else {
                    return
                }
                modelController.isRefreshingPlaces = true
                Task(priority:.userInitiated) {
                    do {
                        try await modelController.resetPlaceModel()
                    } catch {
                        modelController.analyticsManager.trackError(error:error, additionalInfo:nil)
                    }
                    if let cachedResult = modelController.cachedChatResult(for: newValue, cacheManager: cacheManager) {
                        await chatModel.didTap(chatResult: cachedResult,  selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult ?? modelController.currentlySelectedLocationResult.id, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                    }
                    await MainActor.run {
                        modelController.isRefreshingPlaces = false
                     }
                }
            }
    }
}

