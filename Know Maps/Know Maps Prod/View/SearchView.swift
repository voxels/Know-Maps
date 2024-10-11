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
    @Binding  public var preferredColumn:NavigationSplitViewColumn
    @Binding  public var contentViewDetail:ContentDetailView
    @Binding  public var addItemSection:Int
    @Binding  public var settingsPresented:Bool
    @Binding  public var showPlaceViewSheet:Bool
    @Binding  public var didError:Bool
    
    var body: some View {
        SearchSavedView(chatModel: $chatModel, viewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController, preferredColumn: $preferredColumn, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, settingsPresented: $settingsPresented )
            .onChange(of: modelController.selectedPlaceChatResult, { oldValue, newValue in
                guard let newValue = newValue else {
                    showPlaceViewSheet = false
                    return
                }
                
                if let placeChatResult = modelController.placeChatResult(for: newValue), placeChatResult.placeDetailsResponse == nil {
                    Task(priority:.userInitiated) {
                        do {
                            try await chatModel.didTap(placeChatResult: placeChatResult, cacheManager: cacheManager, modelController: modelController)
                            await MainActor.run {
                                showPlaceViewSheet = true
                            }
                        } catch {
                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                            await MainActor.run {
                                didError.toggle()
                            }
                        }
                    }
                }
                else {
                    showPlaceViewSheet = true
                }
            })
            .onChange(of: modelController.selectedSavedResult) { oldValue, newValue in
                guard let newValue = newValue else {
                    return
                }
                preferredColumn = .detail
                Task(priority:.userInitiated) {
                    await modelController.resetPlaceModel()
                    if let selectedDestinationLocationChatResult = modelController.selectedDestinationLocationChatResult {
                        if let cachedResult = modelController.cachedChatResult(for: newValue, cacheManager: cacheManager) {
                            await chatModel.didTap(chatResult: cachedResult, selectedDestinationChatResultID: selectedDestinationLocationChatResult, cacheManager: cacheManager, modelController: modelController)
                        }
                    } else {
                        if let cachedResult = modelController.cachedChatResult(for: newValue, cacheManager: cacheManager) {
                            await chatModel.didTap(chatResult: cachedResult,  selectedDestinationChatResultID: nil, cacheManager: cacheManager, modelController: modelController)
                        }
                    }
                }
            }
    }
}

