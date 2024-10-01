//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var cloudCache:CloudCache
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var columnVisibility:NavigationSplitViewVisibility
    @Binding public var preferredColumn:NavigationSplitViewColumn
    @Binding public var contentViewDetail:ContentDetailView
    @Binding public var settingsPresented:Bool
    @Binding public var showPlaceViewSheet:Bool
    @Binding public var didError:Bool
    @State private var savedSectionSelection = 1
    
    var body: some View {
        SearchSavedView(chatHost:chatHost, chatModel: chatModel, locationProvider: locationProvider, columnVisibility: $columnVisibility, preferredColumn: $preferredColumn, contentViewDetail: $contentViewDetail, settingsPresented: $settingsPresented )
            .onChange(of: chatModel.selectedPlaceChatResult, { oldValue, newValue in
                guard let newValue = newValue else {
                    showPlaceViewSheet = false
                    return
                }
                
                if let placeChatResult = chatModel.placeChatResult(for: newValue), placeChatResult.placeDetailsResponse == nil {
                    Task {
                        do {
                            try await chatModel.didTap(placeChatResult: placeChatResult)
                            await MainActor.run {
                                showPlaceViewSheet = true
                            }
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
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
            .onChange(of: chatModel.selectedSavedResult) { oldValue, newValue in
                chatModel.resetPlaceModel()
                
                guard let newValue = newValue else {
                    return
                }
                
                Task {
                    if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult {
                        if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                            await MainActor.run {
                                chatModel.locationSearchText = cachedResult.title
                            }
                            await chatHost.didTap(chatResult: cachedResult, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
                        }
                    } else {
                        if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                            await MainActor.run {
                                chatModel.locationSearchText = cachedResult.title
                            }
                            await chatHost.didTap(chatResult: cachedResult,  selectedDestinationChatResultID: nil)
                        }
                    }
                }
            }
            .onChange(of: chatModel.selectedCategoryResult) { oldValue, newValue in
                chatModel.resetPlaceModel()
                Task {
                    if let newValue = newValue, let categoricalResult =
                        chatModel.categoricalChatResult(for: newValue) {
                        let categoricalChatResult = chatModel.categoricalChatResult(for: newValue)?.title ?? chatModel.locationSearchText
                        await MainActor.run {
                            chatModel.locationSearchText = categoricalChatResult
                        }
                        await chatHost.didTap(chatResult: categoricalResult, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                    }
                }
            }.onChange(of: chatModel.selectedTasteCategoryResult, { oldValue, newValue in
                chatModel.resetPlaceModel()
                Task {
                    if let newValue = newValue, let tasteResult = chatModel.tasteChatResult(for: newValue) {
                        await MainActor.run {
                            chatModel.locationSearchText = tasteResult.title
                        }
                        await chatHost.didTap(chatResult: tasteResult, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                    }
                }
            })
    }
}

