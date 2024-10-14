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
    @Binding public var settingsPresented:Bool
    @Binding public var showPlaceViewSheet:Bool
    @Binding public var showMapsResultViewSheet:Bool
    @Binding public var didError:Bool
    @State private var showNavigationLocationSheet:Bool = false

    var body: some View {
        SearchSavedView(chatModel: $chatModel, viewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController, preferredColumn: $preferredColumn, addItemSection: $addItemSection, settingsPresented: $settingsPresented, showNavigationLocationSheet: $showNavigationLocationSheet )
            .onChange(of: modelController.selectedPlaceChatResult, { oldValue, newValue in
                
                
                guard newValue != nil else {
                    return
                }
                
                Task { @MainActor in
                    preferredColumn = .detail
                    
                    if !showMapsResultViewSheet {
                        showPlaceViewSheet = true
                    }
                }
            })
            .onChange(of: modelController.selectedSavedResult) { oldValue, newValue in
                guard let newValue = newValue, newValue != oldValue else {
                    return
                }
                preferredColumn = .detail
                modelController.isRefreshingPlaces = true
                modelController.fetchMessage = "Searching"
                Task(priority:.userInitiated) {
                    await modelController.resetPlaceModel()
                    if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult {
                        if let cachedResult = modelController.cachedChatResult(for: newValue, cacheManager: cacheManager) {
                            await chatModel.didTap(chatResult: cachedResult, selectedDestinationChatResultID: selectedDestinationLocationChatResult, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                        }
                    }  else {
                        if let cachedResult = modelController.cachedChatResult(for: newValue, cacheManager: cacheManager) {
                            await chatModel.didTap(chatResult: cachedResult,  selectedDestinationChatResultID: nil, filters: searchSavedViewModel.filters, cacheManager: cacheManager, modelController: modelController)
                        }
                    }
                    await MainActor.run {
                        modelController.isRefreshingPlaces = false
                    }
                }
            }
    }
}

