//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var addItemSection:Int
    @Binding public var settingsPresented:Bool
    @Binding public var showPlaceViewSheet:Bool
    @Binding public var didError:Bool
    
    var body: some View {
        SearchSavedView(viewModel: searchSavedViewModel, preferredColumn: $preferredColumn, contentViewDetail: $contentViewDetail, addItemSection: $addItemSection, settingsPresented: $settingsPresented )
            .onChange(of: chatModel.modelController.selectedPlaceChatResult, { oldValue, newValue in
                guard let newValue = newValue else {
                    showPlaceViewSheet = false
                    return
                }
                
                if let placeChatResult = chatModel.modelController.placeChatResult(for: newValue), placeChatResult.placeDetailsResponse == nil {
                    Task {
                        do {
                            try await chatModel.didTap(placeChatResult: placeChatResult)
                            await MainActor.run {
                                showPlaceViewSheet = true
                            }
                        } catch {
                            chatModel.modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
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
            .onChange(of: chatModel.modelController.selectedSavedResult) { oldValue, newValue in
                chatModel.modelController.resetPlaceModel()
                
                guard let newValue = newValue else {
                    return
                }
                
                Task {
                    if let selectedDestinationLocationChatResult = chatModel.modelController.selectedDestinationLocationChatResult {
                        if let cachedResult = chatModel.modelController.cachedChatResult(for: newValue) {
                            await chatModel.didTap(chatResult: cachedResult, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
                        }
                    } else {
                        if let cachedResult = chatModel.modelController.cachedChatResult(for: newValue) {
                            await chatModel.didTap(chatResult: cachedResult,  selectedDestinationChatResultID: nil)
                        }
                    }
                }
            }
            .onChange(of: chatModel.modelController.selectedCategoryResult) { oldValue, newValue in
                chatModel.modelController.resetPlaceModel()
                Task {
                    if let newValue = newValue, let categoricalResult =
                        chatModel.modelController.categoricalChatResult(for: newValue) {
                        await chatModel.didTap(chatResult: categoricalResult, selectedDestinationChatResultID:chatModel.modelController.selectedDestinationLocationChatResult)
                    }
                }
            }.onChange(of: chatModel.modelController.selectedTasteCategoryResult, { oldValue, newValue in
                chatModel.modelController.resetPlaceModel()
                Task {
                    if let newValue = newValue, let tasteResult = chatModel.modelController.tasteChatResult(for: newValue) {
                        await chatModel.didTap(chatResult: tasteResult, selectedDestinationChatResultID:chatModel.modelController.selectedDestinationLocationChatResult)
                    }
                }
            })
    }
}

