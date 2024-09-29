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
    @Binding public var contentViewDetail:ContentDetailView

    @State private var savedSectionSelection = 1
    @State private var didError = false
    
    var body: some View {
        SearchSavedView(chatHost:chatHost, chatModel: chatModel, locationProvider: locationProvider, columnVisibility: $columnVisibility, contentViewDetail: $contentViewDetail)
        .onChange(of: chatModel.selectedSavedResult) { oldValue, newValue in
            chatModel.resetPlaceModel()
            
            guard let newValue = newValue else {
                return
            }
            
            Task { @MainActor in
                if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult {
                    if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                        chatModel.locationSearchText = cachedResult.title
                        await chatHost.didTap(chatResult: cachedResult, selectedDestinationChatResultID: selectedDestinationLocationChatResult)
                    } else {
                        do {
                            try await chatModel.didSearch(caption: chatModel.locationSearchText, selectedDestinationChatResultID: selectedDestinationLocationChatResult, intent:.Location)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                } else {
                    if let cachedResult = chatModel.cachedChatResult(for: newValue) {
                        chatModel.locationSearchText = cachedResult.title
                        await chatHost.didTap(chatResult: cachedResult, selectedDestinationChatResultID: nil)
                    } else {
                        do {
                            try await chatModel.didSearch(caption: chatModel.locationSearchText, selectedDestinationChatResultID:nil)
                        } catch {
                            chatModel.analytics?.track(name: "error \(error)")
                            print(error)
                        }
                    }
                }
            }
        }
        .onChange(of: chatModel.selectedCategoryResult) { oldValue, newValue in
            chatModel.resetPlaceModel()
            Task { @MainActor in
                if let newValue = newValue, let categoricalResult =
                    chatModel.categoricalChatResult(for: newValue) {
                    chatModel.locationSearchText = chatModel.categoricalChatResult(for: newValue)?.title ?? chatModel.locationSearchText
                    await chatHost.didTap(chatResult: categoricalResult, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                }
            }
        }.onChange(of: chatModel.selectedTasteCategoryResult, { oldValue, newValue in
            chatModel.resetPlaceModel()
            Task { @MainActor in
                if let newValue = newValue, let tasteResult = chatModel.tasteChatResult(for: newValue) {
                    chatModel.locationSearchText = tasteResult.title
                    await chatHost.didTap(chatResult: tasteResult, selectedDestinationChatResultID:chatModel.selectedDestinationLocationChatResult)
                }
            }
        })
    }
}

